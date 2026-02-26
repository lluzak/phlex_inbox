import { Controller } from "@hotwired/stimulus"
import { animate } from "animejs"

export default class extends Controller {
  bounce() {
    animate(this.element, {
      scale: [1, 1.4, 1],
      duration: 300,
      easing: "outElastic(1, 0.5)"
    })
  }
}
