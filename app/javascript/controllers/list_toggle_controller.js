import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]
  static classes = ["active", "inactive"]
  static values = { stateKey: { type: String, default: "" } }

  select(event) {
    const item = this.itemTargets.find(t => t.contains(event.target))
    if (!item) return

    this.itemTargets.forEach(t => {
      const isSelected = t === item
      t.classList.toggle(this.activeClass, isSelected)
      if (this.hasInactiveClass) {
        t.classList.toggle(this.inactiveClass, !isSelected)
      }
      this.#syncState(t, isSelected)
    })
  }

  #syncState(element, isSelected) {
    if (!this.stateKeyValue) return
    const ctrl = this.application.getControllerForElementAndIdentifier(element, "live-renderer")
    if (ctrl?.clientState) ctrl.clientState[this.stateKeyValue] = isSelected
  }
}
