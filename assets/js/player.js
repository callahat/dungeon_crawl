let Player = {
  init(socket, element){ if(!element){ return }
    let playerUserIdHash = element.getAttribute("data-location-id")
    socket.connect()

    let playerChannel   = socket.channel("players:" + playerUserIdHash)


    playerChannel.on("message", (resp) => {
      document.getElementById("short_comm").innerText = resp.message
    })

    playerChannel.on("ping", ({count}) => console.log("PING", count))

    playerChannel.join()
      .receive("ok", (resp) => {
        console.log("joined the players channel!")
      })
      .receive("error", resp => console.log("join failed", resp))
  }
}

export default Player

