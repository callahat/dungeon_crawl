let LevelEditor = {
  init(element, state_variable_subform){ if(!element){ return }
    let level_id = element.getAttribute("data-level-id"),
        dungeon_id = element.getAttribute("data-dungeon-id")
    this.state_variable_subform = state_variable_subform
    this.validate_tile_url = "/editor/dungeons/" + dungeon_id +"/levels/" + level_id + "/validate_tile"
    this.map_edge_url = "/editor/dungeons/" + dungeon_id +"/level_edge"

    for(let tile_template of document.getElementsByName("paintable_tile_template")){
      tile_template.addEventListener('click', e => { this.updateActiveTile(e.target) });
    }
    window.addEventListener('keydown', e => { this.hilightTiles(e) });
    window.addEventListener('keyup', e => { this.unHilightTiles(e) });
    window.addEventListener('keydown', e => { this.typeCharacter(e, this) });

    for(let color of document.getElementsByName("paintable_color")){
      color.addEventListener('mousedown', e => { this.updateActiveColor(e) });
    }

    this.updateActiveTile(document.getElementsByName("paintable_tile_template")[0])

    document.getElementById("level").addEventListener('mousedown', e => {
      if(e.which == 3 || e.button == 2) {
        this.disablePainting()
        this.selectDungeonTile(e)
      } else {
        this.enablePainting()
        this.paintEventHandler(e)
      }
    });
    document.getElementById("level").addEventListener('mouseover', e => {this.paintEventHandler(e)} );
    document.getElementById("level").addEventListener('mouseout', e => {this.painted=false} );
    document.getElementById("level").oncontextmenu = function (){ return false }
    document.getElementById("color_pallette").oncontextmenu = function (){ return false }
    window.addEventListener('mouseup', e => {this.disablePainting(); this.erased = null} );

    document.getElementById("tiletool-tab").addEventListener('click', e => {
      document.getElementById("color_area").classList.remove("hidden")
      document.getElementById("tile_color").value = this.lastTilePaintingColor
      document.getElementById("tile_background_color").value = this.lastTilePaintingBackgroundColor
      this.mode = "tile_painting"
      this.unHilightSpawnTiles()
      this.unHilightTextCursor()
      this.updateColorPreviews()
    });

    document.getElementById("colortool-tab").addEventListener('click', e => {
      document.getElementById("color_area").classList.remove("hidden")
      document.getElementById("tile_color").value = this.lastColorPaintingColor
      document.getElementById("tile_background_color").value = this.lastColorPaintingBackgroundColor
      this.mode = "color_painting"
      this.unHilightSpawnTiles()
      this.unHilightTextCursor()
      this.updateColorPreviews()
    });

    document.getElementById("other-tab").addEventListener('click', e => {
      // defaulting to tile edit
      this.mode = "tile_edit"
      this.otherTabHilightTool("tile_editor_tool")
    });

    document.getElementById("tile_editor_tool").addEventListener('click', e => {
      // defaulting to tile edit
      this.mode = "tile_edit"
      this.otherTabHilightTool("tile_editor_tool")
    });

    document.getElementById("erase_tool").addEventListener('click', e => {
      // defaulting to tile edit
      this.mode = "tile_erase"
      this.otherTabHilightTool("erase_tool")
    });

    document.getElementById("spawn_location_tool").addEventListener('click', e => {
      // defaulting to tile edit
      this.mode = "spawn_location"
      this.otherTabHilightTool("spawn_location_tool")
      this.hilightSpawnTiles()
    });

    document.getElementById("text_tool").addEventListener('click', e => {
      // defaulting to tile edit
      document.getElementById("tile_color").value = this.lastTextColor
      document.getElementById("tile_background_color").value = this.lastTextBackgroundColor
      this.mode = "text"
      this.unHilightSpawnTiles()
      this.otherTabHilightTool("text_tool")
      this.textCursorCoordinates = null
      document.getElementById("color_area").classList.remove("hidden")
      this.updateColorPreviews()
    });

    document.getElementById("line_draw_tool").addEventListener('click', e => {
      // defaulting to tile edit
      document.getElementById("tile_color").value = this.lastLineDrawColor
      document.getElementById("tile_background_color").value = this.lastLineDrawBackgroundColor
      this.mode = "line_draw"
      this.unHilightSpawnTiles()
      this.otherTabHilightTool("line_draw_tool")
      document.getElementById("color_area").classList.remove("hidden")
      this.updateColorPreviews()
    });

    for(let field of ['tile_color', 'tile_background_color']){
      document.getElementById(field).addEventListener('change', e => {
        e.preventDefault()
        this.updateColorPreviews()
      });
    }
    this.updateColorPreviews()

    // debuggung events
    /*
    var events = [
    'mouseover',
    //'mousemove',
    'mouseout',
    'mouseenter',
    //'mouseleave',
    'mousedown',
    'mouseup',
    'focus',
    'blur',
    'click'
    ];
    var report = function(e) {
             console.log(e.type)
    }

    for (var i=0; i<events.length; i++) {
    //document.getElementById("level").addEventListener(events[i], report, false);
    //  window.addEventListener(events[i], report, false);
    }*/

    // Z Index tool
    document.getElementById("z_upper_min").addEventListener('click', e => {
      document.getElementById("z_index_current").value = this.zIndexLowerBound
      this.updateVisibleStacks()
    })
    document.getElementById("z_upper_max").addEventListener('click', e => {
      document.getElementById("z_index_current").value = this.zIndexUpperBound
      this.updateVisibleStacks()
    })
    document.getElementById("z_index_current").addEventListener('change', e => {
      this.updateVisibleStacks();
    })
    document.getElementById("up_to_current_layer_visible_toggle").addEventListener('click', e => {
      document.getElementById("up_to_current_layer_visible_toggle").classList.add("hidden")
      document.getElementById("only_current_layer_visible_toggle").classList.remove("hidden")
      this.onlyShowCurrentLayer = true
      this.updateVisibleStacks()
    })
    document.getElementById("only_current_layer_visible_toggle").addEventListener('click', e => {
      document.getElementById("only_current_layer_visible_toggle").classList.add("hidden")
      document.getElementById("up_to_current_layer_visible_toggle").classList.remove("hidden")
      this.onlyShowCurrentLayer = false
      this.updateVisibleStacks()
    })

    this.zIndexUpperBound = document.getElementById("z_index_upper").value
    this.zIndexLowerBound = document.getElementById("z_index_lower").value
    this.onlyShowCurrentLayer = false

    this.blankDivNode = document.createElement("div");
    this.blankDivNode.classList.add("placeholder")
    this.blankDivNode.innerHTML = "<div> </div>"

    // Tile Editor Tool
    document.getElementById("save_tile_changes").addEventListener('click', e => {
      this.validateTileEditorFields(this.tileEditorEditedSuccessCallback, this)
    })

    document.getElementById("tile_edit_add_to_shortlist").addEventListener('click', e => {
      this.validateTileEditorFields(this.tileEditorShortlistedSuccessCallback, this)
    })

    $("#tileEditModal").on('hide.bs.modal', event => {
      let row = document.getElementById("tile_template_row").value,
          col = document.getElementById("tile_template_col").value,
          map_location_td = document.getElementById(row + "_" + col)
      this.showVisibleTileAtCoordinate(map_location_td, document.getElementById("z_index_current").value)
      this.resetTileModalErrors()

      $("#details-tab").tab("show")
    })

    // Tile Detail
    document.getElementById("tile_detail_tool").addEventListener("click", function(event){
      $('#tileDetailModal').modal({show: true})
    })

    document.getElementById("shortlist_active_tile").addEventListener("click", event => {
      this.shortlistActiveTile()
    })

    document.getElementById("unshortlist_active_tile").addEventListener("click", event => {
      this.remoteActiveTileFromShortlist()
    })

    // Tile listing
    document.getElementById("tile_list_tool").addEventListener("click", function(event){
      $('#tileListModal').modal({show: true})
    })
    for(let add_to_shortlist_button of document.getElementsByClassName("add-tile-to-shortlist")){
      add_to_shortlist_button.addEventListener('click', event => {
        let targetId = event.target.getAttribute("data-target-id"),
            tileToShortlist = document.getElementById(targetId).children[0]
        this.addTileToShortlistFromPre(tileToShortlist, this)
        return false
      })
    }

    // Submit is overridden to build the JSON that updates the dungeon map tiles
    var dungeonForm = document.getElementById("map");
    if(dungeonForm.addEventListener){
      dungeonForm.addEventListener("submit", ((event) => this.submitForm(event, this)), false);  //Modern browsers
    }else if(dungeonForm.attachEvent){
      dungeonForm.attachEvent('onsubmit', ((event) => this.submitForm(event, this)));            //Old IE
    }

    this.updateVisibleStacks()

    // show adjacent map edges so its easier to line up maps that connect on their sides
    let sides = ["north", "south", "east", "west"]
    sides.forEach( (side) =>  this.showEdgeTiles(side) )
    sides.forEach( (side) => {
      document.getElementById("map_number_" + side).addEventListener("change", (event) => this.updateEdgeTiles(side, event.target.value, this))
    })

    document.getElementById("reset_colors").addEventListener("click", event => {
      this.resetColors()
    })
  }, // end init
  resetTileModalErrors(){
    document.getElementById("tile_errors").classList.add("hidden")
    document.getElementById("tile_errors").innerText = ''
    document.getElementById("tile_template_state_error_messages").innerText = ''
    document.getElementById("tile_template_script_error_messages").innerText = ''
    document.getElementById("tile_template_name").classList.remove("error")
    document.getElementById("tile_template_character").classList.remove("error")
    document.getElementById("tile_template_color").classList.remove("error")
    document.getElementById("tile_template_background_color").classList.remove("error")
    document.getElementById("tile_template_state").classList.remove("error")
    document.getElementById("tile_template_script").classList.remove("error")
    document.getElementById("tile_template_animate_random").classList.remove("error")
    document.getElementById("tile_template_animate_period").classList.remove("error")
    document.getElementById("tile_template_animate_characters").classList.remove("error")
    document.getElementById("tile_template_animate_colors").classList.remove("error")
    document.getElementById("tile_template_animate_background_colors").classList.remove("error")
  },
  submitForm(event, context){
    document.getElementById("map_tile_changes").value = JSON.stringify(context.getTileFormData("changed-map-tile"))
    document.getElementById("map_tile_additions").value = JSON.stringify(context.getTileFormData("new-map-tile"))
    document.getElementById("map_tile_deletions").value = JSON.stringify(context.getTileFormData("deleted-map-tile"))
    document.getElementById("map_spawn_tiles").value = JSON.stringify(context.spawnCoordsToSubmit())

    //event.preventDefault()
  },
  getTileFormData(type){
    var map_tile_data = []

    for(let tile of Array.from(document.getElementsByClassName(type))){
      let [row, col] = tile.parentNode.getAttribute("id").split("_").map(i => parseInt(i))
      let ttid = parseInt(tile.getAttribute("data-tile-template-id"))
      let color = tile.getAttribute("data-color")
      let background_color = tile.getAttribute("data-background-color")
      let z_index = tile.getAttribute("data-z-index")
      let character = tile.getAttribute("data-character")
      let state = tile.getAttribute("data-state")
      let script = tile.getAttribute("data-script")
      let name = tile.getAttribute("data-name")
      let animate_random = tile.getAttribute("data-random")
      let animate_period = tile.getAttribute("data-period")
      let animate_characters = tile.getAttribute("data-characters")
      let animate_colors = tile.getAttribute("data-colors")
      let animate_background_colors = tile.getAttribute("data-background-colors")

      map_tile_data.push({row: row,
                          col: col,
                          z_index: z_index,
                          tile_template_id: ttid,
                          color: color,
                          background_color: background_color,
                          character: character,
                          state: state,
                          script: script,
                          name: name,
                          animate_random: animate_random,
                          animate_period: animate_period,
                          animate_characters: animate_characters,
                          animate_colors: animate_colors,
                          animate_background_colors: animate_background_colors})
    }

    return(map_tile_data)
  },
  enablePainting(){
    this.painting = true
  },
  disablePainting(){
    this.lastDraggedCoord = null
    this.painting = false
  },
  updateActiveTile(target){
    if(!target) { return }

    let tag = target.tagName == "DIV" && target.parentNode.tagName != "TD" ? target.parentNode : target

    if(target.classList.contains("placeholder") || target.classList.contains("edge")) { return }

    this.selectedTileId = tag.getAttribute("data-tile-template-id")

    let tileTemplate = document.querySelector("#tileListModal [data-tile-template-id='" + this.selectedTileId + "']"),
        description = tileTemplate?.getAttribute("data-tile-template-description"),
        slug = tileTemplate?.getAttribute("data-slug")

    // Not handling the case of removing a tile selected from the map, leaving the "shortlist" button which
    // will bump it to the top of the list should the user click it
    if(tag.getAttribute("name") == "paintable_tile_template" &&
        !!document.querySelector("#tile_pallette_entries [data-attr-hash='" + tag.getAttribute("data-attr-hash") + "']")) {
      this.active_shortlist_id = tag.getAttribute("data-shortlist-id")
    } else {
      this.active_shortlist_id = null
    }
    this.updateShortlistAddRemoveButton()

    this.historicTile = !!tag.getAttribute("data-historic-template")
    this.selectedTileHtml = tag.children[0] || target
    this.selectedTileColor = tag.getAttribute("data-color")
    this.selectedTileBackgroundColor = tag.getAttribute("data-background-color")
    this.selectedTileName = tag.getAttribute("data-name")
    this.selectedTileDescription = tag.getAttribute("data-tile-template-description") || description || ""
    this.selectedTileSlug = tag.getAttribute("data-slug") || slug || ""
    this.selectedTileCharacter = tag.getAttribute("data-character")
    this.selectedTileState = tag.getAttribute("data-state")
    this.selectedTileScript = tag.getAttribute("data-script")
    this.selectedTileAnimateRandom = tag.getAttribute("data-random")
    this.selectedTileAnimatePeriod = tag.getAttribute("data-period")
    this.selectedTileAnimateCharacters = tag.getAttribute("data-characters")
    this.selectedTileAnimateColors = tag.getAttribute("data-colors")
    this.selectedTileAnimateBackgroundColors = tag.getAttribute("data-background-colors")

    document.getElementById("active_tile_name").innerText = this.selectedTileName

    document.getElementById("active_tile_character").innerHTML = tag.innerHTML
    document.getElementById("active_tile_description").innerText = this.selectedTileDescription

    document.getElementById("tile_color").value = this.selectedTileColor
    document.getElementById("tile_background_color").value = this.selectedTileBackgroundColor

    this.updateColorPreviews()

    if(this.historicTile){
      document.getElementById("active_tile_name").innerText += " (historic)"
    }
    if(!this.selectedTileId){
      document.getElementById("active_tile_name").innerText += " (custom)"
    }
    this.updateTileDetail()
  },
  updateTileDetail(){
    document.getElementById("tile_detail_name").innerText = document.getElementById("active_tile_name").innerText
    document.getElementById("tile_detail_slug").innerText = this.selectedTileSlug
    document.getElementById("tile_detail_character").innerHTML = this.selectedTileHtml.outerHTML
    document.getElementById("tile_detail_color").innerText = this.selectedTileColor || "<none>"
    document.getElementById("tile_detail_background_color").innerText = this.selectedTileBackgroundColor || "<none>"
    document.getElementById("tile_detail_description").innerText = document.getElementById("active_tile_description").innerText || "<none>"
    document.getElementById("tile_detail_state").innerHTML = (this.selectedTileState || "").split(/, ?/).map( kv => {
                                                                return `<pre class="script" style="display: inline">${kv}</pre>`
                                                              }).join(" ")
    document.getElementById("tile_detail_script").innerText = this.selectedTileScript
    document.getElementById("tile_template_color").dispatchEvent(new Event('change'))
  },
  updateActiveColor(event){
    let target = event.target
    if(!target) { return }

    let tag = target.tagName == "SPAN" ? target.parentNode : target

    if(event.which == 3 || event.button == 2) {
      // right click background
      document.getElementById("tile_background_color").value = this.selectedBackgroundColor = tag.getAttribute("data-color")
    } else {
      document.getElementById("tile_color").value = this.selectedColor = tag.getAttribute("data-color")
    }
    this.updateColorPreviews()
  },
  selectDungeonTile(event){
    if(event.target.classList.contains("edge") || event.target.parentNode.classList.contains("edge") ) { return }

    if(this.mode == "tile_edit" || this.mode == "tile_erase" || this.mode == "spawn_location") { return }

    let map_location = this.getMapLocation(event)
    if(!map_location) { return } // event picked up on bad element
    this.painting = false
    this.lastCoord = null

    if(this.mode == "tile_painting") {
      this.updateActiveTile(map_location)
    } else if(this.mode == "color_painting" || this.mode == "text" || this.mode == "line_draw") {
      this.selectedBackgroundColor = document.getElementById("tile_background_color").value = map_location.getAttribute("data-background-color")
      this.selectedColor = document.getElementById("tile_color").value = map_location.getAttribute("data-color")
      this.updateColorPreviews()
    } else {
      console.log("UNKNOWN MODE:" + this.mode)
      return
    }
  },
  paintEventHandler(event){
    if(event.target.classList.contains("edge") || event.target.parentNode.classList.contains("edge") ) { return }
    if(!this.painting || this.painted) { return }
    if(this.mode == "tile_painting" && this.historicTile) { return }

    if(this.mode == "tile_erase") {
      let map_location_td = this.getMapLocation(event).parentNode,
          visible_tile_div = map_location_td.querySelector("td > div:not(.hidden):not(.placeholder)"),
          next_top_coords

      if(!visible_tile_div) { return }

      next_top_coords = map_location_td.id + "_" + visible_tile_div.getAttribute("data-z-index")

      if(this.erased == next_top_coords) { return }

      visible_tile_div.classList.add("deleted-map-tile")

      if(visible_tile_div.getAttribute("data-name") == "line-point"){
        visible_tile_div.setAttribute("data-name", "")
        this.updateLinePoint(map_location_td, visible_tile_div, true, this)
      }

      this.showVisibleTileAtCoordinate(map_location_td, document.getElementById("z_index_current").value)
      visible_tile_div = map_location_td.querySelector("td > div:not(.hidden):not(.placeholder)")

      if(!visible_tile_div) { return }

      next_top_coords = map_location_td.id + "_" + visible_tile_div.getAttribute("data-z-index")
      this.erased = next_top_coords
      return
    }

    if(this.mode == "spawn_location") {
      let map_location_td = this.getMapLocation(event).parentNode
      this.toggleSpawnTile(map_location_td.id)
      return
    }

    if(this.mode == "text") {
      this.unHilightTextCursor()
      let map_location_td = this.getMapLocation(event).parentNode
      this.textCursorCoordinates = map_location_td.id
      this.hilightTextCursor()
      return
    }

    let map_location = this.findOrCreateActiveTileDiv(this.getMapLocation(event).parentNode, this)

    if(!map_location) { return } // event picked up on bad element

    this.painted = true

    var targetCoord = map_location.parentNode.id.split("_").map(c => {return parseInt(c)})

    //var paintMethod;
    if(this.mode == "color_painting") {
      var paintMethod = this.colorTile,
          attributes = ["data-color", "data-background-color", "data-tile-template-id"]
    } else if(this.mode == "tile_painting") {
      var paintMethod = this.paintTile,
          attributes = ["data-color", "data-background-color", "data-tile-template-id"]
    } else if(this.mode == "line_draw"){
      var paintMethod = this.drawLine,
          attributes = ["data-color", "data-background-color", "data-tile-template-id"]
    } else if(this.mode == "tile_edit") {
      document.getElementById("tile_template_row").value = targetCoord[0]
      document.getElementById("tile_template_col").value = targetCoord[1]
      document.getElementById("tile_template_z_index").value = map_location.getAttribute("data-z-index")

      document.getElementById("tile_template_name").value = map_location.getAttribute("data-name")
      document.getElementById("tile_template_character").value = map_location.getAttribute("data-character")
      document.getElementById("tile_template_color").value = map_location.getAttribute("data-color")
      document.getElementById("tile_template_background_color").value = map_location.getAttribute("data-background-color")
      document.getElementById("tile_template_state").value = map_location.getAttribute("data-state")
      document.getElementById("tile_template_script").value = map_location.getAttribute("data-script")

      document.getElementById("tile_template_animate_random").checked = map_location.getAttribute("data-random") == "true"
      document.getElementById("tile_template_animate_period").value = map_location.getAttribute("data-period")
      document.getElementById("tile_template_animate_characters").value = map_location.getAttribute("data-characters")
      document.getElementById("tile_template_animate_colors").value = map_location.getAttribute("data-colors")
      document.getElementById("tile_template_animate_background_colors").value = map_location.getAttribute("data-background-colors")

      document.getElementById("tile_template_color").dispatchEvent(new Event('change'))

      $('#tileEditModal').modal({show: true})

      this.state_variable_subform.generateInitialRows(document.getElementById("tile_template_state_variables"), map_location.getAttribute("data-state"))

      this.lastCoord = this.lastDraggedCoord = targetCoord
      return
    } else {
      console.log("UNKNOWN MODE:" + this.mode)
      return
    }

    if(event.shiftKey && event.ctrlKey){
      this.paintTiles(this.coordsForFill(targetCoord, map_location, attributes), paintMethod)
    } else if(event.shiftKey){
      this.paintTiles(this.coordsBetween(this.lastCoord, targetCoord), paintMethod)
    } else {
      this.paintTiles(this.coordsBetween(this.lastDraggedCoord, targetCoord), paintMethod)
    }

    this.lastCoord = this.lastDraggedCoord = targetCoord
  },
  paintTiles(coords, paintMethod){
    for(let coord of coords){
      paintMethod(document.getElementById(coord), this)
    }

    this.deletePlaceholders()
    this.updateVisibleStacks()
  },
  findOrCreateActiveTileDiv(map_location_td, context){
    let div = map_location_td.querySelector("td > div:not(.deleted-map-tile)[data-z-index='" + document.getElementById("z_index_current").value + "']"),
        toHide = map_location_td.querySelector("td > div:not(.hidden)")

    if(!!toHide){ toHide.classList.add("hidden") }

    if(!!div) {
      div.classList.remove("hidden")
      return(div)
    } else {
      let blankDiv = context.blankDivNode.cloneNode(true);

      blankDiv.setAttribute("data-z-index", document.getElementById("z_index_current").value)
      map_location_td.appendChild(blankDiv)
      return(blankDiv)
    }
  },
  colorTile(map_location_td, context){
    // There should only ever be one not hidden
    let currentZIndex = document.getElementById("z_index_current").value,
        div = map_location_td.querySelector("td > div[data-z-index='" + currentZIndex + "']")

    if(div == null || div.classList.contains("placeholder")){
      context.showVisibleTileAtCoordinate(map_location_td, currentZIndex)
    } else {
      div.setAttribute("data-color", context.selectedColor)
      div.setAttribute("data-background-color", context.selectedBackgroundColor)
      context.updateColors(div.children[0], context.selectedColor, context.selectedBackgroundColor)

      if(!div.classList.contains("new-map-tile")){
        div.setAttribute("class", "changed-map-tile")
      }
    }
  },
  paintTile(map_location_td, context){
    // there should only ever be one not hidden, TODO: but want to also get the current edited z-index
    let div = context.findOrCreateActiveTileDiv(map_location_td, context)
    let old_tile = div.children[0],
        active_tile = document.querySelector("#active_tile_character div")

    div.insertBefore(context.selectedTileHtml.cloneNode(true), old_tile)
    //div.insertBefore(active_tile.cloneNode(true), old_tile)
    if(old_tile){ div.removeChild(old_tile) } else { div.innerHTML = "" }
    div.setAttribute("data-tile-template-id", context.selectedTileId || "")
    div.setAttribute("data-color", context.selectedTileColor || "")
    div.setAttribute("data-background-color", context.selectedTileBackgroundColor || "")

    // from individual tile edits; painted templates dont have these currently. probably should though
    // to make things consistent

    div.setAttribute("data-name", context.selectedTileName || "")
    div.setAttribute("data-description", context.selectedTileDescription || "")
    div.setAttribute("data-character", context.selectedTileCharacter || "")
    div.setAttribute("data-state", context.selectedTileState || "")
    div.setAttribute("data-script", context.selectedTileScript || "")

    div.setAttribute("data-random", context.selectedTileAnimateRandom || "")
    div.setAttribute("data-period", context.selectedTileAnimatePeriod || "")
    div.setAttribute("data-characters", context.selectedTileAnimateCharacters || "")
    div.setAttribute("data-colors", context.selectedTileAnimateColors || "")
    div.setAttribute("data-background-colors", context.selectedTileAnimateBackgroundColors || "")

    if(div.classList.contains("placeholder")  || div.classList.contains("blank") || div.classList.contains("new-map-tile")){
      if(document.getElementById("z_index_current").value > context.zIndexUpperBound) {
        context.zIndexUpperBound = document.getElementById("z_index_current").value
      } else if(document.getElementById("z_index_current").value < context.zIndexLowerBound) {
        context.zIndexLowerBound = document.getElementById("z_index_current").value
      }
      div.setAttribute("class", "new-map-tile")
    } else {
      div.setAttribute("class", "changed-map-tile")
    }
  },
  drawLine(map_location_td, context){
    console.log("line draw magic")
    let div = context.findOrCreateActiveTileDiv(map_location_td, context),
        color = context.lastLineDrawColor || "",
        background_color = context.lastLineDrawBackgroundColor || "",
        tileHtml = context.blankDivNode.cloneNode(true)

    tileHtml.innerText = "⋅"
    tileHtml.style["color"] = color
    tileHtml.style["background-color"] = background_color
    tileHtml.classList.remove("placeholder")

    context.paintTile(map_location_td, {blankDivNode: context.blankDivNode,
                                        selectedTileId: "",
                                        selectedTileHtml: tileHtml,
                                        selectedTileColor: color,
                                        selectedTileBackgroundColor: background_color,
                                        selectedTileCharacter: "⋅",
                                        selectedTileState: "blocking: true",
                                        findOrCreateActiveTileDiv: context.findOrCreateActiveTileDiv
    })

    div.setAttribute("data-name", "line-point")

    context.updateLinePoint(map_location_td, div, true, context)
  },
  updateLinePoint(map_location_td, div, neighbors, context){
    if(!map_location_td) { return }

    let coords = map_location_td.id.split("_").map( c => parseInt(c)),
        north_td = document.getElementById([coords[0] - 1, coords[1]].join("_")),
        south_td = document.getElementById([coords[0] + 1, coords[1]].join("_")),
        east_td = document.getElementById([coords[0], coords[1] + 1].join("_")),
        west_td = document.getElementById([coords[0], coords[1] - 1].join("_")),
        score = 0,
        div_north = north_td ? context.findOrCreateActiveTileDiv(north_td, context) : null,
        div_south = south_td ? context.findOrCreateActiveTileDiv(south_td, context) : null,
        div_east = east_td ? context.findOrCreateActiveTileDiv(east_td, context) : null,
        div_west = west_td ? context.findOrCreateActiveTileDiv(west_td, context) : null

    if(div.getAttribute("data-name") == "line-point") {
      score += div_north && div_north.getAttribute("data-name") == "line-point" ? 8 : 0
      score += div_south && div_south.getAttribute("data-name") == "line-point" ? 4 : 0
      score += div_east && div_east.getAttribute("data-name") == "line-point" ? 2 : 0
      score += div_west && div_west.getAttribute("data-name") == "line-point" ? 1 : 0

      let lineChar = context.lineScoreMap[score] || "X"

      if(!div.classList.contains("new-map-tile")){
        div.setAttribute("class", "changed-map-tile")
      }
      div.setAttribute("data-character", lineChar)
      div.children[0].innerText = lineChar
    }

    if(neighbors){
      context.updateLinePoint(north_td, div_north, false, context)
      context.updateLinePoint(south_td, div_south, false, context)
      context.updateLinePoint(east_td, div_east, false, context)
      context.updateLinePoint(west_td, div_west, false, context)
    }
    context.deletePlaceholders()
    context.updateVisibleStacks()
  },
  getMapLocation(event){
    if(event.target.tagName == "TD"){
      console.log("MISSED THE DIV AND HIT A TD INSTEAD!")
      return(event.target.querySelector("div:not(.hidden)"))
    } else if(event.target.tagName == "DIV" && event.target.parentNode.tagName == "DIV"){
      return(event.target.parentNode)
    } else if(event.target.tagName == "DIV" && event.target.parentNode.tagName == "TD") {
      return(event.target)
    } else {
      return
    }
  },
  coordsBetween(start, end){
    if(!start) { return [end.join("_")] }
    let [rowA, colA] = start
    let [rowB, colB] = end

    let [rowDelta, colDelta] = [rowB - rowA, colB - colA]
    let steps = Math.max.apply(null, [rowDelta, colDelta].map(d => {return Math.abs(d)} ))

    let coords = []

    for (let step = 1; step <= steps; step++) {
      coords.push([rowA + Math.round(rowDelta * step / steps), colA + Math.round(colDelta * step / steps)].join("_"))
    }
    return coords
  },
  coordsForFill(target_coord, map_location, attributes){
    let frontier = [target_coord]
    let coords = []
    let el = null
    let map_tile_td
    let tileId

    while(frontier.length > 0){
      let coord = frontier.pop()
      coords.push(coord.join("_"))

      for(let candidate of this.adjacentCoords(coord)) {
        tileId = candidate.join("_")
        if(map_tile_td = document.getElementById(tileId)) {
          el = this.findOrCreateActiveTileDiv(map_tile_td, this)
          if(!(coords.find(c => { return c == tileId }) || frontier.find(c => { return c.join("_") == tileId })) &&
             this.sameTileTemplate(el, map_location, attributes)){
            frontier.push(candidate)
          }
        }
      }
    }
    return coords
  },
  sameTileTemplate(el, map_location, attributes){
    return !!el && attributes.reduce(function(acc, attr){ return(acc && el.getAttribute(attr) == map_location.getAttribute(attr)) }, true)
  },
  adjacentCoords(coord){
    return [[coord[0] + 1, coord[1]],
           [coord[0] - 1, coord[1]],
           [coord[0], coord[1] + 1],
           [coord[0], coord[1] - 1]]
  },
  // Might be easier or more efficient to tweak the CSS for the selector than adding/removing a class
  hilightTiles(event){
    if(event.which == 16 && this.hilightable){
      this.hilightable = false

      let elem = document.querySelectorAll(".tile_template_preview:hover")[0]
      if(!elem) { return }
      let ttid = elem.getAttribute("data-tile-template-id"),
          char = elem.getAttribute("data-character"),
          script = elem.getAttribute("data-script"),
          state = elem.getAttribute("data-state")

      for(let element of document.querySelectorAll('div[data-tile-template-id="' + ttid + '"]')){
        if(ttid == ""){
          if(element.getAttribute("data-character") == char &&
             element.getAttribute("data-script") == script &&
             element.getAttribute("data-state") == state){
            element.querySelector("div").classList.add("hilight");
          }
        } else {
          element.querySelector("div").classList.add("hilight");
        }
      }
    }
  },
  unHilightTiles(event){
    if(event.which == 16){
      for(let element of document.querySelectorAll("div.hilight")){
        element.classList.remove("hilight");
      }
      //for(let element of document.getElementsByClassName("hilight")){
      //  element.classList.remove("hilight");
      //}
      this.hilightable = true
    }
  },
  updateColorPreviews(){
    let color = document.getElementById("tile_color").value;
    let background_color = document.getElementById("tile_background_color").value;

    // can these be consolidated into selectedTileBackgroundColor?
    this.selectedBackgroundColor = background_color
    this.selectedColor = color

    if(this.mode == "tile_painting"){
      this.selectedTileBackgroundColor = background_color
      this.selectedTileColor = color

      this.updateColors(document.querySelector("#active_tile_character div"), color, background_color)
      this.lastTilePaintingColor = color
      this.lastTilePaintingBackgroundColor = background_color

      let active_tile = document.querySelector("#active_tile_character div")

      this.selectedTileHtml = active_tile
    } else if(this.mode == "color_painting") {
      this.lastColorPaintingColor = color
      this.lastColorPaintingBackgroundColor = background_color
    } else if(this.mode == "text") {
      this.lastTextColor = color
      this.lastTextBackgroundColor = background_color
    } else if(this.mode == "line_draw") {
      this.lastLineDrawColor = color
      this.lastLineDrawBackgroundColor = background_color
    }

    this.updateColors(document.getElementById("tile_color_pre"), color, background_color)
    this.updateColors(document.getElementById("tile_background_color_pre"), color, background_color)
  },
  updateColors(element, color, background_color){
    if(color == "" && background_color == ""){
      var style = "";
    } else if(color != "" && background_color == ""){
      var style = "color:" + color;
    } else if(color == "" && background_color != ""){
      var style = "background-color:" + background_color;
    } else {
      var style = "color:" + color + ";background-color:" + background_color;
    }
    element.setAttribute("style", style)
  },
  updateVisibleStacks(){
    let currentZIndex = document.getElementById("z_index_current").value;

    for(let td of document.querySelectorAll('#level tr td')){
      if(!td.classList.contains("edge")){
        this.showVisibleTileAtCoordinate(td, currentZIndex)
      }
    }
  },
  showVisibleTileAtCoordinate(td, currentZIndex){
    let visibleTile,
        tiles = Array.from(td.children)
    if(this.onlyShowCurrentLayer){
      visibleTile = tiles.find((a) => a.getAttribute("data-z-index") == currentZIndex && !a.classList.contains("deleted-map-tile"))
    } else {
      visibleTile = tiles.filter((a)=> (!a.classList.contains("deleted-map-tile")) && a.getAttribute("data-z-index") <= currentZIndex )
                         .sort(function(a,b){
                                 if(a.classList.contains("placeholder") != b.classList.contains("placeholder")){
                                   return(a.classList.contains("placeholder") ? 1 : -1)
                                 }
                                 return(a.getAttribute("data-z-index") < b.getAttribute("data-z-index") ? 1 : -1)
                               })[0]
    }

    tiles.forEach((div) => div.classList.add("hidden"))

    if(visibleTile){
      visibleTile.classList.remove("hidden")
    } else {
      let blankDiv = this.blankDivNode.cloneNode(true)
      blankDiv.setAttribute("data-z-index", currentZIndex)
      td.appendChild(blankDiv)
    }
  },
  toggleSpawnTile(coordinate){
    if(window.spawnLocations[coordinate]){
      window.spawnLocations[coordinate] = false
      document.getElementById(coordinate).classList.remove("spawn-hilight")
    } else {
      window.spawnLocations[coordinate] = true
      document.getElementById(coordinate).classList.add("spawn-hilight")
    }
  },
  hilightSpawnTiles(){
    if(this.hilightingSpawnTiles) { return }

    let coordinate
    this.hilightingSpawnTiles = true
    for(coordinate in window.spawnLocations) {
      if(window.spawnLocations[coordinate]){
        document.getElementById(coordinate).classList.add("spawn-hilight")
      }
    }
  },
  unHilightSpawnTiles(){
    if(! this.hilightingSpawnTiles) { return }

    let coordinate
    this.hilightingSpawnTiles = false
    for(coordinate in window.spawnLocations) {
      document.getElementById(coordinate).classList.remove("spawn-hilight")
    }
  },
  spawnCoordsToSubmit(){
    let coordinate, pair, pairs = []
    for(coordinate in window.spawnLocations) {
      if(window.spawnLocations[coordinate]){
        pair = coordinate.split("_")
        pairs = pairs.concat([ [parseInt(pair[0]), parseInt(pair[1])] ])
      }
    }
    return pairs
  },
  showEdgeTiles(side){
    let edgeTiles = document.querySelectorAll("#level td.edge." + side),
        tile

    edgeTiles.forEach( (tile) => { tile.innerHTML = "" })

    window.adjacent_tiles[side].forEach( (tileDetail) => {
      if(tile = document.getElementById(tileDetail.id)) { tile.innerHTML = tileDetail.html}
    })
  },
  updateEdgeTiles(edge, level_number, context){
    if(level_number){
      $.get(this.map_edge_url, {edge: edge, level_number: level_number, _csrf_token: document.getElementsByName("_csrf_token")[0].value})
        .done(function(resp){
          window.adjacent_tiles[edge] = resp
          context.showEdgeTiles(edge)
         })
         .fail(function(resp){
            console.log(resp.status)
         })
    } else {
      let edgeTiles = document.querySelectorAll("#level td.edge." + edge)
      edgeTiles.forEach( (tile) => { tile.innerHTML = "" })
    }
  },
  addTileToShortlistFromPre(tag, context){
    let attributes = {tile_template_id: tag.getAttribute("data-tile-template-id"),
                      color: tag.getAttribute("data-color"),
                      background_color: tag.getAttribute("data-background-color"),
                      character: tag.getAttribute("data-character"),
                      state: tag.getAttribute("data-state"),
                      script: tag.getAttribute("data-script"),
                      name: tag.getAttribute("data-name"),
                      description: tag.getAttribute("data-tile-template-description"),
                      slug: tag.getAttribute("data-slug"),
                      animate_random: tag.getAttribute("data-random"),
                      animate_period: tag.getAttribute("data-period"),
                      animate_characters: tag.getAttribute("data-characters"),
                      animate_colors: tag.getAttribute("data-colors"),
                      animate_background_colors: tag.getAttribute("data-background-colors")}
    context.addTileToShortlist(attributes, context)
  },
  addTileToShortlist(shortlist_attributes, context){
    $.post("/editor/tile_shortlists", {tile_shortlist: shortlist_attributes,
                                _csrf_token: document.getElementsByName("_csrf_token")[0].value})
     .done(function(resp){
        if(resp.errors && resp.errors.length > 0){
          alert(resp.errors[0].detail)
        } else {
          context.active_shortlist_id = resp.tile_shortlist.id
          context.updateShortlistAddRemoveButton()

          document.getElementById("tile_shortlist_entries").insertAdjacentHTML("afterbegin", resp.tile_pre)
          document.querySelector("#tile_shortlist_entries pre:first-of-type")
                  .addEventListener('click', e => { context.updateActiveTile(e.target) });
          let tiles = document.querySelectorAll(
                "#tile_shortlist_entries [name=paintable_tile_template][data-attr-hash='" + resp.attr_hash + "']"),
              dupeTiles = Array.prototype.slice.call(tiles, 1)
          dupeTiles.forEach( tile => tile.remove() )

          let fullShortlist = document.querySelectorAll("#tile_shortlist_entries [name=paintable_tile_template]"),
              tilesToTrim = Array.prototype.slice.call(fullShortlist, 30)
          tilesToTrim.forEach( tile => tile.remove() )
        }
     })
     .fail(function(resp){
        console.log(resp.status)
     })
  },
  remoteActiveTileFromShortlist(){
    document.querySelector("#tile_shortlist_entries [data-shortlist-id='" + this.active_shortlist_id + "']")?.remove()
    let context = this
    $.ajax("/editor/tile_shortlists",
           {data: {tile_shortlist_id: this.active_shortlist_id,
                          _csrf_token: document.getElementsByName("_csrf_token")[0].value},
                          type: 'DELETE'})
        .done(function(resp){
          if(resp.error){
            alert(resp.error)
          }
          context.active_shortlist_id = null
          context.updateShortlistAddRemoveButton()
        })
        .fail(function(resp){
          console.log(resp.status)
        })
  },
  updateShortlistAddRemoveButton(){
    if(!!this.active_shortlist_id) {
      document.getElementById("shortlist_active_tile").hidden = "hidden"
      document.getElementById("unshortlist_active_tile").hidden = ""
    } else {
      document.getElementById("shortlist_active_tile").hidden = ""
      document.getElementById("unshortlist_active_tile").hidden = "hidden"
    }
  },
  validateTileEditorFields(successFunction, context){
    let map_tile_attrs = {
          row: document.getElementById("tile_template_row").value,
          col: document.getElementById("tile_template_col").value,
          z_index: document.getElementById("tile_template_z_index").value,
          character: (document.getElementById("tile_template_character").value[0] || " "),
          color: (document.getElementById("tile_template_color").value || ""),
          background_color: (document.getElementById("tile_template_background_color").value || ""),
          tile_name: (document.getElementById("tile_template_name").value || ""),
          state_variables: (Array.from(document.getElementsByName("tile_template[state_variables][]")).map(v => {return v.value}) || []),
          state_values: (Array.from(document.getElementsByName("tile_template[state_values][]")).map(v => {return v.value}) || []),
          state: (document.getElementById("tile_template_state").value || ""),
          script: (document.getElementById("tile_template_script").value || ""),
          name: (document.getElementById("tile_template_name").value || ""),
          animate_random: (document.getElementById("tile_template_animate_random").checked),
          animate_period: (document.getElementById("tile_template_animate_period").value || ""),
          animate_characters: (document.getElementById("tile_template_animate_characters").value || ""),
          animate_colors: (document.getElementById("tile_template_animate_colors").value || ""),
          animate_background_colors: (document.getElementById("tile_template_animate_background_colors").value || ""),
        }

    $.post(context.validate_tile_url, {tile: map_tile_attrs, _csrf_token: document.getElementsByName("_csrf_token")[0].value})
     .done(function(resp){
        if(resp.errors.length > 0){
          let otherErrors = ["Errors exist with the tile"]
          for(let error of resp.errors){
            let field = document.getElementById('tile_template_' + error.field),
                errorMessageEl = document.getElementById('tile_template_' + error.field + '_error_messages')
            if(field) {
              field.classList.add("error")
              if(errorMessageEl){
                errorMessageEl.innerText = error.detail
              }
            } else {
              otherErrors.push(error.field + ' - ' + error.detail)
            }
          }
          document.getElementById("tile_errors").innerText = otherErrors.join("<br/>")
          document.getElementById("tile_errors").classList.remove("hidden")

        } else {
          // since the state is built in the changeset from state_variables and state_values in the tile edit modal now
          map_tile_attrs.state = resp.tile.state
          context.resetTileModalErrors()

          successFunction(map_tile_attrs, context)
        }
     })
     .fail(function(resp){
        console.log(resp.status)
     })
  },
  tileEditorEditedSuccessCallback(map_tile_attrs, context){
    let map_location_td = document.getElementById(map_tile_attrs.row + "_" + map_tile_attrs.col),
        map_location = context.findOrCreateActiveTileDiv(map_location_td, context),
        tileHtml = context.blankDivNode.cloneNode(true)

    tileHtml.innerText = map_tile_attrs.character
    tileHtml.style["color"] = map_tile_attrs.color
    tileHtml.style["background-color"] = map_tile_attrs.background_color
    tileHtml.classList.remove("placeholder")

    if(map_tile_attrs.animate_characters != "" ||
       map_tile_attrs.animate_colors != "" ||
       map_tile_attrs.animate_background_colors != ""){

      tileHtml.setAttribute("data-random", map_tile_attrs.animate_random)
      tileHtml.setAttribute("data-period", map_tile_attrs.animate_period)
      tileHtml.setAttribute("data-characters", map_tile_attrs.animate_characters)
      tileHtml.setAttribute("data-colors", map_tile_attrs.animate_colors)
      tileHtml.setAttribute("data-background-colors", map_tile_attrs.animate_background_colors)

      tileHtml.classList.add("animate")
      if(map_tile_attrs.animate_random == "true"){
        tileHtml.classList.add("random")
      } else {
        tileHtml.classList.remove("random")
      }
      //window.TileAnimation.renderTile(window.TileAnimation, div)
    } else {
      tileHtml.classList.remove("animate")
      tileHtml.classList.remove("random")
    }

    context.paintTile(map_location_td, {selectedTileId: "",
                                        selectedTileHtml: tileHtml,
                                        selectedTileColor: map_tile_attrs.color,
                                        selectedTileBackgroundColor: map_tile_attrs.background_color,
                                        selectedTileName: map_tile_attrs.tile_name,
                                        selectedTileDescription: map_tile_attrs.description,
                                        selectedTileCharacter: map_tile_attrs.character,
                                        selectedTileState: map_tile_attrs.state,
                                        selectedTileScript: map_tile_attrs.script,
                                        selectedTileAnimateRandom: map_tile_attrs.animate_random,
                                        selectedTileAnimatePeriod: map_tile_attrs.animate_period,
                                        selectedTileAnimateCharacters: map_tile_attrs.animate_characters,
                                        selectedTileAnimateColors: map_tile_attrs.animate_colors,
                                        selectedTileAnimateBackgroundColors: map_tile_attrs.animate_background_colors,
                                        findOrCreateActiveTileDiv: context.findOrCreateActiveTileDiv
    })

    $("#tileEditModal").modal('hide')
  },
  tileEditorShortlistedSuccessCallback(map_tile_attrs, context){
    context.tileEditorEditedSuccessCallback(map_tile_attrs, context)
    context.addTileToShortlist(map_tile_attrs, context)
  },
  shortlistActiveTile(){
    let map_tile_attrs = {
          tile_template_id: this.selectedTileId,
          character: this.selectedTileCharacter,
          color: this.selectedTileColor,
          background_color: this.selectedTileBackgroundColor,
          state: this.selectedTileState,
          script: this.selectedTileScript,
          name: this.selectedTileName,
          description: this.selectedTileDescription,
          slug: this.selectedTileSlug,
          animate_random: this.selectedTileAnimateRandom,
          animate_period: this.selectedTileAnimatePeriod,
          animate_characters: this.selectedTileAnimateCharacters,
          animate_colors: this.selectedTileAnimateColors,
          animate_background_colors: this.selectedTileAnimateBackgroundColors
        }
    this.addTileToShortlist(map_tile_attrs, this)
  },
  resetColors(){
    if(this.mode == "tile_painting"){
      let tt = [...document.getElementsByName("paintable_tile_template")
               ].find(i => { return i.getAttribute("data-tile-template-id") == this.selectedTileId })

      document.getElementById("tile_color").value = tt ? tt.getAttribute("data-color") : ""
      document.getElementById("tile_background_color").value = tt ? tt.getAttribute("data-background-color") : ""
    } else {
      document.getElementById("tile_color").value = ""
      document.getElementById("tile_background_color").value = ""
    }
    this.updateColorPreviews()
  },
  otherTabHilightTool(tool_id){
    document.getElementById("color_area").classList.add("hidden")
    this.unHilightSpawnTiles()
    this.unHilightTextCursor()

    document.getElementById("tile_editor_tool").classList.add('btn-light')
    document.getElementById("tile_editor_tool").classList.remove('btn-info')
    document.getElementById("erase_tool").classList.add('btn-light')
    document.getElementById("erase_tool").classList.remove('btn-info')
    document.getElementById("spawn_location_tool").classList.add('btn-light')
    document.getElementById("spawn_location_tool").classList.remove('btn-info')
    document.getElementById("text_tool").classList.add('btn-light')
    document.getElementById("text_tool").classList.remove('btn-info')
    document.getElementById("line_draw_tool").classList.add('btn-light')
    document.getElementById("line_draw_tool").classList.remove('btn-info')

    document.getElementById(tool_id).classList.add('btn-info')
    document.getElementById(tool_id).classList.remove('btn-light')
  },
  hilightTextCursor(){
    document.getElementById(this.textCursorCoordinates).classList.add("cursor-hilight")
  },
  unHilightTextCursor(){
    if(! this.textCursorCoordinates){ return }
    document.getElementById(this.textCursorCoordinates).classList.remove("cursor-hilight")
  },
  typeCharacter(event, context){
    if(context.mode != "text") { return }
    if(! document.getElementById("map-tab").classList.contains("active")) { return }

    let character = event.key

    if(!context.textCursorCoordinates || character.length != 1){
      if(character == "Backspace"){
        event.preventDefault();
        context.unHilightTextCursor()

        let map_location_td = document.getElementById(context.textCursorCoordinates),
            current_z_index = document.getElementById("z_index_current").value,
            visible_tile_div = map_location_td.querySelector("td > div[data-z-index='" + current_z_index + "']:not(.hidden):not(.placeholder)")

        if(visible_tile_div){
          visible_tile_div.classList.add("deleted-map-tile")
          context.showVisibleTileAtCoordinate(map_location_td, current_z_index)
        }

        context.previousCursorCoords(context)
        context.hilightTextCursor()
      }
      return
    }
    event.preventDefault();

    let map_location_td = document.getElementById(context.textCursorCoordinates),
        tileHtml = context.blankDivNode.cloneNode(true),
        [cursorRow, cursorCol] = context.textCursorCoordinates.split("_")

    tileHtml.innerText = character
    tileHtml.style["color"] = context.selectedColor
    tileHtml.style["background-color"] = context.selectedBackgroundColor
    tileHtml.classList.remove("placeholder")

    context.paintTile(map_location_td, {blankDivNode: context.blankDivNode,
                                        selectedTileId: "",
                                        selectedTileHtml: tileHtml,
                                        selectedTileColor: context.selectedColor,
                                        selectedTileBackgroundColor: context.selectedBackgroundColor,
                                        selectedTileCharacter: character,
                                        findOrCreateActiveTileDiv: context.findOrCreateActiveTileDiv
    })

    // advance cursor
    context.unHilightTextCursor()
    context.nextCursorCoords(context)
    context.hilightTextCursor()
  },
  nextCursorCoords(context){
    let [cursorRow, cursorCol] = context.textCursorCoordinates.split("_")
    cursorRow = parseInt(cursorRow)
    cursorCol = parseInt(cursorCol)

    cursorRow += cursorCol + 1 >= window.level_width ? 1 : 0
    cursorRow %= window.level_height

    cursorCol += 1
    cursorCol %= window.level_width
    context.textCursorCoordinates = [cursorRow, cursorCol].join("_")
  },
  previousCursorCoords(context){
    let [cursorRow, cursorCol] = context.textCursorCoordinates.split("_")
    cursorRow = parseInt(cursorRow)
    cursorCol = parseInt(cursorCol)

    cursorRow -= cursorCol - 1 < 0 ? 1 : 0
    cursorRow = cursorRow < 0 ? window.level_height -1 : cursorRow

    cursorCol -= 1
    cursorCol = cursorCol < 0 ? window.level_width - 1 : cursorCol
    context.textCursorCoordinates = [cursorRow, cursorCol].join("_")
  },
  deletePlaceholders(){
    for(let placeholder of document.getElementsByClassName("placeholder")){
      placeholder.remove()
    }
  },
  blankDivNode: null,
  selectedTileId: null,
  selectedTileHtml: null,
  selectedTileColor: null,
  selectedTileBackgroundColor: null,
  selectedTileName: null,
  selectedTileDescription: null,
  selectedTileSlug: null,
  selectedTileCharacter: null,
  selectedTileState: null,
  selectedTileScript: null,
  selectedTileAnimateRandom: null,
  selectedTileAnimatePeriod: null,
  selectedTileAnimateCharacters: null,
  selectedTileAnimateColors: null,
  selectedTileAnimateBackgroundColors: null,
  painting: false,
  painted: false,
  lastDraggedCoord: null,
  lastCoord: null,
  historicTile: false,
  hilightable: true,
  mode: "tile_painting",
  selectedColor: null,
  selectedBackgroundColor: null,
  zIndexUpperBound: 0,
  zIndexLowerBound: 0,
  onlyShowCurrentLayer: false,
  erased: false,
  hilightingSpawnTiles: false,
  validate_tile_url: null,
  map_edge_url: null,
  lastTilePaintingColor: null,
  lastTilePaintingBackgroundColor: null,
  lastColorPaintingColor: null,
  lastColorPaintingBackgroundColor: null,
  lastTextColor: null,
  lastTextBackgroundColor: null,
  textCursorCoordinates: null,
  lastLineDrawColor: null,
  lastLineDrawBackgroundColor: null,
  lineScoreMap: { 0: "⋅",  1: "╡",  2: "╞",  3: "═",  4: "╥",  5: "╗",
                  6: "╔",  7: "╦",  8: "╨",  9: "╝", 10: "╚", 11: "╩",
                 12: "║", 13: "╣", 14: "╠", 15: "╬"},
  state_variable_subform: null,
  active_shortlist_id: null
}

export default LevelEditor

