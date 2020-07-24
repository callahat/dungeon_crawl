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

      keysPressed[direction] = true

      switch(direction){
        case(72): // h
          $('#helpDetailModal').modal('show')
          break
        case(79): // o
          this.renderMessage("Open Direction?")
          this.actionMethod = this.open
          break
        case(67): // c
          this.renderMessage("Close Direction?")
          this.actionMethod = this.close
          break
        case(38):
        case(87):
          this.actionMethod(dungeonChannel, "up", keysPressed)
          break
        case(40):
        case(83):
          this.actionMethod(dungeonChannel, "down", keysPressed)
          break
        case(37):
        case(65):
          this.actionMethod(dungeonChannel, "left", keysPressed)
          break
        case(39):
        case(68):
          this.actionMethod(dungeonChannel, "right", keysPressed)
          break
      }
    })

    window.addEventListener("keyup", e => {
      delete keysPressed[e.keyCode || e.which]
    })

    window.addEventListener("focus", e => {
      keysPressed = {}
    })
  },
  move(dungeonChannel, direction, keysPressed){
    console.log(direction)
    console.log(shoot)
    let payload = {direction: direction},
        shoot = keysPressed[16], // shift key
        pull = keysPressed[80],  // p
        action

    if(shoot) {
      action = "shoot"
    } else if(pull) {
      action = "pull"
    } else {
      action = "move"
    }

    dungeonChannel.push(action, payload)
                  .receive("error", e => console.log(e))
  },
  open(dungeonChannel, direction, shift = false){
    this._useDoor(dungeonChannel, direction, "OPEN")
  },
  close(dungeonChannel, direction, shift = false){
    this._useDoor(dungeonChannel, direction, "CLOSE")
  },
  renderMessage(msg){
    let template = document.createElement("div")
    template.setAttribute("class", "d-flex flex-row no-gutters")
    template.innerHTML = `
      <div class="col-2 timestamp">
        ${this._messageTimestamp()}
      </div>
      <div>
        ${msg}
      </div>
    `
    document.getElementById("sidebar_message_box").appendChild(template)
    document.getElementById("sidebar_message_box").scrollTop = document.getElementById("sidebar_message_box").scrollHeight
  },
  _messageTimestamp(){
    return new Date().toLocaleTimeString("en-US", this.timestampOptions)
  },
  _useDoor(dungeonChannel, direction, action){
    let payload = {direction: direction, action: action}
    dungeonChannel.push("use_door", payload)
                  .receive("error", resp => this.renderMessage(resp.msg) )
    this.actionMethod = this.move
  },
  actionMethod: null,
  timestampOptions: {
         hour12 : false,
         hour:  "2-digit",
         minute: "2-digit"
  },
}

export default Dungeon

