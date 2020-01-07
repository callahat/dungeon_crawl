let Dungeon = {
  init(socket, element){ if(!element){ return }
    let dungeonId = element.getAttribute("data-instance-id")
    let readonly = element.getAttribute("data-readonly") == "true"
    socket.connect()

    let dungeonChannel   = socket.channel("dungeons:" + dungeonId)

    if(!readonly){
      this.setupWindowListeners(dungeonChannel)
    }

    dungeonChannel.on("tile_changes", (resp) => {
      let location;
      for(let tile of resp.tiles){
        document.getElementById(tile.row + "_" + tile.col).innerHTML = tile.rendering
      }
    })
    // These could be used to announce something, but the tile updating has been consolidated
    //dungeonChannel.on("player_left", (resp) => {
    //  document.getElementById(resp.row + "_" + resp.col).innerHTML = resp.tile
    //})
    //dungeonChannel.on("player_joined", (resp) => {
    //  document.getElementById(resp.row + "_" + resp.col).innerHTML = resp.tile
    //})

    dungeonChannel.on("ping", ({count}) => console.log("PING", count))

    dungeonChannel.join()
      .receive("ok", (resp) => {
        console.log("joined the dungeons channel!")
      })
      .receive("error", resp => console.log("join failed", resp))

    window.addEventListener('beforeunload', (event) => {
      socket.disconnect()
    })
  },
  setupWindowListeners(dungeonChannel){
    let suppressDefaultKeys = [37,38,39,40]
    this.actionMethod = this.move

    window.addEventListener("keydown", e => {
      let direction = e.keyCode || e.which
      if(suppressDefaultKeys.indexOf(direction) > 0) {
        e.preventDefault()
      }
      // document.getElementById("short_comm").innerHTML = direction
      // console.log(direction)
      // arrow keys or WASD, respectiv
      switch(direction){
        case(79): // o
          document.getElementById("short_comm").innerText = "Open Direction?"
          this.actionMethod = this.open
          break
        case(67): // c
          document.getElementById("short_comm").innerText = "Close Direction?"
          this.actionMethod = this.close
          break
        case(38):
        case(87):
          this.actionMethod(dungeonChannel, "up")
          break
        case(40):
        case(83):
          this.actionMethod(dungeonChannel, "down")
          break
        case(37):
        case(65):
          this.actionMethod(dungeonChannel, "left")
          break
        case(39):
        case(68):
          this.actionMethod(dungeonChannel, "right")
          break
      }
    })
  },
  move(dungeonChannel, direction){
    console.log(direction)
    let payload = {direction: direction}
    document.getElementById("short_comm").innerText = "Moving..."
    dungeonChannel.push("step", payload)
                  .receive("error", resp => document.getElementById("short_comm").innerHTML = resp.msg)
    dungeonChannel.push("move", payload)
                  .receive("error", e => console.log(e))
  },
  open(dungeonChannel, direction){
    this._useDoor(dungeonChannel, direction, "OPEN")
  },
  close(dungeonChannel, direction){
    this._useDoor(dungeonChannel, direction, "CLOSE")
  },
  _useDoor(dungeonChannel, direction, action){
    let payload = {direction: direction, action: action}
    dungeonChannel.push("use_door", payload)
                  .receive("error", resp => document.getElementById("short_comm").innerHTML = resp.msg)
    this.actionMethod = this.move
    document.getElementById("short_comm").innerText = "Moving..."
  },
  actionMethod: null
}

export default Dungeon

