import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"
import { animate } from "animejs"

const consumer = createConsumer()

function getSessionId() {
  if (!window.__presenceSessionId) {
    window.__presenceSessionId = crypto.randomUUID()
  }
  return window.__presenceSessionId
}

export default class extends Controller {
  static values = {
    messageId: Number,
    mode: { type: String, default: "row" }
  }

  static targets = ["indicator"]

  connect() {
    if (!this.messageIdValue) return

    this.visible = false
    const role = this.modeValue === "detail" ? "viewer" : "observer"

    this.subscription = consumer.subscriptions.create(
      { channel: "PresenceChannel", message_id: this.messageIdValue, session_id: getSessionId(), role },
      {
        received: (data) => this.handleReceived(data),
        connected: () => { if (role === "viewer") this.startHeartbeat() },
        disconnected: () => this.stopHeartbeat()
      }
    )

    if (this.modeValue === "detail") {
      this.handleTypingEvent = (e) => {
        if (e.detail.messageId === this.messageIdValue && this.subscription) {
          this.subscription.perform("typing", { status: e.detail.status })
        }
      }
      document.addEventListener("presence:status", this.handleTypingEvent)
    }
  }

  disconnect() {
    this.stopHeartbeat()
    if (this.handleTypingEvent) {
      document.removeEventListener("presence:status", this.handleTypingEvent)
      this.handleTypingEvent = null
    }
    if (this.subscription) {
      consumer.subscriptions.remove(this.subscription)
      this.subscription = null
    }
  }

  handleReceived(data) {
    if (data.type !== "viewers") return

    const others = data.viewers.filter(v => v.session_id !== getSessionId())
    this.renderIndicator(others)
  }

  renderIndicator(viewers) {
    if (!this.hasIndicatorTarget) return
    const target = this.indicatorTarget

    if (viewers.length === 0) {
      if (this.visible) {
        this.visible = false
        animate(target, {
          opacity: [1, 0],
          scale: [1, 0.9],
          duration: 200,
          easing: "inQuad",
          onComplete: () => { target.innerHTML = "" }
        })
      }
      return
    }

    const wasEmpty = !this.visible
    this.visible = true

    if (this.modeValue === "detail") {
      this.renderDetailBanner(viewers)
    } else {
      this.renderRowDots(viewers)
    }

    if (wasEmpty) {
      animate(target, {
        opacity: [0, 1],
        scale: [0.9, 1],
        duration: 250,
        easing: "outQuad"
      })
    }
  }

  renderDetailBanner(viewers) {
    const entries = viewers.map(v => {
      const isTyping = v.status === "typing"
      const icon = isTyping ? this.pencilIcon() : this.eyeIcon()
      const label = isTyping ? "is typing a reply..." : "is viewing this message"
      return { ...v, icon, label, isTyping }
    })

    const typingViewers = entries.filter(e => e.isTyping)
    const viewingViewers = entries.filter(e => !e.isTyping)

    const sections = []
    if (typingViewers.length > 0) {
      const names = typingViewers.map(e => e.name)
      const text = names.length === 1
        ? `${names[0]} is typing a reply...`
        : `${names.join(", ")} are typing replies...`
      sections.push(`
        <div class="flex items-center gap-2 px-3 py-2 bg-blue-50 border border-blue-200 rounded-lg text-sm text-blue-800">
          ${this.pencilIcon()}
          <div class="flex items-center gap-1.5">
            ${typingViewers.map(e => `<span class="inline-flex items-center justify-center w-5 h-5 rounded-full ${e.color} text-white text-xs font-medium">${e.initials}</span>`).join("")}
            <span>${text}</span>
          </div>
        </div>
      `)
    }
    if (viewingViewers.length > 0) {
      const names = viewingViewers.map(e => e.name)
      const text = names.length === 1
        ? `${names[0]} is also viewing this message`
        : `${names.join(", ")} are also viewing this message`
      sections.push(`
        <div class="flex items-center gap-2 px-3 py-2 bg-amber-50 border border-amber-200 rounded-lg text-sm text-amber-800">
          ${this.eyeIcon()}
          <div class="flex items-center gap-1.5">
            ${viewingViewers.map(e => `<span class="inline-flex items-center justify-center w-5 h-5 rounded-full ${e.color} text-white text-xs font-medium">${e.initials}</span>`).join("")}
            <span>${text}</span>
          </div>
        </div>
      `)
    }

    this.indicatorTarget.innerHTML = `<div class="flex flex-col gap-2">${sections.join("")}</div>`
  }

  eyeIcon() {
    return `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 flex-shrink-0 animate-pulse">
      <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
      <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
    </svg>`
  }

  pencilIcon() {
    return `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 flex-shrink-0 animate-bounce">
      <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L6.832 19.82a4.5 4.5 0 01-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 011.13-1.897L16.863 4.487zm0 0L19.5 7.125" />
    </svg>`
  }

  renderRowDots(viewers) {
    const anyTyping = viewers.some(v => v.status === "typing")
    this.indicatorTarget.innerHTML = `
      <span class="inline-flex items-center gap-1">
        <span class="inline-flex -space-x-1">
          ${viewers.map(v => {
            const ring = v.status === "typing" ? "ring-blue-400 ring-2" : "ring-1 ring-white"
            return `<span class="inline-flex items-center justify-center w-4 h-4 rounded-full ${v.color} text-white ${ring}" style="font-size: 0.5rem; line-height: 1;">${v.initials}</span>`
          }).join("")}
        </span>
        ${anyTyping ? `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-3 h-3 text-blue-500 animate-bounce"><path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L6.832 19.82a4.5 4.5 0 01-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 011.13-1.897L16.863 4.487zm0 0L19.5 7.125" /></svg>` : ""}
      </span>
    `
  }

  startHeartbeat() {
    this.heartbeatTimer = setInterval(() => {
      if (this.subscription) {
        this.subscription.perform("heartbeat")
      }
    }, 15000)
  }

  stopHeartbeat() {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer)
      this.heartbeatTimer = null
    }
  }
}
