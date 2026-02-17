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
    data: { type: Object, default: {} }
  }

  connect() {
    log("connect", this.element.id)

    this.clientState = { ...this.stateValue }
    this.lastServerData = Object.keys(this.dataValue).length > 0 ? this.dataValue : null

    const encoded = this.resolveTemplate()
    this.renderFn = encoded ? compileTemplate(encoded) : null

    if (!this.renderFn) {
      if (this.hasTemplateValue || this.hasTemplateIdValue) {
        log("ERROR no render function, skipping")
      }
      if (!this.streamValue) return
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
      this.lastServerData = data
      if (this.renderFn) this.render({ ...data, ...this.clientState })
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
  }
}
