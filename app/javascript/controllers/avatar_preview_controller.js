import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = [ "input", "preview", "initials" ]

    preview() {
        const revision = this.previewRevision = (this.previewRevision || 0) + 1
        const file = this.inputTarget.files[0]
        this.inputTarget.setCustomValidity("")
        if (!file) return

        if (!["image/jpeg", "image/png", "image/webp"].includes(file.type)) {
            this.rejectFile("Choose a JPEG, PNG, or WEBP image.")
            return
        }
        if (file.size > 5 * 1024 * 1024) {
            this.rejectFile("Choose an image under 5 MB.")
            return
        }

        // Decode before replacing the current avatar, including corrupt image files.
        const imageUrl = URL.createObjectURL(file)
        const image = new Image()
        image.onload = () => {
            if (revision !== this.previewRevision || !this.element.isConnected) {
                URL.revokeObjectURL(imageUrl)
                return
            }
            this.showPreview(imageUrl)
        }
        image.onerror = () => {
            URL.revokeObjectURL(imageUrl)
            if (revision === this.previewRevision && this.element.isConnected) {
                this.rejectFile("Choose a readable JPEG, PNG, or WEBP image.")
            }
        }
        image.src = imageUrl
    }

    showPreview(imageUrl) {
        if (this.hasPreviewTarget) {
            this.previewTarget.src = imageUrl
        } else if (this.hasInitialsTarget) {
            const img = document.createElement("img")
            img.src = imageUrl
            img.className = this.initialsTarget.className + " object-cover"
            img.dataset.avatarPreviewTarget = "preview"
            this.initialsTarget.replaceWith(img)
        }
        if (this.previewUrl) URL.revokeObjectURL(this.previewUrl)
        this.previewUrl = imageUrl
    }

    rejectFile(message) {
        this.inputTarget.setCustomValidity(message)
        this.inputTarget.reportValidity()
    }

    disconnect() {
        this.previewRevision = (this.previewRevision || 0) + 1
        if (this.previewUrl) URL.revokeObjectURL(this.previewUrl)
    }
}
