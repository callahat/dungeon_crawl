let LevelAdmin = {
  init(socket, sound, element){ if(!element){ return }
    let levelNumber = element.getAttribute("data-level-number"),
        ownerId = element.getAttribute("data-owner-id")
    this.dungeonId = element.getAttribute("data-dungeon-id")
    socket.connect()

    window.addEventListener('beforeunload', (event) => {
      socket.disconnect()
    })

    this.sound = sound

    this.tuneInToChannel(socket, levelNumber, ownerId)
  },
  tuneInToChannel(socket, levelNumber, ownerId) {
    this.levelAdminChannel = socket.channel("level_admin:" + this.dungeonId + ":" + levelNumber + ":" + ownerId)

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

        // rerender, as the first page load might be stale at this point, so tile updates
        // may cause wierd artifacts
        this.levelAdminChannel.push("rerender", {})
          .receive("ok", resp => document.getElementById("level_admin").innerHTML = resp)
      })
      .receive("error", resp => console.log("join failed", resp))

    this.levelAdminChannel.on("sound_effects", (msg) => {
      for(let sound of msg.sound_effects){
        this.sound.playEffectString(sound.zzfx_params, sound.volume_modifier)
      }
    })
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
  dungeonId: null,
  sound: null
}

export default LevelAdmin

