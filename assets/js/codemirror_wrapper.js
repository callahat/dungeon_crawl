// import 'codemirror/addon/mode/simple.js';
// import CodeMirror from 'codemirror/lib/codemirror.js';

import {EditorView, keymap, drawSelection, highlightActiveLine, dropCursor,
  lineNumbers, highlightActiveLineGutter} from "@codemirror/view"
import {defaultKeymap, history, historyKeymap} from "@codemirror/commands"
import {StreamLanguage, syntaxHighlighting, HighlightStyle} from "@codemirror/language"
import {tags} from "@lezer/highlight";

const dscriptHighlightStyle = HighlightStyle.define([
  {tag: tags.link, color: "#00C", textDecoration: "underline"},
  {tag: tags.meta, color: "#555"},
  {tag: tags.string, color: "#A11"},
  {tag: tags.atom, color: "#219"},
  {tag: tags.name, color: "#00F"},
  {tag: tags.invalid, color: "red"},
  {tag: tags.keyword, color: "#708"},
  {tag: tags.variableName, color: "#05A"},
  {tag: tags.number, color: "#164"},
  {tag: tags.operator, color: "black"},
]);

import { simpleMode } from "@codemirror/legacy-modes/mode/simple-mode"

let CodemirrorWrapper = {
  initOnTab(textAreaEl, triggerEl){ if(!textAreaEl || !triggerEl){ return }

    $(triggerEl).on("shown.bs.tab", () => {
      this.init(textAreaEl)
    })

    if(!!$("#tile_template_script ~ pre.help-block")[0]) {
      $(triggerEl).tab('show')
    }
  },
  init(textAreaEl) { if(!textAreaEl) { return }
    if(! this.decorated){
      this.decorated = true

      this.codemirror = new EditorView({
        doc: textAreaEl.value,
        extensions: [
          lineNumbers(),
          history(),
          highlightActiveLine(),
          highlightActiveLineGutter(),
          dropCursor(),
          drawSelection(),
          keymap.of([
            ...defaultKeymap,
            ...historyKeymap
          ]),
          syntaxHighlighting(dscriptHighlightStyle, {fallback: false}),
          StreamLanguage.define(dscript)
        ]
      })
      textAreaEl.parentNode.insertBefore(this.codemirror.dom, textAreaEl)
      textAreaEl.hidden = true
      if (textAreaEl.form) textAreaEl.form.addEventListener("submit", () => {
        textAreaEl.value = this.codemirror.state.doc.toString()
      })

      console.log(this.codemirror)

    } else {
      this.codemirror.getDoc().setValue(textAreaEl.value)
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
    "equip",
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
    "sound",
    "take",
    "target_player",
    "terminate",
    "text",
    "transport",
    "try",
    "unequip",
    "unlock",
    "walk",
    "zap"
  ].join("|")

export const dscript = simpleMode({
  start: [
    // interpolated text
    {regex: /\${/, token: "meta", sol: true, next: "text"},
    // text link
    {regex: / *![^ ]*?;/, token: "link", sol: true, next: "text"},
    // text
    {regex: /^[^&#@:\/\?${}]+/, token: "string", sol: true, next: "text"},
    // Label
    {regex: /:[^ ]*$/, token: "name", sol: true},
    {regex: /:.*$/, token: "invalid", sol: true},
    // Command
    {regex: RegExp("#(?:" + commands +")(?: |$)", "i"), token: "keyword", sol: true},
    {regex: RegExp("#.*$"), token: "invalid", sol: true},
    // Special variables
    {regex: /\?(?:self|sender)/, token: "variable"},
    // Shorthand movements
    {regex: /[\?\/][nsewicp]/i, token: "keyword"},
    // directions
    {regex: /\b(?:north|up|south|down|east|right|west|left|idle|player|continue)\b/, token: "atom"},
    // boolean
    {regex: /true|false/, token: "atom"},
    // number
    {regex: /[-+]?\d+\.?\d*/, token: "number"},
    // state change
    {regex: /(\?[^ {]*?@|\?{@[^ ]+?}@|@|@@|&)[^@]+?\b/, token: "variableName"},
    // invalid state change
    {regex: /(\?.*@|\?{@.+}@).+\b/, token: "invalid"},
    // operators
    {regex: /==|>=|<=|<|>|!=|\+=|-=|\/=|\*=|\+\+|--|=|not|!/, token: "operator"},
    // invalid movement shorthand
    {regex: /[\?\/]./, token: "invalid"},
  ],
  text: [
    {regex: /^[&#@:\/\?]/, sol: true, next: "start"},
    {regex: /\${/, token: "meta", next: "interpolated"},
    {regex: /[^${}]+$/, token: "string", next: "start"},
    {regex: /[^${}]+/, token: "string"}
  ],
  interpolated: [
    // directions
    {regex: /\b(?:north|up|south|down|east|right|west|left|idle|player|continue)\b/, token: "atom"},
    // boolean
    {regex: /true|false/, token: "atom"},
    // number
    {regex: /[-+]?\d+\.?\d*/, token: "number"},
    // Special variables
    {regex: /\?(?:self|sender)/, token: "variableName"},
    // state change
    {regex: /(\?[^ {]*?@|\?{@[^ ]+?}@|@|@@|&)[^@]+?\b/, token: "variableName"},
    {regex: /\}/, token: "meta", next: "text"},
  ]
})

export default CodemirrorWrapper
