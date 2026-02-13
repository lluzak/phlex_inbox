import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

const consumer = createConsumer()
const log = (...args) => console.log("[live-renderer]", ...args)

const templateCache = new Map()

function compileTemplate(encoded) {
  if (templateCache.has(encoded)) return templateCache.get(encoded)

  try {
    const body = atob(encoded)
    const fn = new Function("data", body)
    templateCache.set(encoded, fn)
    return fn
  } catch (e) {
    log("ERROR compiling template:", e)
    return null
  }
}

function findSubscription(streamValue) {
  const identifier = JSON.stringify({ channel: "LiveComponentChannel", signed_stream_name: streamValue })
  return consumer.subscriptions.subscriptions.find(s => s.identifier === identifier)
}

function subscribe(streamValue, controller) {
  let sub = findSubscription(streamValue)

  if (!sub) {
    sub = consumer.subscriptions.create(
      { channel: "LiveComponentChannel", signed_stream_name: streamValue },
      {
        connected: () => log("stream connected"),
        disconnected: () => log("stream disconnected"),
        rejected: () => log("ERROR stream rejected"),
        received: (message) => {
          for (const handler of sub.handlers) {
            handler.handleMessage(message)
          }
        }
      }
    )
    sub.handlers = new Set()
  }
  sub.handlers.add(controller)
}

function unsubscribe(streamValue, controller) {
  const sub = findSubscription(streamValue)
  if (!sub) return

  sub.handlers.delete(controller)
  if (sub.handlers.size === 0) {
    consumer.subscriptions.remove(sub)
  }
}

export default class extends Controller {
  static values = {
    template: String,
    templateId: String,
    stream: String
  }

  connect() {
    log("connect", this.element.id)

    const encoded = this.resolveTemplate()
    this.renderFn = encoded ? compileTemplate(encoded) : null

    if (!this.renderFn) {
      log("ERROR no render function, skipping")
      return
    }
    log("template compiled")

    if (!this.streamValue) {
      log("no stream value, skipping subscription")
      return
    }

    subscribe(this.streamValue, this)
  }

  disconnect() {
    log("disconnect", this.element.id)
    if (this.streamValue) {
      unsubscribe(this.streamValue, this)
    }
  }

  resolveTemplate() {
    if (this.hasTemplateValue) return this.templateValue

    if (this.hasTemplateIdValue) {
      const el = document.getElementById(this.templateIdValue)
      if (el) return el.textContent
      log("ERROR template element not found:", this.templateIdValue)
    }

    return null
  }

  handleMessage(message) {
    const { action, data } = message

    if (action === "update" && data.dom_id === this.element.id) {
      this.render(data)
    } else if (action === "destroy" && data.dom_id === this.element.id) {
      log("removing element", this.element.id)
      this.element.remove()
    }
  }

  render(data) {
    log("render", this.element.id)
    const newHtml = this.renderFn(data)
    this.morph(newHtml)
    log("morphed", this.element.id)
  }

  morph(newHtml) {
    const parser = new DOMParser()
    const doc = parser.parseFromString(`<div>${newHtml}</div>`, "text/html")
    const newContent = doc.body.firstChild

    if (typeof Idiomorph !== "undefined") {
      Idiomorph.morph(this.element, newContent, {
        morphStyle: "innerHTML",
        ignoreActiveValue: true
      })
    } else {
      this.element.innerHTML = newContent.innerHTML
    }
  }
}
