let Player = {
  init(socket, dungeonJs, element){ if(!element){ return }
    let playerUserIdHash = element.getAttribute("data-location-id")
    socket.connect()

    let playerChannel   = socket.channel("players:" + playerUserIdHash)


    playerChannel.on("message", (resp) => {
      dungeonJs.renderMessage(resp.message)
    })

    playerChannel.on("ping", ({count}) => console.log("PING", count))

    playerChannel.join()
      .receive("ok", (resp) => {
        dungeonJs.renderMessage("Entered the dungeon")
      })
      .receive("error", resp => console.log("join failed", resp))

    window.addEventListener('beforeunload', (event) => {
      socket.disconnect()
    })
  }
}

export default Player

