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
    window.addEventListener('mouseup', e => {this.disablePainting()} );


    document.getElementById("tiletool-tab").addEventListener('click', e => {
      this.mode = "tile_painting"
    });

    document.getElementById("colortool-tab").addEventListener('click', e => {
      this.mode = "color_painting"
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
    document.getElementById("z_lower_min").addEventListener('click', e => {
      document.getElementById("z_index_lower").value = this.zIndexLowerBound
    })
    document.getElementById("z_lower_max").addEventListener('click', e => {
      document.getElementById("z_index_lower").value = parseInt(document.getElementById("z_index_upper").value)
    })
    document.getElementById("z_upper_min").addEventListener('click', e => {
      document.getElementById("z_index_upper").value = parseInt(document.getElementById("z_index_lower").value)
    })
    document.getElementById("z_upper_max").addEventListener('click', e => {
      document.getElementById("z_index_upper").value = this.zIndexUpperBound
    })

    // Submit is overridden to build the JSON that updates the dungeon map tiles
    var dungeonForm = document.getElementById("dungeon_form");
    if(dungeonForm.addEventListener){
      dungeonForm.addEventListener("submit", this.submitForm, false);  //Modern browsers
    }else if(dungeonForm.attachEvent){
      dungeonForm.attachEvent('onsubmit', this.submitForm);            //Old IE
    }
  },
  submitForm(event){
    var map_tile_changes = []

    for(let tile_change of Array.from(document.getElementsByClassName("changed-map-tile"))){
      let [row, col] = tile_change.parentNode.getAttribute("id").split("_").map(i => parseInt(i))
      let ttid = parseInt(tile_change.getAttribute("data-tile-template-id"))
      let color = tile_change.getAttribute("data-color")
      let background_color = tile_change.getAttribute("data-background-color")
      let z_index = tile_change.getAttribute("data-z-index")

      map_tile_changes.push({row: row, col: col, z_index: z_index, tile_template_id: ttid, color: color, background_color: background_color })
    }
    document.getElementById("map_tile_changes").value = JSON.stringify(map_tile_changes)
    //event.preventDefault()
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

    let tag = target.tagName == "DIV" ? target.parentNode : target

    document.getElementById("active_tile_name").innerText = tag.getAttribute("title")

    document.getElementById("active_tile_character").innerHTML = tag.innerHTML
    document.getElementById("active_tile_description").innerText = tag.getAttribute("data-tile-template-description")

    this.historicTile = !!tag.getAttribute("data-historic-template")
    this.selectedTileId = tag.getAttribute("data-tile-template-id")
    this.selectedTileHtml = tag.children[0]
    this.selectedTileColor = tag.getAttribute("data-color")
    this.selectedTileBackgroundColor = tag.getAttribute("data-background-color")
    if(this.historicTile){
      document.getElementById("active_tile_name").innerText += " (historic)"
    }
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
    let map_location = this.getMapLocation(event)
    if(!map_location) { return } // event picked up on bad element
    this.painting = false
    this.lastCoord = null

    if(this.mode == "tile_painting") {
      let target = [...document.getElementsByName("paintable_tile_template")].find(
        function(i){ return i.getAttribute("data-tile-template-id") == map_location.getAttribute("data-tile-template-id") })

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

    //var paintMethod;
    if(this.mode == "color_painting") {
      var paintMethod = this.colorTile,
          attributes = ["data-color", "data-background-color", "data-tile-template-id"]
    } else if(this.mode == "tile_painting") {
      if(this.historicTile) { return }
      var paintMethod = this.paintTile,
          attributes = ["data-color", "data-background-color", "data-tile-template-id"]
    } else {
      console.log("UNKNOWN MODE:" + this.mode)
      return
    }

    let map_location = this.getMapLocation(event)

    if(!map_location) { return } // event picked up on bad element

    this.painted = true

    var targetCoord = map_location.parentNode.id.split("_").map(c => {return parseInt(c)})

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
      /* If current tile selection is top + 1, get the top non hidden tile that is not class new-map-tile
            if there is a new map tile, that one will be selected for both top + 1 as well as the current z_index being edited.
            if current z_index being edited is greater than the tile there (can be tile with changed-map-tile class, that
            still indicates the topmost tile is not newly placed.
         Then how to stack multiple tiles? 
         Have top level being edited be explicit. Painting color (and erasing when that comes) drops to the visible tile
            (probably should not jump z_indexes on a fill though)
          
       */
      var location_td = document.getElementById(coord)
      paintMethod(document.getElementById(coord), this)
    }
  },
  colorTile(map_location_td, context){
    // There should only ever be one not hidden
    let div = map_location_td.querySelector("div:not([hidden])")

    div.setAttribute("data-color", context.selectedColor)
    div.setAttribute("data-background-color", context.selectedBackgroundColor)
    context.updateColors(div.children[0], context.selectedColor, context.selectedBackgroundColor)
    div.setAttribute("class", "changed-map-tile")
  },
  paintTile(map_location_td, context){
    // there should only ever be one not hidden, TODO: but want to also get the current edited z-index
    let div = map_location_td.querySelector("div:not([hidden])")
    let old_tile = div.children[0]

    div.insertBefore(context.selectedTileHtml.cloneNode(true), old_tile)
    div.removeChild(old_tile)
    div.setAttribute("data-tile-template-id", context.selectedTileId)
    div.setAttribute("data-color", context.selectedTileColor)
    div.setAttribute("data-background-color", context.selectedTileBackgroundColor)
    div.setAttribute("class", "changed-map-tile")
  },
  getMapLocation(event){
    // if it hits TD, more work would be needed to figure out what div is the active targr
    if(event.target.tagName != "DIV"){
      return
    } else if(event.target.tagName == "DIV" && event.target.parentNode.tagName == "DIV"){
      return(event.target.parentNode)
    } else {
      return(event.target)
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

    while(frontier.length > 0){
      let coord = frontier.pop()
      coords.push(coord.join("_"))

      for(let candidate of this.adjacentCoords(coord)) {
        let tileId = candidate.join("_")
        el = document.querySelector("td[id='"+tileId+"'] div:not([hidden])")
        if(!(coords.find(c => { return c == tileId }) || frontier.find(c => { return c.join("_") == tileId })) &&
           this.sameTileTemplate(el, map_location, attributes)){
          frontier.push(candidate)
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
  toggleActiveToolLink(selected, other){
    let selected_link = document.getElementById(selected + "_tools")

    if(!!selected_link.getAttribute("class").match("inactive")) {
      let other_link = document.getElementById(other + "_tools"),
          selected_tools = document.getElementById(selected + "_area"),
          other_tools = document.getElementById(other + "_area"),
          selected_pallette = document.getElementById(selected + "_objects"),
          other_pallette = document.getElementById(other + "_objects")

      selected_link.classList.add("active")
      selected_link.classList.remove("inactive")
      other_link.classList.add("inactive")
      other_link.classList.remove("active")
      other_tools.classList.add("hidden")
      selected_tools.classList.remove("hidden")
      other_pallette.classList.add("hidden")
      selected_pallette.classList.remove("hidden")
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
  selectedTileId: null,
  selectedTileHtml: null,
  selectedTileColor: null,
  selectedTileBackgroundColor: null,
  painting: false,
  painted: false,
  lastDraggedCoord: null,
  lastCoord: null,
  historicTile: false,
  hilightable: true,
  mode: "tile_painting",
  selectedColor: null,
  selectedBackgroundColor: null,
  zIndexBoundSelected: null,
  zIndexUpperBound: 0,
  zIndexLowerBound: 0
}

export default DungeonEditor

