import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      const form = this.element.closest("form")
      if (form) form.requestSubmit()
    }, 300)
  }
}
