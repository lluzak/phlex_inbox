import { Controller } from "@hotwired/stimulus"
import { animate } from "animejs"

export default class extends Controller {
  static targets = ["modal", "backdrop", "panel", "form"]

  open() {
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")

    animate(this.backdropTarget, {
      opacity: [0, 1],
      duration: 200,
      easing: "outQuad"
    })

    animate(this.panelTarget, {
      opacity: [0, 1],
      scale: [0.95, 1],
      duration: 250,
      easing: "outQuad"
    })
  }

  close() {
    animate(this.backdropTarget, {
      opacity: [1, 0],
      duration: 150,
      easing: "inQuad"
    })

    animate(this.panelTarget, {
      opacity: [1, 0],
      scale: [1, 0.95],
      duration: 150,
      easing: "inQuad",
      onComplete: () => {
        this.modalTarget.classList.remove("flex")
        this.modalTarget.classList.add("hidden")
        this.formTarget.reset()
        // Reset inline styles for next open
        this.panelTarget.style = ""
        this.backdropTarget.style = ""
      }
    })
  }
}
