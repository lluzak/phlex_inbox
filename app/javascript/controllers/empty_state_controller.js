import { Controller } from "@hotwired/stimulus"
import { animate } from "animejs"

export default class extends Controller {
  static targets = ["icon"]

  connect() {
    animate(this.element, {
      opacity: [0, 1],
      duration: 400,
      easing: "outQuad"
    })

    if (this.hasIconTarget) {
      animate(this.iconTarget, {
        scale: [0.5, 1],
        duration: 500,
        easing: "outElastic(1, 0.6)"
      })
    }
  }
}
