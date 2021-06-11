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

      let saveTileChangesButton = document.getElementById("save_tile_changes"),
          shortlistTileButton = document.getElementById("tile_edit_add_to_shortlist")
      if(saveTileChangesButton) {
        saveTileChangesButton.addEventListener('mouseover', e => { this.codemirror.save() })
        saveTileChangesButton.addEventListener('focus', e => { this.codemirror.save() })
      }
      if(shortlistTileButton) {
        shortlistTileButton.addEventListener('mouseover', e => { this.codemirror.save() })
        shortlistTileButton.addEventListener('focus', e => { this.codemirror.save() })
      }
    })

    $(triggerEl).on("hide.bs.tab", () => {
      this.codemirror.save()
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
    "cycle",
    "die",
    "end",
    "facing",
    "gameover",
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
    // interpolated text
    {regex: /\${/, token: "meta", sol: true, mode: {spec: "simplemode", end: /}/}, next: "text"},
    // text link
    {regex: / *![^ ]*?;/, token: "link", sol: true, next: "text"},
    // text
    {regex: /^[^&#@:\/\?]/, token: "string", sol: true, next: "text"},
    // Label
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
    {regex: /(\?[^ {]*?@|\?{@[^ ]+?}@|@|@@|&)[^@]+?\b/, token: "variable-2"},
    // invalid state change
    {regex: /(\?.*@|\?{@.+}@).+\b/, token: "error"},
    // operators
    {regex: /==|>=|<=|<|>|!=|\+=|-=|\/=|\*=|\+\+|--|=|not|!/, token: "operator"},
    // invalid movement shorthand
    {regex: /[\?\/]./, token: "error"},
  ],
  text: [
    {regex: /^[&#@:\/\?]/, sol: true, next: "start"},
    {regex: /\${/, token: "meta", mode: {spec: "simplemode", end: /}/}},
    {regex: /.$/, token: "string", next: "start"},
    {regex: /./, token: "string"}
  ]
})

export default CodemirrorWrapper
