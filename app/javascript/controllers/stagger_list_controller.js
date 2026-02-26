import { Controller } from "@hotwired/stimulus"
import { animate, stagger } from "animejs"

export default class extends Controller {
  connect() {
    const items = this.element.children

    if (items.length > 0) {
      animate(items, {
        opacity: [0, 1],
        translateY: [8, 0],
        delay: stagger(30),
        duration: 300,
        easing: "outQuad"
      })
    }

    this.observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          if (node.nodeType !== Node.ELEMENT_NODE) continue
          animate(node, {
            opacity: [0, 1],
            translateY: [-12, 0],
            duration: 350,
            easing: "outQuad"
          })
        }
      }
    })

    this.observer.observe(this.element, { childList: true })
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
