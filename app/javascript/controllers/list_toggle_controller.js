import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]
  static classes = ["active", "inactive"]
  static values = { iconActiveClass: String, iconInactiveClass: String }

  select(event) {
    const item = this.itemTargets.find(t => t.contains(event.target))
    if (!item) return

    this.itemTargets.forEach(t => {
      const isSelected = t === item
      if (isSelected) {
        t.classList.remove(...this.inactiveClasses)
        t.classList.add(...this.activeClasses)
      } else {
        t.classList.remove(...this.activeClasses)
        t.classList.add(...this.inactiveClasses)
      }

      if (this.hasIconActiveClassValue) {
        const icon = t.querySelector("svg")
        if (icon) {
          if (isSelected) {
            icon.classList.remove(this.iconInactiveClassValue)
            icon.classList.add(this.iconActiveClassValue)
          } else {
            icon.classList.remove(this.iconActiveClassValue)
            icon.classList.add(this.iconInactiveClassValue)
          }
        }
      }
    })
  }
}
