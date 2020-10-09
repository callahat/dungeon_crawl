let Dungeon = {
  init(socket, element){ if(!element){ return }
    let dungeonId = element.getAttribute("data-instance-id")
    let readonly = element.getAttribute("data-readonly") == "true"
    socket.connect()

    if(!readonly){
      this.setupWindowListeners()
    }

    this.tuneInToChannel(socket, dungeonId)

    window.addEventListener('beforeunload', (event) => {
      socket.disconnect()
    })

    this.handleDungeonChange = function(msg) {
      this.dungeonChannel.leave()
      console.log("Left dungeon, joining " + msg.dungeon_id)

      document.getElementById("dungeon_instance").setAttribute("data-instance-id", msg.dungeon_id)
      document.getElementById("dungeon_instance").innerHTML = msg.dungeon_render
      this.tuneInToChannel(socket, msg.dungeon_id)
    }
  },
  handleDungeonChange: null,
  tuneInToChannel(socket, dungeonId) {

    this.dungeonChannel   = socket.channel("dungeons:" + dungeonId)

    this.dungeonChannel.on("tile_changes", (resp) => {
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

    this.dungeonChannel.on("ping", ({count}) => console.log("PING", count))

    let ressurectionEl
    if(ressurectionEl = document.getElementById("ressurect_me")){
      ressurectionEl.addEventListener('click', e => {this.respawn()} )
    }

    let messageSendEl, words, payload, multilineMessageEl
    if(messageSendEl = document.getElementById("submit_message")){
      messageSendEl.addEventListener('click', e => { this.sendMessage() });
      document.getElementById("message_field").addEventListener('keypress', e => {
        if (e.key === 'Enter' && !e.shiftKey) { this.sendMessage() }
      });
      document.getElementById("message_field").addEventListener('focus', (e) => { this.typing = true })
      document.getElementById("message_field").addEventListener('blur', (e) => { this.typing = false })

      multilineMessageEl = document.getElementById("multilineMessage")
      multilineMessageEl.addEventListener('click', (e) => {
        if(e.target.matches(".messageLink")){
          let label = e.target.getAttribute("data-label"),
              tile_id = e.target.getAttribute("data-tile-id")
          $('#messageModal').modal('hide')
          this.dungeonChannel.push("message_action", {label: label, tile_id: tile_id})
          multilineMessageEl.innerHTML = ""
        }
      })
    }

    this.dungeonChannel.join()
      .receive("ok", (resp) => {
        console.log("joined the dungeons channel!")
      })
      .receive("error", resp => console.log("join failed", resp))
  },
  setupWindowListeners(){
    let suppressDefaultKeys = [37,38,39,40],
        keysPressed = {}
    this.actionMethod = this.move

    window.addEventListener("keydown", e => {
      if(this.typing){ return }

      if(parseInt(document.getElementById("health").innerText) <= 0) {
        $('#respawnModal').modal('show')
        return
      }

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
          this.actionMethod("up", keysPressed)
          break
        case(40):
        case(83):
          this.actionMethod("down", keysPressed)
          break
        case(37):
        case(65):
          this.actionMethod("left", keysPressed)
          break
        case(39):
        case(68):
          this.actionMethod("right", keysPressed)
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
  move(direction, keysPressed){
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

    this.dungeonChannel.push(action, payload)
                       .receive("error", e => console.log(e))
  },
  open(direction, shift = false){
    this._useDoor(direction, "OPEN")
  },
  close(direction, shift = false){
    this._useDoor(direction, "CLOSE")
  },
  renderMessage(msg){
    if(msg == this.lastMessage) { return }
    this.lastMessage = msg

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
  renderMessageModal(msg){
    let messageArea = document.getElementById("multilineMessage")

    messageArea.innerHTML = msg.join("<br/>")

    $('#messageModal').modal('show')
  },
  respawn(){
    this.dungeonChannel.push("respawn", {})
                       .receive("error", e => console.log(e))
  },
  sendMessage(){
    let words = document.getElementById("message_field").value.trim(),
        payload
    if(words != ""){
      payload = {words: words}
      this.dungeonChannel.push("speak", payload)
        .receive("error", resp => this.renderMessage("Could not send message") )
        .receive("ok", resp => {
                         this.renderMessage("<b>Me:</b> " + resp.safe_words)
                         document.getElementById("message_field").value = ""
                       } )
    } else {
      document.getElementById("message_field").value = ""
    }
  },
  _messageTimestamp(){
    return new Date().toLocaleTimeString("en-US", this.timestampOptions)
  },
  _useDoor(direction, action){
    let payload = {direction: direction, action: action}
    this.dungeonChannel.push("use_door", payload)
                       .receive("error", resp => this.renderMessage(resp.msg) )
    this.actionMethod = this.move
  },
  actionMethod: null,
  timestampOptions: {
         hour12 : false,
         hour:  "2-digit",
         minute: "2-digit"
  },
  dungeonChannel: null,
  lastMessage: null,
  typing: false
}

export default Dungeon

