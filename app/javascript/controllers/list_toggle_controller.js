import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]
  static classes = ["active"]

  select(event) {
    const item = this.itemTargets.find(t => t.contains(event.target))
    if (!item) return

    this.itemTargets.forEach(t => {
      t.classList.toggle(this.activeClass, t === item)
    })
  }
}
