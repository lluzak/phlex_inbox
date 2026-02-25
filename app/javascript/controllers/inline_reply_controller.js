import { Controller } from "@hotwired/stimulus"
import { compileTemplate } from "./live_renderer_utils"
import { buildOptimisticData } from "./optimistic_utils"

export default class extends Controller {
  static targets = ["form", "button"]
  static values = {
    currentUserName: String,
    currentUserInitials: String,
    currentUserAvatarColor: String,
    fieldMap: Object,
    templateId: String,
    targetId: String,
    subject: String
  }

  connect() {
    this.pendingOptimistic = null
    this.formTarget.addEventListener("turbo:submit-start", this.onSubmitStart)
    this.formTarget.addEventListener("turbo:submit-end", this.onSubmitEnd)
    this.boundStreamInterceptor = this.onBeforeStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.boundStreamInterceptor)
  }

  disconnect() {
    this.formTarget.removeEventListener("turbo:submit-start", this.onSubmitStart)
    this.formTarget.removeEventListener("turbo:submit-end", this.onSubmitEnd)
    document.removeEventListener("turbo:before-stream-render", this.boundStreamInterceptor)
  }

  show() {
    this.formTarget.classList.remove("hidden")
    this.buttonTarget.classList.add("hidden")
    this.formTarget.querySelector("textarea").focus()
  }

  onSubmitStart = (event) => {
    const form = this.formTarget.querySelector("form")
    const textarea = form?.querySelector("textarea[name='body']")
    const body = textarea?.value?.trim()
    if (!body) return

    const templateEl = document.getElementById(this.templateIdValue)
    if (!templateEl) return

    const renderFn = compileTemplate(templateEl.textContent)
    if (!renderFn) return

    const data = buildOptimisticData({
      fieldMap: this.fieldMapValue,
      userInfo: {
        name: this.currentUserNameValue,
        initials: this.currentUserInitialsValue,
        avatarUrl: null,
        avatarColor: this.currentUserAvatarColorValue
      },
      body,
      subject: this.subjectValue
    })

    const html = renderFn(data)
    const target = document.getElementById(this.targetIdValue)
    if (!target) return

    const wrapper = document.createElement("div")
    wrapper.id = data.dom_id
    wrapper.innerHTML = html
    wrapper.style.opacity = "0.6"

    target.prepend(wrapper)
    this.pendingOptimistic = { element: wrapper, domId: data.dom_id, body }

    // Reset form for clean UX
    textarea.value = ""
    this.formTarget.classList.add("hidden")
    this.buttonTarget.classList.remove("hidden")
  }

  onSubmitEnd = async (event) => {
    if (!this.pendingOptimistic) return

    const { element, reconciled, body } = this.pendingOptimistic
    this.pendingOptimistic = null

    if (event.detail.success) {
      if (reconciled) return

      const response = event.detail.fetchResponse?.response
      const realDomId = response?.headers?.get("X-Message-Dom-Id")

      if (realDomId && element.isConnected) {
        element.id = realDomId
        element.style.opacity = ""
      }
    } else {
      if (element.isConnected) element.remove()
      // Restore form with original text
      const textarea = this.formTarget.querySelector("textarea[name='body']")
      if (textarea) textarea.value = body
      this.formTarget.classList.remove("hidden")
      this.buttonTarget.classList.add("hidden")
    }
  }

  onBeforeStreamRender(event) {
    if (!this.pendingOptimistic) return

    const stream = event.target
    if (stream.action !== "prepend" || stream.target !== this.targetIdValue) return

    event.preventDefault()

    const template = stream.querySelector("template")
    if (!template) return

    const newContent = template.content.firstElementChild
    if (!newContent) return

    const { element } = this.pendingOptimistic
    if (element.isConnected) {
      element.id = newContent.id
      element.innerHTML = newContent.innerHTML
      element.style.opacity = ""

      for (const attr of newContent.attributes) {
        if (attr.name.startsWith("data-")) {
          element.setAttribute(attr.name, attr.value)
        }
      }

      this.pendingOptimistic.reconciled = true
    }
  }
}
