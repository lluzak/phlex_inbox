import { describe, it, expect, beforeEach } from "vitest"
import {
  isBase64,
  compileTemplate,
  clearTemplateCache,
  morphElement,
  buildActionBody,
  routeMessage
} from "../../app/javascript/lib/live_renderer_utils.js"

describe("isBase64", () => {
  it("returns true for valid base64 strings", () => {
    expect(isBase64("SGVsbG8=")).toBe(true)
    expect(isBase64("dGVzdA==")).toBe(true)
    expect(isBase64("AAAA")).toBe(true)
  })

  it("returns false for plain JavaScript code", () => {
    expect(isBase64("function _escape(s) { return s; }")).toBe(false)
    expect(isBase64("let {v0} = data;")).toBe(false)
    expect(isBase64("return `<div>${v0}</div>`")).toBe(false)
  })

  it("returns false for empty string", () => {
    expect(isBase64("")).toBe(false)
  })
})

describe("compileTemplate", () => {
  beforeEach(() => clearTemplateCache())

  it("compiles plain JS function body to callable function", () => {
    const fn = compileTemplate("return data.name")
    expect(fn).toBeTypeOf("function")
    expect(fn({ name: "Alice" })).toBe("Alice")
  })

  it("compiles base64-encoded JS function body", () => {
    const source = btoa("return data.value")
    const fn = compileTemplate(source)
    expect(fn).toBeTypeOf("function")
    expect(fn({ value: 42 })).toBe(42)
  })

  it("caches compiled functions", () => {
    const source = "return data.x"
    const fn1 = compileTemplate(source)
    const fn2 = compileTemplate(source)
    expect(fn1).toBe(fn2) // same reference
  })

  it("returns null for invalid JavaScript", () => {
    const fn = compileTemplate("this is not valid {{{ javascript")
    expect(fn).toBeNull()
  })
})

describe("morphElement", () => {
  it("updates element innerHTML with new content (fallback mode)", () => {
    const el = document.createElement("div")
    el.innerHTML = "<p>old</p>"

    morphElement(el, "<p>new</p>")
    expect(el.innerHTML).toBe("<p>new</p>")
  })

  it("adds live-morph-flash class after morph", () => {
    const el = document.createElement("div")
    el.innerHTML = "<p>old</p>"

    morphElement(el, "<p>new</p>")
    expect(el.classList.contains("live-morph-flash")).toBe(true)
  })
})

describe("buildActionBody", () => {
  it("includes token and action_name", () => {
    const { body } = buildActionBody("toggle_star", "abc123", {}, null)
    expect(body.get("token")).toBe("abc123")
    expect(body.get("action_name")).toBe("toggle_star")
  })

  it("converts camelCase params to snake_case", () => {
    const { body } = buildActionBody("add_label", "tok", { labelId: "5" }, null)
    expect(body.get("params[label_id]")).toBe("5")
  })

  it("strips action key from params", () => {
    const { body } = buildActionBody("test", "tok", { action: "something", name: "val" }, null)
    expect(body.has("params[action]")).toBe(false)
    expect(body.get("params[name]")).toBe("val")
  })

  it("extracts redirect from params", () => {
    const { redirect } = buildActionBody("test", "tok", { redirect: "/messages" }, null)
    expect(redirect).toBe("/messages")
  })

  it("appends form data entries", () => {
    const formData = new FormData()
    formData.append("reply_body", "Hello")
    const { body } = buildActionBody("reply", "tok", {}, formData)
    expect(body.get("params[reply_body]")).toBe("Hello")
  })
})

describe("routeMessage", () => {
  const elementId = "message_42"

  it("routes render action with matching dom_id", () => {
    const result = routeMessage(
      { action: "render", data: { dom_id: "message_42", v0: "test" } },
      elementId,
      "push"
    )
    expect(result.type).toBe("render")
    expect(result.data.v0).toBe("test")
  })

  it("ignores render action with non-matching dom_id", () => {
    const result = routeMessage(
      { action: "render", data: { dom_id: "message_99" } },
      elementId,
      "push"
    )
    expect(result.type).toBe("ignore")
  })

  it("routes update action with matching dom_id", () => {
    const result = routeMessage(
      { action: "update", data: { dom_id: "message_42" } },
      elementId,
      "push"
    )
    expect(result.type).toBe("update")
  })

  it("routes remove action", () => {
    const result = routeMessage(
      { action: "remove", dom_id: "message_42", data: {} },
      elementId,
      "push"
    )
    expect(result.type).toBe("remove")
  })

  it("routes destroy action with matching dom_id", () => {
    const result = routeMessage(
      { action: "destroy", data: { dom_id: "message_42" } },
      elementId,
      "push"
    )
    expect(result.type).toBe("destroy")
  })

  it("returns request_update for notify strategy on update", () => {
    const result = routeMessage(
      { action: "update", data: { dom_id: "message_42" } },
      elementId,
      "notify"
    )
    expect(result.type).toBe("request_update")
  })

  it("returns request_update for notify strategy on destroy", () => {
    const result = routeMessage(
      { action: "destroy", data: { dom_id: "message_42" } },
      elementId,
      "notify"
    )
    expect(result.type).toBe("request_update")
  })

  it("ignores update with non-matching dom_id in push mode", () => {
    const result = routeMessage(
      { action: "update", data: { dom_id: "message_99" } },
      elementId,
      "push"
    )
    expect(result.type).toBe("ignore")
  })
})
