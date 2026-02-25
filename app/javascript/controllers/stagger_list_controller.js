import { Controller } from "@hotwired/stimulus"
import { animate, stagger } from "animejs"

export default class extends Controller {
  connect() {
    const items = this.element.children

    if (items.length === 0) return

    animate(items, {
      opacity: [0, 1],
      translateY: [8, 0],
      delay: stagger(30),
      duration: 300,
      easing: "outQuad"
    })
  }
}
