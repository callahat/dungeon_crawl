let InviteLink = {
  init(inviteLinkMenuElement) { if(!inviteLinkMenuElement) { return }
    $("#share_link_copy").popover()

    if(document.getElementById("inviteLinkModal")) {
      this.shareLinkCopyEl = document.getElementById("share_link_copy")
      this.shareLinkCopyEl.addEventListener("click", () => {
        this.copyLink()
      })
      inviteLinkMenuElement.addEventListener("click", () => {
        this.shareLinkCopyEl.classList.remove("fa-check")
        this.shareLinkCopyEl.classList.add("fa-clone")
        $('#inviteLinkModal').modal({show: true})
      })
    } else {
      inviteLinkMenuElement.style.display = "none"
    }
  },
  copyLink() {
    this.shareLinkCopyEl.classList.remove("fa-check")
    this.shareLinkCopyEl.classList.add("fa-clone")
    var linkText = document.getElementById("share_link")
    navigator.clipboard.writeText(linkText.text);
    this.shareLinkCopyEl.classList.remove("fa-clone")
    this.shareLinkCopyEl.classList.add("fa-check")
  },
  shareLinkCopyEl: null
}

export default InviteLink