import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = [ "input", "preview", "initials" ]

    preview() {
        const file = this.inputTarget.files[0]
        if (!file) return

        const imageUrl = URL.createObjectURL(file)

        if (this.hasPreviewTarget) {
            // If the user already has an avatar image showing
            this.previewTarget.src = imageUrl
        } else if (this.hasInitialsTarget) {
            // If they only have initials placeholder, replace it with a new preview image tag
            const img = document.createElement("img")
            img.src = imageUrl
            img.className = this.initialsTarget.className + " object-cover"
            img.dataset.avatarPreviewTarget = "preview"

            this.initialsTarget.replaceWith(img)
        }
    }
}