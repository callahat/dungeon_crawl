import {EditorView, keymap, drawSelection, highlightActiveLine, dropCursor,
  lineNumbers, highlightActiveLineGutter} from "@codemirror/view"
import {autocompletion} from "@codemirror/autocomplete"
import {defaultKeymap, history, historyKeymap} from "@codemirror/commands"
import {StreamLanguage, syntaxHighlighting, HighlightStyle} from "@codemirror/language"
import {tags} from "@lezer/highlight"
import { simpleMode } from "@codemirror/legacy-modes/mode/simple-mode"

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


const CodemirrorWrapper = {
  initOnTab(textAreaEl, triggerEl){ if(!textAreaEl || !triggerEl){ return }
    $(triggerEl).on("shown.bs.tab", () => {
      this.init(textAreaEl)
    })

    $(triggerEl).on("hide.bs.tab", () => {
      this.save(textAreaEl)
    })

    if(!!$("#tile_template_script ~ pre.help-block")[0]) {
      $(triggerEl).tab('show')
    }
  },
  init(textAreaEl) { if(!textAreaEl) { return }
    if(! this.decorated){
      this.decorated = true

      let saveTileChangesButton = document.getElementById("save_tile_changes"),
        shortlistTileButton = document.getElementById("tile_edit_add_to_shortlist")
      if(saveTileChangesButton) {
        saveTileChangesButton.addEventListener('mouseover', e => { this.save(textAreaEl) })
        saveTileChangesButton.addEventListener('focus', e => { this.save(textAreaEl) })
      }
      if(shortlistTileButton) {
        shortlistTileButton.addEventListener('mouseover', e => { this.save(textAreaEl) })
        shortlistTileButton.addEventListener('focus', e => { this.save(textAreaEl) })
      }

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
          StreamLanguage.define(dscript),
          autocompletion({override: [completionFunction]})
        ]
      })
      textAreaEl.parentNode.insertBefore(this.codemirror.dom, textAreaEl)
      textAreaEl.hidden = true
      if (textAreaEl.form) textAreaEl.form.addEventListener("submit", () => {
        this.save(textAreaEl)
      })

    } else {
      this.codemirror.dispatch(
        this.codemirror.state.update({changes: {from: 0, to: this.codemirror.state.doc.length, insert: textAreaEl.value}})
      )
    }
  },
  save(textAreaEl) {
    textAreaEl.value = this.codemirror.state.doc.text.join("\n")
  },
  decorated: false,
  codemirror: null
}

// detail will be a quick reminder of the params this command takes, but
// not a full reference
const commandCompletions = [
  {label: "#become", detail: "slug:, character:, ...", info: "KWARGS"},
  {label: "#cycle", detail: "number"},
  {label: "#die"},
  {label: "#end"},
  {label: "#equip", detail: "what, who, [max], [label]"},
  {label: "#facing", detail: "direction"},
  {label: "#gameover", detail: "[win/loss], [result], [who]"},
  {label: "#give", detail: "what, amount, who, [max], [label]"},
  {label: "#go", detail: "direction"},
  {label: "#if", detail: "condition, label or number"},
  {label: "#lock"},
  {label: "#move", detail: "direction, [try until successful]"},
  {label: "#noop"},
  {label: "#passage", detail: "match_key"},
  {label: "#pull", detail: "direction, [try until successful]"},
  {label: "#push", detail: "direction, [range]"},
  {label: "#put", detail: "slug:, direction:, ...", info: "KWARGS"},
  {label: "#random", detail: "variable name, (a,b,c or min-max)"},
  {label: "#remove",
    detail: "target:, (target_[attribute]): ...",
    info: "KWARGS, attributes prefixed with 'target_' will be used for selecting tile(s) to be removed"},
  {label: "#replace",
    detail: "target: (target_[attribute]), color:, ...",
    info: "KWARGS, attributes prefixed with 'target_' will be used for selecting tile(s) to be replaced"},
  {label: "#restore", detail: "label"},
  {label: "#send", detail: "message, [who], [delay]"},
  {label: "#sequence", detail: "variable, list"},
  {label: "#shift", detail: "clockwise or counterclockwise"},
  {label: "#shoot", detail: "direction"},
  {label: "#sound", detail: "sound, (who)"},
  {label: "#take", detail: "what, amount, who, [label]"},
  {label: "#target_player", detail: "nearest or random"},
  {label: "#terminate"},
  {label: "#transport", detail: "who, level, [match_key]"},
  {label: "#try", detail: "direction"},
  {label: "#unequip", detail: "what, who, [label]"},
  {label: "#unlock"},
  {label: "#walk", detail: "direction"},
  {label: "#zap", detail: "label"},
]

const commands = commandCompletions.map((m) => m.label.replace("#","")).join("|")

function completionFunction(context) {
  let before = context.matchBefore(/^[#\w]+/)
  // If completion wasn't explicitly started and there
  // is no word before the cursor, don't open completions.
  if (!context.explicit && !before) return null
  return {
    from: before ? before.from : context.pos,
    options: commandCompletions,
    validFor: /^#\w*$/
  }
}

const dscript = simpleMode({
  start: [
    // interpolated text
    {regex: /\${/, token: "meta", next: "interpolated"},
    // text link
    {regex: / *![^ ]*?;/, token: "link", sol: true, next: "text"},
    // text
    {regex: /[^&#@:\/?${}]+$/, token: "string", sol: true},
    {regex: /[^&#@:\/?${}]+/, token: "string", sol: true, next: "text"},
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
    {regex: /^[^${}]*$/, token: "string", sol: true, next: "start"},
    {regex: /^[&#@:\/?]/, sol: true, next: "start"},
    {regex: /\${/, token: "meta", next: "interpolated"},
    {regex: /[^${}]$/, token: "string", next: "start"},
    {regex: /[^${}]/, token: "string"}
  ],
  interpolated: [
    {regex: /}$/, token: "meta", next: "start"},
    {regex: /}/, token: "meta", next: "text"},
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
  ]
})

export default CodemirrorWrapper
