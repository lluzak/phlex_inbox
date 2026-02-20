import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

const consumer = createConsumer()
const log = (...args) => console.log("[live-renderer]", ...args)

const templateCache = new Map()

async function decompress(base64) {
  const bytes = Uint8Array.from(atob(base64), c => c.charCodeAt(0))
  const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("gzip"))
  return new Response(stream).json()
}

function compileTemplate(source) {
  if (templateCache.has(source)) return templateCache.get(source)

  try {
    const body = isBase64(source) ? atob(source) : source
    const fn = new Function("data", body)
    templateCache.set(source, fn)
    return fn
  } catch (e) {
    log("ERROR compiling template:", e)
    return null
  }
}

function isBase64(str) {
  return /^[A-Za-z0-9+/\n]+=*$/.test(str.trim())
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
        received: async (message) => {
          const decoded = message.z ? await decompress(message.z) : message
          for (const handler of sub.handlers) {
            handler.handleMessage(decoded)
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
    stream: String,
    actionUrl: String,
    actionToken: String,
    state: { type: Object, default: {} },
    data: { type: Object, default: {} },
    strategy: { type: String, default: "push" },
    component: { type: String, default: "" },
    params: { type: Object, default: {} }
  }

  connect() {
    this.clientState = { ...this.stateValue }
    this.lastServerData = Object.keys(this.dataValue).length > 0 ? this.dataValue : null

    const encoded = this.resolveTemplate()
    this.renderFn = encoded ? compileTemplate(encoded) : null

    if (!this.renderFn) {
      if (!this.streamValue) return
    }

    if (!this.streamValue) return

    subscribe(this.streamValue, this)
  }

  disconnect() {
    if (this.streamValue) {
      unsubscribe(this.streamValue, this)
    }
  }

  resolveTemplate() {
    if (this.hasTemplateValue) return this.templateValue

    if (this.hasTemplateIdValue) {
      const el = document.getElementById(this.templateIdValue)
      if (el) return el.textContent
    }

    return null
  }

  handleMessage(message) {
    const { action, data } = message

    if (action === "render" && data?.dom_id === this.element.id) {
      log("render", this.element.id, data)
      this.lastServerData = data
      if (this.renderFn) this.render({ ...data, ...this.clientState })
      return
    }

    if (this.strategyValue === "notify" && (action === "update" || action === "destroy")) {
      log("update", this.element.id, { action, strategy: "notify" })
      this.requestUpdate()
      return
    }

    if (action === "update" && data?.dom_id === this.element.id) {
      log("update", this.element.id, data)
      this.lastServerData = data
      if (this.renderFn) this.render({ ...data, ...this.clientState })
      this.element.dispatchEvent(new CustomEvent("live-renderer:updated", {
        bubbles: true,
        detail: { data }
      }))
    } else if (action === "remove" && (message.dom_id || data?.dom_id) === this.element.id) {
      this.element.remove()
    } else if (action === "destroy" && data?.dom_id === this.element.id) {
      this.element.remove()
    }
  }

  requestUpdate() {
    if (this._updateTimer) clearTimeout(this._updateTimer)

    this._updateTimer = setTimeout(() => {
      this._updateTimer = null
      const sub = findSubscription(this.streamValue)
      if (!sub) return

      sub.perform("request_update", {
        component: this.componentValue,
        record_id: this.dataValue?.id,
        dom_id: this.element.id,
        params: this.paramsValue
      })
    }, 50)
  }

  render(data) {
    const newHtml = this.renderFn(data)
    this.morph(newHtml)
  }

  performAction(event) {
    event.preventDefault()
    event.stopPropagation()

    const actionName = event.params.action
    if (!actionName || !this.hasActionUrlValue || !this.hasActionTokenValue) return

    const body = new URLSearchParams({
      token: this.actionTokenValue,
      action_name: actionName
    })

    const stimulusParams = { ...event.params }
    delete stimulusParams.action
    const redirect = stimulusParams.redirect
    delete stimulusParams.redirect
    for (const [key, value] of Object.entries(stimulusParams)) {
      const snakeKey = key.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`)
      body.append(`params[${snakeKey}]`, value)
    }

    if (event.type === "submit") {
      for (const [key, value] of new FormData(event.target).entries()) {
        body.append(`params[${key}]`, value)
      }
    }

    fetch(this.actionUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
      },
      body
    }).then(response => {
      if (redirect && response.ok) {
        Turbo.visit(redirect)
      } else if (response.ok && response.headers.get("content-type")?.includes("text/html")) {
        return response.text()
      }
    }).then(html => {
      if (html) this.morph(html)
    })
  }

  setState(event) {
    const updates = { ...event.params }
    delete updates.action

    if (updates.exclusive) {
      delete updates.exclusive
      const container = this.element.parentElement
      if (container) {
        container.querySelectorAll(`:scope > [data-controller~="live-renderer"]`).forEach(el => {
          if (el === this.element) return
          const ctrl = this.application.getControllerForElementAndIdentifier(el, "live-renderer")
          if (!ctrl?.clientState) return
          for (const key of Object.keys(updates)) {
            if (ctrl.clientState[key]) ctrl.clientState[key] = false
          }
        })
      }
    }

    Object.assign(this.clientState, updates)
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

    this.element.classList.remove("live-morph-flash")
    void this.element.offsetWidth
    this.element.classList.add("live-morph-flash")
  }
}
