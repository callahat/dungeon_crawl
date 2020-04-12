let Player = {
  init(socket, dungeonJs, element){ if(!element){ return }
    let playerUserIdHash = element.getAttribute("data-location-id")
    socket.connect()

    let playerChannel   = socket.channel("players:" + playerUserIdHash)


    playerChannel.on("message", (resp) => {
      dungeonJs.renderMessage(resp.message)
    })

    playerChannel.on("ping", ({count}) => console.log("PING", count))

    playerChannel.on("stat_update", (resp) => {
      this.statUpdate(resp.stats)
    })

    playerChannel.join()
      .receive("ok", (resp) => {
        dungeonJs.renderMessage("Entered the dungeon")
      })
      .receive("error", resp => console.log("join failed", resp))

    window.addEventListener('beforeunload', (event) => {
      socket.disconnect()
    })
  },
  statUpdate(stats){
    document.getElementById("health").innerText = stats.health
    document.getElementById("gems").innerText = stats.gems
    document.getElementById("cash").innerText = stats.cash
    document.getElementById("ammo").innerText = stats.ammo
  }
}

export default Player

