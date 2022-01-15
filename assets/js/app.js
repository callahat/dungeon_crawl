// Brunch automatically concatenates all files in your
// watched paths. Those paths can be configured at
// config.paths.watched in "brunch-config.js".
//
// However, those files will only be executed if
// explicitly imported. The only exception are files
// in vendor, which are never wrapped in imports and
// therefore are always executed.

// Import dependencies
//
// If you no longer want to use a dependency, remember
// to also remove its path from "config.paths.watched".
import css from '../css/app.css';

import 'bootstrap'

import $ from 'jquery'

import "phoenix_html"

window.jQuery = $
window.$ = $

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

import 'codemirror/addon/mode/simple.js';
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
CharacterPicker.init(document.getElementById("show_character_picker"))
CodemirrorWrapper.init(document.getElementById("tile_template_script"), document.getElementById("script-tab"))
TileAnimation.init()
