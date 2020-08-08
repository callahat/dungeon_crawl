let DungeonEditor = {
  init(element){ if(!element){ return }

    for(let tile_template of document.getElementsByName("paintable_tile_template")){
      tile_template.addEventListener('click', e => { this.updateActiveTile(e.target) });
      window.addEventListener('keydown', e => { this.hilightTiles(e) });
      window.addEventListener('keyup', e => { this.unHilightTiles(e) });
    }

    for(let color of document.getElementsByName("paintable_color")){
      color.addEventListener('mousedown', e => { this.updateActiveColor(e) });
    }

    for(let character of document.getElementsByName("character_picker")){
      character.addEventListener('click', e => {
        if(!e.target) { return }
        console.log(e.target.textContent)
        document.getElementById("tile_template_character").value = e.target.textContent
        $("#characterPickModal").modal('hide')
      });
    }

    this.updateActiveTile(document.getElementsByName("paintable_tile_template")[0])

    document.getElementById("dungeon").addEventListener('mousedown', e => {
      if(e.which == 3 || e.button == 2) {
        this.disablePainting()
        this.selectDungeonTile(e)
      } else {
        this.enablePainting()
        this.paintEventHandler(e)
      }
    });
    document.getElementById("dungeon").addEventListener('mouseover', e => {this.paintEventHandler(e)} );
    document.getElementById("dungeon").addEventListener('mouseout', e => {this.painted=false} );
    document.getElementById("dungeon").oncontextmenu = function (){ return false }
    document.getElementById("color_pallette").oncontextmenu = function (){ return false }
    window.addEventListener('mouseup', e => {this.disablePainting(); this.erased = null} );


    document.getElementById("tiletool-tab").addEventListener('click', e => {
      this.mode = "tile_painting"
      this.unHilightSpawnTiles()
    });

    document.getElementById("colortool-tab").addEventListener('click', e => {
      this.mode = "color_painting"
      this.unHilightSpawnTiles()
    });

    document.getElementById("other-tab").addEventListener('click', e => {
      // defaulting to tile edit
      this.mode = "tile_edit"
      this.unHilightSpawnTiles()
      document.getElementById("tile_editor_tool").classList.add('btn-info')
      document.getElementById("tile_editor_tool").classList.remove('btn-light')
      document.getElementById("erase_tool").classList.add('btn-light')
      document.getElementById("erase_tool").classList.remove('btn-info')
      document.getElementById("spawn_location_tool").classList.add('btn-light')
      document.getElementById("spawn_location_tool").classList.remove('btn-info')
    });

    document.getElementById("tile_editor_tool").addEventListener('click', e => {
      // defaulting to tile edit
      this.mode = "tile_edit"
      this.unHilightSpawnTiles()
      document.getElementById("tile_editor_tool").classList.add('btn-info')
      document.getElementById("tile_editor_tool").classList.remove('btn-light')
      document.getElementById("erase_tool").classList.add('btn-light')
      document.getElementById("erase_tool").classList.remove('btn-info')
      document.getElementById("spawn_location_tool").classList.add('btn-light')
      document.getElementById("spawn_location_tool").classList.remove('btn-info')
    });

    document.getElementById("erase_tool").addEventListener('click', e => {
      // defaulting to tile edit
      this.mode = "tile_erase"
      this.unHilightSpawnTiles()
      document.getElementById("tile_editor_tool").classList.add('btn-light')
      document.getElementById("tile_editor_tool").classList.remove('btn-info')
      document.getElementById("erase_tool").classList.add('btn-info')
      document.getElementById("erase_tool").classList.remove('btn-light')
      document.getElementById("spawn_location_tool").classList.add('btn-light')
      document.getElementById("spawn_location_tool").classList.remove('btn-info')
    });

    document.getElementById("spawn_location_tool").addEventListener('click', e => {
      // defaulting to tile edit
      this.mode = "spawn_location"
      this.hilightSpawnTiles()
      document.getElementById("tile_editor_tool").classList.add('btn-light')
      document.getElementById("tile_editor_tool").classList.remove('btn-info')
      document.getElementById("erase_tool").classList.add('btn-light')
      document.getElementById("erase_tool").classList.remove('btn-info')
      document.getElementById("spawn_location_tool").classList.add('btn-info')
      document.getElementById("spawn_location_tool").classList.remove('btn-light')
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
    //document.getElementById("dungeon").addEventListener(events[i], report, false);
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
      let map_tile_attrs = {
            row: document.getElementById("tile_template_row").value,
            col: document.getElementById("tile_template_col").value,
            z_index: document.getElementById("tile_template_z_index").value,
            character: (document.getElementById("tile_template_character").value[0] || " "),
            color: (document.getElementById("tile_template_color").value || ""),
            background_color: (document.getElementById("tile_template_background_color").value || ""),
            tile_name: (document.getElementById("tile_template_name").value || ""),
            state: (document.getElementById("tile_template_state").value || ""),
            script: (document.getElementById("tile_template_script").value || ""),
            name: (document.getElementById("tile_template_name").value || "")
          },
          map_location_td = document.getElementById(map_tile_attrs.row + "_" + map_tile_attrs.col),
          map_location = this.findOrCreateActiveTileDiv(map_location_td),
          tileHtml = this.blankDivNode.cloneNode(true),
          paintTileFunction = this.paintTile,
          findOrCreateActiveTileDivFunction = this.findOrCreateActiveTileDiv,
          resetTileModalErrors = this.resetTileModalErrors

      $.post("/dungeons/205/validate_map_tile", {map_tile: map_tile_attrs, _csrf_token: document.getElementsByName("_csrf_token")[0].value})
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
            resetTileModalErrors()

            tileHtml.innerText = map_tile_attrs.character
            tileHtml.style["color"] = map_tile_attrs.color
            tileHtml.style["background-color"] = map_tile_attrs.background_color

            paintTileFunction(map_location_td, {selectedTileId: "",
                                                selectedTileHtml: tileHtml,
                                                selectedTileColor: map_tile_attrs.color,
                                                selectedTileBackgroundColor: map_tile_attrs.background_color,
                                                selectedTileName: map_tile_attrs.tile_name,
                                                selectedTileCharacter: map_tile_attrs.character,
                                                selectedTileState: map_tile_attrs.state,
                                                selectedTileScript: map_tile_attrs.script,
                                                findOrCreateActiveTileDiv: findOrCreateActiveTileDivFunction
            })

            $("#tileEditModal").modal('hide')
          }
       })
       .fail(function(resp){
          console.log(resp.status)
       })


    }) // end save_tile_changes listener

    $("#tileEditModal").on('hide.bs.modal', event => {
      let row = document.getElementById("tile_template_row").value,
          col = document.getElementById("tile_template_col").value,
          map_location_td = document.getElementById(row + "_" + col)
      this.showVisibleTileAtCoordinate(map_location_td, document.getElementById("z_index_current").value)
      this.resetTileModalErrors()
    })

    // Tile Detail
    document.getElementById("tile_detail_tool").addEventListener("click", function(event){
      $('#tileDetailModal').modal({show: true})
    })

    // Character Picker
    document.getElementById("show_character_picker").addEventListener("click", function(event){
      $('#characterPickModal').modal({show: true})
    })

    // Submit is overridden to build the JSON that updates the dungeon map tiles
    var dungeonForm = document.getElementById("dungeon_form");
    if(dungeonForm.addEventListener){
      dungeonForm.addEventListener("submit", ((event) => this.submitForm(event, this)), false);  //Modern browsers
    }else if(dungeonForm.attachEvent){
      dungeonForm.attachEvent('onsubmit', ((event) => this.submitForm(event, this)));            //Old IE
    }

    this.updateVisibleStacks()
  },
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

      map_tile_data.push({row: row,
                          col: col,
                          z_index: z_index,
                          tile_template_id: ttid,
                          color: color,
                          background_color: background_color,
                          character: character,
                          state: state,
                          script: script,
                          name: name })
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

    if(target.classList.contains("placeholder")) { return }

    document.getElementById("active_tile_name").innerText = tag.getAttribute("title")

    document.getElementById("active_tile_character").innerHTML = tag.innerHTML
    document.getElementById("active_tile_description").innerText = tag.getAttribute("data-tile-template-description")

    this.historicTile = !!tag.getAttribute("data-historic-template")
    this.selectedTileId = tag.getAttribute("data-tile-template-id")
    this.selectedTileHtml = tag.children[0]
    this.selectedTileColor = tag.getAttribute("data-color")
    this.selectedTileBackgroundColor = tag.getAttribute("data-background-color")
    this.selectedTileName = tag.getAttribute("data-name")
    this.selectedTileSlug = tag.getAttribute("data-slug")
    this.selectedTileCharacter = tag.getAttribute("data-character")
    this.selectedTileState = tag.getAttribute("data-state")
    this.selectedTileScript = tag.getAttribute("data-script")
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
    document.getElementById("tile_detail_state").innerText = this.selectedTileState
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
    if(this.mode == "tile_edit" || this.mode == "tile_erase" || this.mode == "spawn_location") { return }

    let map_location = this.getMapLocation(event)
    if(!map_location) { return } // event picked up on bad element
    this.painting = false
    this.lastCoord = null

    if(this.mode == "tile_painting") {
      let target = [...document.getElementsByName("paintable_tile_template")].find(
        function(i){ return i.getAttribute("data-tile-template-id") == map_location.getAttribute("data-tile-template-id") })
        || map_location
      this.updateActiveTile(target)
    } else if(this.mode == "color_painting") {

      this.selectedBackgroundColor = document.getElementById("tile_background_color").value = map_location.getAttribute("data-background-color")
      this.selectedColor = document.getElementById("tile_color").value = map_location.getAttribute("data-color")
      this.updateColorPreviews()
    } else {
      console.log("UNKNOWN MODE:" + this.mode)
      return
    }
  },
  paintEventHandler(event){
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

    let map_location = this.findOrCreateActiveTileDiv(this.getMapLocation(event).parentNode)

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
 
      document.getElementById("tile_template_color").dispatchEvent(new Event('change'))

      $('#tileEditModal').modal({show: true})

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
  },
  findOrCreateActiveTileDiv(map_location_td){
    let div = map_location_td.querySelector("td > div[data-z-index='" + document.getElementById("z_index_current").value + "']")
    map_location_td.querySelector("td > div:not(.hidden)").classList.add("hidden")

    if(!!div) {
      div.classList.remove("hidden")
      return(div)
    } else {
      let blankDiv = this.blankDivNode.cloneNode(true);

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
    let div = context.findOrCreateActiveTileDiv(map_location_td)
    let old_tile = div.children[0]

    div.insertBefore(context.selectedTileHtml.cloneNode(true), old_tile)
    div.removeChild(old_tile)
    div.setAttribute("data-tile-template-id", context.selectedTileId)
    div.setAttribute("data-color", context.selectedTileColor)
    div.setAttribute("data-background-color", context.selectedTileBackgroundColor)

    // from individual tile edits; painted templates dont have these currently. probably should though
    // to make things consistent

    div.setAttribute("data-name", context.selectedTileName)
    div.setAttribute("data-character", context.selectedTileCharacter)
    div.setAttribute("data-state", context.selectedTileState)
    div.setAttribute("data-script", context.selectedTileScript)

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
          el = this.findOrCreateActiveTileDiv(map_tile_td)
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

      for(let element of document.querySelectorAll('div[data-tile-template-id="' + elem.getAttribute("data-tile-template-id") + '"] div')){
        element.classList.add("hilight");
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

    this.selectedBackgroundColor = document.getElementById("tile_background_color").value
    this.selectedColor = document.getElementById("tile_color").value

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

    for(let td of document.querySelectorAll('#dungeon tr td')){
      this.showVisibleTileAtCoordinate(td, currentZIndex)
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
                                   return(a.classList.contains("placeholder"))
                                 }
                                 return(a.getAttribute("data-z-index") < b.getAttribute("data-z-index"))
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
  blankDivNode: null,
  selectedTileId: null,
  selectedTileHtml: null,
  selectedTileColor: null,
  selectedTileBackgroundColor: null,
  selectedTileName: null,
  selectedTileSlug: null,
  selectedTileCharacter: null,
  selectedTileState: null,
  selectedTileScript: null,
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

}

export default DungeonEditor

