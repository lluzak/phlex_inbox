import { Controller } from "@hotwired/stimulus"

const KEYS = {
  debug: "devToolbar:debug",
  turboFrames: "devToolbar:turboFrames",
  stimulusDebug: "devToolbar:stimulusDebug",
  animations: "devToolbar:animations"
}

const DEFAULTS = {
  debug: true,
  turboFrames: false,
  stimulusDebug: false,
  animations: true
}

function load(key) {
  const stored = localStorage.getItem(KEYS[key])
  if (stored === null) return DEFAULTS[key]
  return stored === "true"
}

function save(key, value) {
  localStorage.setItem(KEYS[key], value)
}

export default class extends Controller {
  static targets = ["panel", "debugToggle", "turboToggle", "stimulusToggle", "animationsToggle"]

  connect() {
    this.styleTag = document.createElement("style")
    this.styleTag.id = "dev-toolbar-styles"
    document.head.appendChild(this.styleTag)

    this.applyAll()
  }

  disconnect() {
    this.styleTag?.remove()
  }

  toggle() {
    this.panelTarget.classList.toggle("hidden")
  }

  close() {
    this.panelTarget.classList.add("hidden")
  }

  toggleDebug() {
    const current = load("debug")
    save("debug", !current)
    this.applyDebug()
    this.updateToggleUI("debugToggle", !current)
  }

  toggleTurboFrames() {
    const current = load("turboFrames")
    save("turboFrames", !current)
    this.applyTurboFrames()
    this.updateToggleUI("turboToggle", !current)
  }

  toggleStimulusDebug() {
    const current = load("stimulusDebug")
    save("stimulusDebug", !current)
    this.applyStimulusDebug()
    this.updateToggleUI("stimulusToggle", !current)
  }

  toggleAnimations() {
    const current = load("animations")
    save("animations", !current)
    this.applyAnimations()
    this.updateToggleUI("animationsToggle", !current)
  }

  async simulateMessage() {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    if (!token) return

    const response = await fetch("/dev/simulate", {
      method: "POST",
      headers: {
        "X-CSRF-Token": token,
        "Accept": "application/json"
      }
    })

    if (response.ok) {
      const data = await response.json()
      this.flashButton(data.subject)
    }
  }

  // private

  applyAll() {
    this.applyDebug()
    this.applyTurboFrames()
    this.applyStimulusDebug()
    this.applyAnimations()

    this.updateToggleUI("debugToggle", load("debug"))
    this.updateToggleUI("turboToggle", load("turboFrames"))
    this.updateToggleUI("stimulusToggle", load("stimulusDebug"))
    this.updateToggleUI("animationsToggle", load("animations"))
  }

  applyDebug() {
    const on = load("debug")
    this.rebuildStyles()
    if (!on) {
      document.querySelectorAll(".live-debug-wrapper").forEach(el => {
        el.style.outline = "none"
      })
    }
  }

  applyTurboFrames() {
    this.rebuildStyles()
  }

  applyStimulusDebug() {
    const on = load("stimulusDebug")
    if (window.Stimulus) {
      window.Stimulus.debug = on
    }
  }

  applyAnimations() {
    this.rebuildStyles()
  }

  rebuildStyles() {
    const rules = []

    if (!load("debug")) {
      rules.push(`.live-debug-wrapper { outline: none !important; }`)
      rules.push(`.live-debug-wrapper::before { display: none !important; }`)
    }

    if (load("turboFrames")) {
      rules.push(`turbo-frame { outline: 2px dashed rgba(239, 68, 68, 0.4) !important; }`)
    }

    if (!load("animations")) {
      rules.push(`*, *::before, *::after { animation-duration: 0s !important; transition-duration: 0s !important; }`)
    }

    this.styleTag.textContent = rules.join("\n")
  }

  updateToggleUI(targetName, on) {
    if (!this[`has${targetName.charAt(0).toUpperCase() + targetName.slice(1)}Target`]) return
    const el = this[`${targetName}Target`]
    const dot = el.querySelector("[data-dot]")
    const track = el.querySelector("[data-track]")

    if (on) {
      track.classList.remove("bg-gray-300")
      track.classList.add("bg-blue-500")
      dot.classList.remove("translate-x-0")
      dot.classList.add("translate-x-4")
    } else {
      track.classList.remove("bg-blue-500")
      track.classList.add("bg-gray-300")
      dot.classList.remove("translate-x-4")
      dot.classList.add("translate-x-0")
    }
  }

  flashButton(subject) {
    const btn = this.element.querySelector("[data-simulate-btn]")
    if (!btn) return
    const original = btn.textContent
    btn.textContent = `Sent: ${subject.substring(0, 20)}`
    btn.classList.add("bg-green-600")
    setTimeout(() => {
      btn.textContent = original
      btn.classList.remove("bg-green-600")
    }, 1500)
  }
}
