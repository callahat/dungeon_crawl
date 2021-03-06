let LevelAdmin = {
  init(socket, element){ if(!element){ return }
    let levelId = element.getAttribute("data-level-id")
    let readonly = element.getAttribute("data-readonly") == "true"
    this.dungeonId = element.getAttribute("data-dungeon-id")
    socket.connect()

    window.addEventListener('beforeunload', (event) => {
      socket.disconnect()
    })

    this.tuneInToChannel(socket, levelId)
  },
  tuneInToChannel(socket, levelId) {
    this.levelAdminChannel = socket.channel("level_admin:" + this.dungeonId + ":" + levelId)

    this.levelAdminChannel.on("tile_changes", (resp) => {
      this.tileChanges(resp.tiles)
    })

    this.levelAdminChannel.on("full_render", (msg) => {
      document.getElementById("level_instance").innerHTML = msg.dungeon_render
    })
    // These could be used to announce something, but the tile updating has been consolidated
    //levelAdminChannel.on("player_left", (resp) => {
    //  document.getElementById(resp.row + "_" + resp.col).innerHTML = resp.tile
    //})
    //levelAdminChannel.on("player_joined", (resp) => {
    //  document.getElementById(resp.row + "_" + resp.col).innerHTML = resp.tile
    //})

    this.levelAdminChannel.join()
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
  levelAdminChannel: null,
  dungeonId: null
}

export default LevelAdmin

