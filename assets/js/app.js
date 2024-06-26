import '../css/app.css';

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

import 'bootstrap'

import $ from 'jquery'

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"

window.jQuery = $
window.$ = $

import './liveview_config'

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

import {zzfx} from 'zzfx'

import socket from "./socket"
import Level from "./level"
import LevelAdmin from "./level_admin"
import Player from "./player"
import TileTemplatePreview from "./tile_template_preview"
import LevelEditor from "./level_editor"
import CharacterPicker from "./character_picker"
import CodemirrorWrapper from "./codemirror_wrapper"
import TileAnimation from "./tile_animation"
import AvatarPreview from "./avatar_preview"
import Sound from "./sound"
import StateVariableSubform from "./state_variable_subform"
import InviteLink from "./invite_link"
import ConfirmationModal from "./confirmation_modal"

Sound.init(zzfx)
StateVariableSubform.init(document.getElementById("dungeon_state_variables"))
StateVariableSubform.init(document.getElementById("level_state_variables"))
StateVariableSubform.init(document.getElementById("tile_template_state_variables"))
Level.init(socket, Sound, document.getElementById("level_instance"))
LevelAdmin.init(socket, Sound, document.getElementById("level_admin"))
Player.init(socket, Level, document.getElementById("player"))
TileTemplatePreview.init(document.getElementById("character_preview"))
TileTemplatePreview.init(document.getElementById("character_preview_small"))
AvatarPreview.init(document.getElementById("avatar_preview"))
AvatarPreview.init(document.getElementById("avatar_preview_small"))
LevelEditor.init(document.getElementById("level_editor"), StateVariableSubform)
InviteLink.init(document.getElementById("invite_link"))
CharacterPicker.init(document.getElementById("show_character_picker"))
CodemirrorWrapper.initOnTab(document.getElementById("tile_template_script"), document.getElementById("script-tab"))
CodemirrorWrapper.init(document.getElementById("item_script"))
CodemirrorWrapper.initDiff(document.getElementById("assetImportDiffList"))
ConfirmationModal.init(document, document.getElementById("confirmationModal"))
TileAnimation.init()
