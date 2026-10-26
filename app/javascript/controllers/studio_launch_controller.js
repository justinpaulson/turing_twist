import { Controller } from "@hotwired/stimulus"

let hasShownStudioCard = false

export default class extends Controller {
  connect() {
    if (hasShownStudioCard) {
      this.element.remove()
      return
    }
    hasShownStudioCard = true
    this.siblings = [...this.element.parentElement.children].filter(element =>
      element !== this.element && !element.hasAttribute("inert"))
    this.siblings.forEach(element => element.setAttribute("inert", ""))
    this.finish = () => {
      document.documentElement.classList.add("studio-launch-complete")
      this.siblings.forEach(element => element.removeAttribute("inert"))
      this.element.remove()
    }
    this.timer = window.setTimeout(this.finish, 2000)
    document.addEventListener("turbo:before-cache", this.finish)
  }

  disconnect() {
    window.clearTimeout(this.timer)
    document.removeEventListener("turbo:before-cache", this.finish)
    this.siblings?.forEach(element => element.removeAttribute("inert"))
  }
}
