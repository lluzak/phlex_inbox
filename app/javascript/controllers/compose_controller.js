import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = ["open", "closed"]
  static targets = ["modal", "subject", "body", "form"]

  open() {
    this.#show()
  }

  close() {
    this.#hide()
    this.#resetForm()
  }

  #show() {
    this.modalTarget.classList.remove(...this.closedClasses)
    this.modalTarget.classList.add(...this.openClasses)
  }

  #hide() {
    this.modalTarget.classList.remove(...this.openClasses)
    this.modalTarget.classList.add(...this.closedClasses)
  }

  #resetForm() {
    this.formTarget.reset()
  }
}
