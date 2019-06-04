let Dungeon = {
  init(socket, element){ if(!element){ return }
    let suppressDefaultKeys = [37,38,39,40]
    let dungeonId = element.getAttribute("data-dungeon-id")
    socket.connect()

    let dungeonChannel   = socket.channel("dungeons:" + dungeonId)

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
    dungeonChannel.on("tile_update", (resp) => {
//      console.log("Got tile_update")
//      console.log(resp)
//      console.log(dungeonChannel.params)
      let old_location = resp.old_location
      let new_location = resp.new_location
      document.getElementById(old_location.row + "_" + old_location.col).innerHTML = old_location.tile
      document.getElementById(new_location.row + "_" + new_location.col).innerHTML = "@"
    })
    dungeonChannel.on("door_changed", (resp) => {
//      console.log("Got door_changed")
//      console.log(resp)
//      console.log(dungeonChannel.params)
      let door_location = resp.door_location
      document.getElementById(door_location.row + "_" + door_location.col).innerHTML = door_location.tile
    })

    dungeonChannel.on("ping", ({count}) => console.log("PING", count))

    dungeonChannel.join()
      .receive("ok", (resp) => {
        console.log("joined the dungeons channel!")
      })
      .receive("error", resp => console.log("join failed", resp))
  },
  move(dungeonChannel, direction){
    console.log(direction)
    let payload = {direction: direction}
    dungeonChannel.push("move", payload)
                  .receive("error", e => console.log(e))
    document.getElementById("short_comm").innerText = "Moving..."
  },
  open(dungeonChannel, direction){
    this._useDoor(dungeonChannel, direction, "open")
  },
  close(dungeonChannel, direction){
    this._useDoor(dungeonChannel, direction, "close")
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

