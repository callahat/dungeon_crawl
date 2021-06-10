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

import socket from "./socket"
import Dungeon from "./dungeon"
import DungeonAdmin from "./dungeon_admin"
import Player from "./player"
import TileTemplatePreview from "./tile_template_preview"
import DungeonEditor from "./dungeon_editor"
import CharacterPicker from "./character_picker"
import CodemirrorWrapper from "./codemirror_wrapper"
import TileAnimation from "./tile_animation"
import AvatarPreview from "./avatar_preview"

Dungeon.init(socket, document.getElementById("level_instance"))
DungeonAdmin.init(socket, document.getElementById("level_admin"))
Player.init(socket, Dungeon, document.getElementById("player"))
TileTemplatePreview.init(document.getElementById("character_preview"))
TileTemplatePreview.init(document.getElementById("character_preview_small"))
AvatarPreview.init(document.getElementById("avatar_preview"))
AvatarPreview.init(document.getElementById("avatar_preview_small"))
DungeonEditor.init(document.getElementById("dungeon_editor"))
CharacterPicker.init(document.getElementById("show_character_picker"))
CodemirrorWrapper.init(document.getElementById("tile_template_script"), document.getElementById("script-tab"))
TileAnimation.init()
