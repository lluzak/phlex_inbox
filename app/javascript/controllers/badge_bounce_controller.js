import { Controller } from "@hotwired/stimulus"
import { animate } from "animejs"

export default class extends Controller {
  connect() {
    animate(this.element, {
      scale: [0, 1],
      duration: 400,
      easing: "outElastic(1, 0.5)"
    })
  }
}
