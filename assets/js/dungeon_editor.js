let DungeonEditor = {
  init(element){ if(!element){ return }

    for(let tile_template of document.getElementsByName("paintable_tile_template")){
      tile_template.addEventListener('click', e => { this.updateActiveTile(e) });
    }

    this.updateActiveTile({target: document.getElementsByName("paintable_tile_template")[0]})

    document.getElementById("dungeon").addEventListener('mousedown', e => {
//      if(e.which == 3 || e.button == 2) {
        // TODO: stash the details for all the existing tiles somewhere so right clicking can select that tile for painting
//      } else {
        this.enablePainting()
        this.paintTile(e)
//      }
    });
    document.getElementById("dungeon").addEventListener('mouseover', e => {this.paintTile(e)} );
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
    console.log("HERE")
    var map_tile_changes = []

    for(let tile_change of Array.from(document.getElementsByClassName("changed-map-tile"))){
      let [row, col] = tile_change.getAttribute("id").split("_").map(i => parseInt(i))
      let ttid = parseInt(tile_change.getAttribute("data-tile-template-id"))

      map_tile_changes.push({row: row, col: col, tile_template_id: ttid })
    }
    console.log(map_tile_changes)
    document.getElementById("map_tile_changes").value = JSON.stringify(map_tile_changes)
    //event.preventDefault()
  },
  enablePainting(){
    console.log("Enabled")
    this.painting = true
  },
  disablePainting(){
    console.log("Disable")
    this.painting = false
  },
  updateActiveTile(event){
    let tag = event.target.tagName == "SPAN" ? event.target.parentNode : event.target

    document.getElementById("active_tile_name").innerText = tag.getAttribute("title")
    document.getElementById("active_tile_character").innerHTML = tag.innerHTML
    document.getElementById("active_tile_description").innerText = tag.getAttribute("data-tile-template-description")
    document.getElementById("active_tile_responders").innerText = tag.getAttribute("data-tile-template-responders")

    this.selectedTileId = tag.getAttribute("data-tile-template-id")
    this.selectedTileHtml = tag.innerHTML
  },
  paintTile(event){
    if(!this.painting || this.painted) { return }
    if(event.target.tagName != "SPAN" && event.target.tagName != "TD"){ return }
    this.painted = true

    let map_location = event.target.tagName == "SPAN" ? event.target.parentNode : event.target

    if(!map_location) { return } // event picked up on bad element

    let old_tile = map_location.children[0]

    var new_tile = document.createElement("span")
    new_tile.innerHTML = this.selectedTileHtml

    map_location.insertBefore(new_tile, old_tile)
    map_location.removeChild(old_tile)
    map_location.setAttribute("data-tile-template-id", this.selectedTileId)
    map_location.setAttribute("class", "changed-map-tile")
  },
  selectedTileId: null,
  selectedTileHtml: null,
  painting: false,
  painted: false
}

export default DungeonEditor

