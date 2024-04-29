let ConfirmationModal = {
  init(document, modalEl) { if(!document || !modalEl) { return }

    this.$modal = $(modalEl)
    this.$body = this.$modal.find("#confirmationModalBody")

    $(document).on("click", "[data-confirm]", (event) => {
      event.preventDefault()

      this.$body.text(event.target.dataset["confirm"])
      this.confirmationTarget = event.target

      this.$modal.modal({show: true})
    })

    this.$modal.on("click", ".btn.action", (event) => {
      // Dirty way of using the already listening UJS listener
      // to do its thing; Simply copying the data attributes
      // to the modal confirm button did not work, and it did
      // not seem worthwhile to try and reimplement the handling
      // of a data spiced link here
      this.confirmationTarget.removeAttribute("data-confirm")
      this.confirmationTarget.click()
    })

    this.$modal.on('hide.bs.modal', () => {
      this.resetModal()
    })
  },
  resetModal() {
    this.$body.text("")
    this.confirmationTarget = null
  },
  $modal: null,
  $body: null,
  confirmationTarget: null
}

export default ConfirmationModal