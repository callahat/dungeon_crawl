let Player = {
  init(socket, levelJs, element){ if(!element){ return }
    let playerUserIdHash = element.getAttribute("data-location-id")
    socket.connect()

    let playerChannel = socket.channel("players:" + playerUserIdHash)

    playerChannel.on("change_level", (msg) => {
      levelJs.handleLevelChange(msg)

      playerChannel.push("update_visible", {})
                   .receive("error", e => console.log(e))
    })

    playerChannel.on("visible_tiles", (msg) => {
      levelJs.tileFogger(msg.fog)
      levelJs.tileChanges(msg.tiles)
    })

    playerChannel.on("message", (resp) => {
      if(!resp.modal) {
        levelJs.renderMessage(resp.message)
      } else {
        levelJs.renderMessageModal(resp.message)
      }
    })

    playerChannel.on("ping", ({count}) => console.log("PING", count))

    playerChannel.on("stat_update", (resp) => {
      this.statUpdate(resp.stats)
    })

    playerChannel.on("gameover", (resp) => {
      this.gameover(resp)
    })

    playerChannel.join()
      .receive("ok", (resp) => {
        levelJs.renderMessage("Entered the level")

        playerChannel.push("refresh_level", {})
                     .receive("error", e => console.log(e))
      })
      .receive("error", function(resp){
         console.log("join failed", resp)
         if(resp.reload){ window.location.reload() }
      })

    window.addEventListener('beforeunload', (event) => {
      socket.disconnect()
    })
  },
  statUpdate(stats){
    document.getElementById("score").innerHTML = stats.score
    document.getElementById("health").innerText = stats.health
    document.getElementById("gems").innerText = stats.gems
    document.getElementById("cash").innerText = stats.cash
    document.getElementById("ammo").innerText = stats.ammo
    document.getElementById("keys").innerHTML = stats.keys
    if(parseInt(stats.health) <= 0 && !document.gameover) {
      $('#respawnModal').modal('show')
    }
  },
  gameover(resp){
    document.gameover = true
    let scoreboard = document.getElementById("scoreboard")
    let params = resp.score_id == undefined ? "" : "?score_id=" + resp.score_id + "&dungeon_id=" + resp.dungeon_id
    if(scoreboard){
      scoreboard.setAttribute("data-to", scoreboard.getAttribute("data-to") + params)
    }
    $('#gameoverModal').modal('show')
  }
}

export default Player

