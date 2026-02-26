import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link"]
  static classes = ["active", "inactive"]

  select(event) {
    const clicked = event.currentTarget

    this.linkTargets.forEach((link) => {
      const icon = link.querySelector("svg")
      if (link === clicked) {
        link.classList.remove(...this.inactiveClasses)
        link.classList.add(...this.activeClasses)
        if (icon) { icon.classList.remove("text-gray-400"); icon.classList.add("text-blue-600") }
      } else {
        link.classList.remove(...this.activeClasses)
        link.classList.add(...this.inactiveClasses)
        if (icon) { icon.classList.remove("text-blue-600"); icon.classList.add("text-gray-400") }
      }
    })
  }
}
