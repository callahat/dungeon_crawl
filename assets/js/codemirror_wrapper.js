let CodemirrorWrapper = {
  init(textAreaEl, triggerEl){ if(!textAreaEl || !triggerEl){ return }

    $(triggerEl).on("shown.bs.tab", () => {
      if(! this.decorated){
        this.decorated = true
        this.codemirror = CodeMirror.fromTextArea(textAreaEl, {
          lineNumbers: true
        });
      } else {
        this.codemirror.getDoc().setValue(textAreaEl.value)
      }

      let saveTileChangesButton = document.getElementById("save_tile_changes")
      if(saveTileChangesButton) {
        saveTileChangesButton.addEventListener('mouseover', e => { this.codemirror.save() })
        saveTileChangesButton.addEventListener('focus', e => { this.codemirror.save() })
      }
    })

    if(!!$("#tile_template_script ~ pre.help-block")[0]) {
      $(triggerEl).tab('show')
    }
  },
  decorated: false,
  codemirror: null
}

let commands = [
    "become",
      "change_state",
      "change_instance_state",
      "change_other_state",
      "cycle",
      "die",
      "end",
      "facing",
      "give",
      "go",
      "if",
      "lock",
      "move",
      "noop",
      "passage",
      "pull",
      "push",
      "put",
      "random",
      "replace",
      "remove",
      "restore",
      "send",
      "sequence",
      "shift",
      "shoot",
      "take",
      "target_player",
      "terminate",
      "text",
      "transport",
      "try",
      "unlock",
      "walk",
      "zap"
  ].join("|")

CodeMirror.defineSimpleMode("simplemode", {
  start: [
    {regex: /:[^ ]*$/, token: "label", sol: true},
    {regex: /:.*$/, token: "error", sol: true},
    // Command
    {regex: RegExp("#(?:" + commands +")(?: |$)", "i"), token: "command", sol: true},
    {regex: RegExp("#.*$"), token: "error", sol: true},
    // Shorthand movements
    {regex: /[\?\/][nsewicp]/i, token: "command"},
    // directions
    {regex: /\b(?:north|up|south|down|east|right|west|left|idle|player|continue)\b/, token: "atom"},
    // boolean
    {regex: /true|false/, token: "atom"},
    // number
    {regex: /[-+]?\d+\.?\d*/, token: "number"},
    // state change
    {regex: /(\?[^ {]*?@|\?{@[^ ]+?}@|@|@@)[^@]+?\b/, token: "variable-2"},
    // invalid state change
    {regex: /(\?.*@|\?{@.+}@).+\b/, token: "error"},
    // text link
    {regex: / *![^ ]*?;/, token: "link", sol: true, next: "text"},
    // text
    {regex: /[^#@:\/\?].*$/, token: "string", sol: true},
    // operators
    {regex: /==|>=|<=|<|>|!=|\+=|-=|\/=|\*=|\+\+|--|=|not|!/, token: "operator"},
    // invalid movement shorthand
    {regex: /[\?\/]./, token: "error"},
  ],
  text: [
    {regex: /.*$/, token: "string", next: "start"}
  ]
})

export default CodemirrorWrapper
