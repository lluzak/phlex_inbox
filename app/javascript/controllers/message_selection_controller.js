import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  select(event) {
    const row = event.target.closest("[data-controller~='live-renderer']")
    if (!row) return

    // Deselect previous
    this.element.querySelectorAll(":scope > .bg-blue-50").forEach(el => {
      el.classList.remove("bg-blue-50")
      el.classList.add("bg-white")
    })

    // Select clicked row
    row.classList.remove("bg-white")
    row.classList.add("bg-blue-50")

    // Update live-renderer client state so selection survives server re-renders
    const app = this.application
    const ctrl = app.getControllerForElementAndIdentifier(row, "live-renderer")
    if (ctrl?.clientState) ctrl.clientState.selected = true

    // Clear selected state on siblings
    this.element.querySelectorAll(":scope > [data-controller~='live-renderer']").forEach(el => {
      if (el === row) return
      const sibling = app.getControllerForElementAndIdentifier(el, "live-renderer")
      if (sibling?.clientState) sibling.clientState.selected = false
    })
  }
}
