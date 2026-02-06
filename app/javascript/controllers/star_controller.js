import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
  }
}
