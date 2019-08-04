let DungeonEditor = {
  init(element){ if(!element){ return }

    for(let tile_template of document.getElementsByName("paintable_tile_template")){
      tile_template.addEventListener('click', e => { this.updateActiveTile(e.target) });
      window.addEventListener('keydown', e => { this.hilightTiles(e) });
      window.addEventListener('keyup', e => { this.unHilightTiles(e) });
    }

    this.updateActiveTile(document.getElementsByName("paintable_tile_template")[0])

    document.getElementById("dungeon").addEventListener('mousedown', e => {
      if(e.which == 3 || e.button == 2) {
        this.disablePainting()
        this.selectDungeonTile(e)
        // TODO: stash the details for all the existing tiles somewhere so right clicking can select that tile for painting
      } else {
        this.enablePainting()
        this.paintEventHandler(e)
      }
    });
    document.getElementById("dungeon").addEventListener('mouseover', e => {this.paintEventHandler(e)} );
    document.getElementById("dungeon").addEventListener('mouseout', e => {this.painted=false} );
    document.getElementById("dungeon").oncontextmenu = function (){ return false }
    window.addEventListener('mouseup', e => {this.disablePainting()} );

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
      let [row, col] = tile_change.getAttribute("id").split("_").map(i => parseInt(i))
      let ttid = parseInt(tile_change.getAttribute("data-tile-template-id"))

      map_tile_changes.push({row: row, col: col, tile_template_id: ttid })
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

    let tag = target.tagName == "SPAN" ? target.parentNode : target

    document.getElementById("active_tile_name").innerText = tag.getAttribute("title")

    document.getElementById("active_tile_character").innerHTML = tag.innerHTML
    document.getElementById("active_tile_description").innerText = tag.getAttribute("data-tile-template-description")
    document.getElementById("active_tile_responders").innerText = tag.getAttribute("data-tile-template-responders")

    this.historicTile = !!tag.getAttribute("data-historic-template")
    this.selectedTileId = tag.getAttribute("data-tile-template-id")
    this.selectedTileHtml = tag.children[0]
    if(this.historicTile){
      document.getElementById("active_tile_name").innerText += " (historic)"
    }
  },
  selectDungeonTile(event){
    let map_location = this.getMapLocation(event)
    if(!map_location) { return } // event picked up on bad element
    this.painting = false

    let target = [...document.getElementsByName("paintable_tile_template")].find(
      function(i){ return i.getAttribute("data-tile-template-id") == map_location.getAttribute("data-tile-template-id") })

    this.updateActiveTile(target)
  },
  paintEventHandler(event){
    if(this.historicTile) { return }
    if(!this.painting || this.painted) { return }

    let map_location = this.getMapLocation(event)
    if(!map_location) { return } // event picked up on bad element

    this.painted = true

    var targetCoord = map_location.id.split("_").map(c => {return parseInt(c)})

    if(event.shiftKey && event.ctrlKey){
      this.paintTiles(this.coordsForFill(targetCoord, map_location.getAttribute("data-tile-template-id")))
    } else if(event.shiftKey){
      this.paintTiles(this.coordsBetween(this.lastCoord, targetCoord))
    } else {
      this.paintTiles(this.coordsBetween(this.lastDraggedCoord, targetCoord))
    }

    this.lastCoord = this.lastDraggedCoord = targetCoord
  },
  paintTiles(coords){
    for(let coord of coords){
      this.paintTile(document.getElementById(coord))
    }
  },
  paintTile(map_location){
    let old_tile = map_location.children[0]

    map_location.insertBefore(this.selectedTileHtml.cloneNode(true), old_tile)
    map_location.removeChild(old_tile)
    map_location.setAttribute("data-tile-template-id", this.selectedTileId)
    map_location.setAttribute("class", "changed-map-tile")
  },
  getMapLocation(event){
    if(event.target.tagName != "SPAN" && event.target.tagName != "TD"){ 
      return
    } else if(event.target.tagName == "SPAN"){ 
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
  coordsForFill(target_coord, tile_template_id){
    let frontier = [target_coord]
    let coords = []
    let e = null

    while(frontier.length > 0){
      let coord = frontier.pop()
      coords.push(coord.join("_"))

      for(let candidate of this.adjacentCoords(coord)) {
        let tileId = candidate.join("_")
        e = document.getElementById(tileId)
        if(!(coords.find(c => { return c == tileId }) || frontier.find(c => { return c.join("_") == tileId })) &&
           !!e && (e.getAttribute("data-tile-template-id") == tile_template_id)){
          frontier.push(candidate)
        }
      }
    }
    return coords
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

      for(let element of document.querySelectorAll('td[data-tile-template-id="' + elem.getAttribute("data-tile-template-id") + '"] span')){
        element.classList.add("hilight");
      }
    }
  },
  unHilightTiles(event){
    if(event.which == 16){
      for(let element of document.querySelectorAll("span.hilight")){
        element.classList.remove("hilight");
      }
      //for(let element of document.getElementsByClassName("hilight")){
      //  element.classList.remove("hilight");
      //}
      this.hilightable = true
    }
  },
  selectedTileId: null,
  selectedTileHtml: null,
  painting: false,
  painted: false,
  lastDraggedCoord: null,
  lastCoord: null,
  historicTile: false,
  hilightable: true
}

export default DungeonEditor

