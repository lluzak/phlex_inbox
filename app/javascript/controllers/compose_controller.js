import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = ["open", "closed"]
  static targets = ["subject", "body"]

  open() {
    this.element.classList.remove(...this.closedClasses)
    this.element.classList.add(...this.openClasses)
  }

  close() {
    this.element.classList.remove(...this.openClasses)
    this.element.classList.add(...this.closedClasses)
  }

  reply(event) {
    const { subjectParam } = event.params
    this.open()
    if (this.hasSubjectTarget) {
      this.subjectTarget.value = `Re: ${subjectParam}`
    }
    if (this.hasBodyTarget) {
      this.bodyTarget.focus()
    }
  }
}
