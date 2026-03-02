import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"
import { animate } from "animejs"

const consumer = createConsumer()
const SESSION_ID = crypto.randomUUID()

// Share SESSION_ID with presence_controller
window.__presenceSessionId = SESSION_ID

export default class extends Controller {
  static targets = ["avatars", "self"]

  connect() {
    this.visible = false
    this.subscription = consumer.subscriptions.create(
      { channel: "GlobalPresenceChannel", session_id: SESSION_ID },
      {
        received: (data) => this.handleReceived(data),
        connected: () => this.startHeartbeat(),
        disconnected: () => this.stopHeartbeat()
      }
    )
  }

  disconnect() {
    this.stopHeartbeat()
    if (this.subscription) {
      consumer.subscriptions.remove(this.subscription)
      this.subscription = null
    }
  }

  handleReceived(data) {
    if (data.type !== "global_viewers") return
    this.renderAvatars(data.viewers)
  }

  renderAvatars(viewers) {
    if (!this.hasAvatarsTarget) return

    const self = viewers.find(v => v.session_id === SESSION_ID)
    const others = viewers.filter(v => v.session_id !== SESSION_ID)

    // Show own identity badge
    if (this.hasSelfTarget && self) {
      this.selfTarget.innerHTML = `
        <span class="inline-flex items-center justify-center w-8 h-8 rounded-full ${self.color} text-white text-xs font-bold ring-2 ring-white">${self.initials}</span>
      `
    }

    const target = this.avatarsTarget

    if (others.length === 0) {
      if (this.visible) {
        this.visible = false
        animate(target, {
          opacity: [1, 0],
          duration: 200,
          easing: "inQuad",
          onComplete: () => { target.innerHTML = "" }
        })
      }
      return
    }

    const wasEmpty = !this.visible
    this.visible = true

    const shown = others.slice(0, 3)
    const overflow = others.length - shown.length

    target.innerHTML = `
      <div class="flex items-center gap-2.5">
        <div class="flex -space-x-1">
          ${shown.map(v => {
            const viewing = v.viewing_message_id
            if (viewing) {
              return `<a href="/messages/${viewing}" data-turbo-frame="message_detail" data-turbo-action="advance" class="inline-flex items-center justify-center w-8 h-8 rounded-full ${v.color} text-white text-xs font-bold ring-2 ring-white hover:ring-blue-400 hover:scale-110 transition-all cursor-pointer" title="${v.name} — viewing a message (click to go)">${v.initials}</a>`
            }
            return `<span class="inline-flex items-center justify-center w-8 h-8 rounded-full ${v.color} text-white text-xs font-bold ring-2 ring-gray-200 opacity-60 cursor-default" title="${v.name} — online">${v.initials}</span>`
          }).join("")}
          ${overflow > 0 ? `<span class="inline-flex items-center justify-center w-8 h-8 rounded-full bg-gray-400 text-white text-xs font-bold ring-2 ring-white">+${overflow}</span>` : ""}
        </div>
        <span class="text-xs text-gray-500">${others.length} other${others.length === 1 ? "" : "s"} online</span>
      </div>
    `

    if (wasEmpty) {
      animate(target, {
        opacity: [0, 1],
        translateX: [8, 0],
        duration: 300,
        easing: "outQuad"
      })
    }
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
