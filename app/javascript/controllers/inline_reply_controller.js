import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "button"]

  show() {
    this.formTarget.classList.remove("hidden")
    this.buttonTarget.classList.add("hidden")
    this.formTarget.querySelector("textarea").focus()
  }
}
