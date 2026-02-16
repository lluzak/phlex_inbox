import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.boundKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  handleKeydown(event) {
    if (event.target.tagName === "INPUT" || event.target.tagName === "TEXTAREA" || event.target.tagName === "SELECT") {
      return
    }

    const rows = document.querySelectorAll("[id^='message_']")
    const current = document.querySelector("[id^='message_'].bg-blue-50")
    const currentIndex = current ? Array.from(rows).indexOf(current) : -1

    switch (event.key) {
      case "j":
        if (currentIndex < rows.length - 1) {
          const next = rows[currentIndex + 1]
          const link = next.querySelector("a")
          if (link) link.click()
        }
        break
      case "k":
        if (currentIndex > 0) {
          const prev = rows[currentIndex - 1]
          const link = prev.querySelector("a")
          if (link) link.click()
        }
        break
      case "s":
        if (current) {
          const starBtn = current.querySelector("[data-live-renderer-action-param='toggle_star']")
          if (starBtn) starBtn.click()
        }
        break
    }
  }
}
