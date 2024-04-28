let ConfirmationModal = {
  init(document, modalEl) { if(!document || !modalEl) { return }

    this.$modal = $(modalEl)
    this.$body = this.$modal.find("#confirmationModalBody")
    this.$confirmButton = this.$modal.find(".action.btn")

    $(document).on("click", "[data-confirm]", (event) => {
      event.preventDefault()

      this.$body.text(event.target.dataset["confirm"])
      this.$confirmButton.attr("data-csrf", event.target.dataset["csrf"])
      this.$confirmButton.attr("data-method", event.target.dataset["method"])
      this.$confirmButton.attr("data-to", event.target.dataset["to"])
      this.$modal.modal({show: true})
    })

    this.$modal.on("click", ".btn.action", (event) => {
      if(event.target.dataset["method"] === "delete"){
        $.delete(event.target.dataset["to"],
          {_csrf_token: event.target.dataset["csrf"]})
      } else {
        $.post(event.target.dataset["to"],
          {_csrf_token: event.target.dataset["csrf"]})
      }
    })

    this.$modal.on('hide.bs.modal', () => {
      this.resetModal()
    })
  },
  resetModal() {
    this.$body.text("")
    this.$confirmButton.attr("data-csrf", "")
    this.$confirmButton.attr("data-method", "")
    this.$confirmButton.attr("data-to", "")
  },
  $modal: null,
  $body: null,
  $confirmButton: null
}

export default ConfirmationModal