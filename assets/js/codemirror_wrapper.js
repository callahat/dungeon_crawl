let CodemirrorWrapper = {
  init(textAreaEl, triggerEl){ if(!textAreaEl || !triggerEl){ return }

    $(triggerEl).on("shown.bs.tab", () => {
      console.log("shown bs tab")
      if(! this.decorated){
        this.decorated = true
        this.codemirror = CodeMirror.fromTextArea(textAreaEl, {
          lineNumbers: true
        });
      } else {
        this.codemirror.getDoc().setValue(textAreaEl.value)
      }

      document.getElementById("save_tile_changes").addEventListener('mouseover', e => { this.codemirror.save() })
      document.getElementById("save_tile_changes").addEventListener('focus', e => { this.codemirror.save() })
    })

    if(!!$("#tile_template_script ~ pre.help-block")[0]) {
      $(triggerEl).tab('show')
    }
  },
  decorated: false,
  codemirror: null
}

export default CodemirrorWrapper
