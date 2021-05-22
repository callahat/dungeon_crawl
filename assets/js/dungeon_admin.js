let DungeonAdmin = {
  init(socket, element){ if(!element){ return }
    let dungeonId = element.getAttribute("data-instance-id")
    let readonly = element.getAttribute("data-readonly") == "true"
    this.mapSetId = element.getAttribute("data-map-set-id")
    socket.connect()

    window.addEventListener('beforeunload', (event) => {
      socket.disconnect()
    })

    this.tuneInToChannel(socket, dungeonId)
  },
  tuneInToChannel(socket, dungeonId) {
    this.dungeonChannel = socket.channel("dungeon_admin:" + this.mapSetId + ":" + dungeonId)

    this.dungeonChannel.on("tile_changes", (resp) => {
      this.tileChanges(resp.tiles)
    })

    this.dungeonChannel.on("full_render", (msg) => {
      document.getElementById("dungeon_instance").innerHTML = msg.dungeon_render
    })
    // These could be used to announce something, but the tile updating has been consolidated
    //dungeonChannel.on("player_left", (resp) => {
    //  document.getElementById(resp.row + "_" + resp.col).innerHTML = resp.tile
    //})
    //dungeonChannel.on("player_joined", (resp) => {
    //  document.getElementById(resp.row + "_" + resp.col).innerHTML = resp.tile
    //})

    this.dungeonChannel.join()
      .receive("ok", (resp) => {
        console.log("joined the dungeon admin channel!")
      })
      .receive("error", resp => console.log("join failed", resp))
  },
  tileChanges(tiles){
    let location, tdEl;
    for(let tile of tiles){
      tdEl = document.getElementById(tile.row + "_" + tile.col)
      tdEl.classList.remove("fog")
      tdEl.innerHTML = tile.rendering
      if(tdEl.children[0].classList.contains("animate")){
        window.TileAnimation.renderTile(window.TileAnimation, tdEl.children[0])
      }
    }
  },
  dungeonChannel: null,
  mapSetId: null
}

export default DungeonAdmin

