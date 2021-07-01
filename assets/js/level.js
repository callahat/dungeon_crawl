let Level = {
  init(socket, element){ if(!element){ return }
    let levelId = element.getAttribute("data-level-id")
    this.dungeonId = element.getAttribute("data-dungeon-id")
    socket.connect()

    this.setupWindowListeners()

    this.tuneInToChannel(socket, levelId)

    window.addEventListener('beforeunload', (event) => {
      socket.disconnect()
    })

    this.handleLevelChange = function(msg) {
      this.levelChannel.leave()
      console.log("Left dungeon, joining " + msg.level_id)

      document.getElementById("level_instance").setAttribute("data-level-id", msg.level_id)
      document.getElementById("level_instance").innerHTML = msg.level_render
      this.tuneInToChannel(socket, msg.level_id)

      if(msg.fade) {
        for(let td of Array.from(document.querySelectorAll("#level_instance td"))){
          if(td.id != msg.player_coord_id){ td.classList.add("entry-fade") }
        }
        setTimeout(() => {
          for(let td of Array.from(document.querySelectorAll(".entry-fade"))){
            td.classList.add("entry-faded")
            td.classList.remove("entry-fade")
          }
        }, 1000)
      }
    }
  },
  handleLevelChange: null,
  tuneInToChannel(socket, levelId) {
    this.levelChannel = socket.channel("level:" + this.dungeonId + ":" + levelId)

    this.levelChannel.on("tile_changes", (resp) => {
      this.tileChanges(resp.tiles)
    })

    this.levelChannel.on("full_render", (msg) => {
      document.getElementById("level_instance").innerHTML = msg.level_render
    })
    // These could be used to announce something, but the tile updating has been consolidated
    //levelChannel.on("player_left", (resp) => {
    //  document.getElementById(resp.row + "_" + resp.col).innerHTML = resp.tile
    //})
    //levelChannel.on("player_joined", (resp) => {
    //  document.getElementById(resp.row + "_" + resp.col).innerHTML = resp.tile
    //})

    this.levelChannel.on("ping", ({count}) => console.log("PING", count))

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
          this.levelChannel.push("message_action", {label: label, tile_id: tile_id})
          multilineMessageEl.innerHTML = ""
        }
      })
    }

    this.levelChannel.join()
      .receive("ok", (resp) => {
        console.log("joined the dungeons channel!")
      })
      .receive("error", resp => console.log("join failed", resp))
  },
  setupWindowListeners(){
    let suppressDefaultKeys = [13,32,37,38,39,40],
        keysPressed = {}
    this.actionMethod = this.move

    window.addEventListener("keydown", e => {
      if(this.typing){ return }

      if(document.gameover) {
        $('#messageModal').modal('hide')
        $('#gameoverModal').modal('show')
        return
      }

      if(parseInt(document.getElementById("health").innerText) <= 0) {
        $('#messageModal').modal('hide')
        $('#respawnModal').modal('show')
        return
      }

      let direction = e.keyCode || e.which
      if(suppressDefaultKeys.indexOf(direction) > 0) {
        e.preventDefault()
      }

      if($('#messageModal.show').length == 1 && this.textLinkPointer != null){
        this._messageModalKeypressHandler(direction)
        return
      } else {
        $('#messageModal').modal('hide')
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
    // console.log(direction)
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

    this.levelChannel.push(action, payload)
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
    let messageArea = document.getElementById("multilineMessage"),
        messageLinks

    messageArea.innerHTML = msg.join("<br/>")
    this.textLinks = document.getElementsByClassName("messageLink")

    if(this.textLinks.length > 0){
      this.textLinkPointer = 0
      this._textLinkDisplayUpdate()
    } else {
      this.textLinks = null
      this.textLinkPointer = null
    }

    $('#messageModal').modal('show')
  },
  respawn(){
    this.levelChannel.push("respawn", {})
                       .receive("error", e => console.log(e))
  },
  sendMessage(){
    let words = document.getElementById("message_field").value.trim(),
        payload
    if(words != ""){
      payload = {words: words}
      this.levelChannel.push("speak", payload)
        .receive("error", resp => this.renderMessage("Could not send message") )
        .receive("ok", resp => {
                         this.renderMessage("<b>Me:</b> " + resp.safe_words)
                         document.getElementById("message_field").value = ""
                       } )
    } else {
      document.getElementById("message_field").value = ""
    }
  },
  tileFogger(tiles){
    let tdEl;
    for(let tile of tiles){
      tdEl = document.getElementById(tile.row + "_" + tile.col)
      tdEl.classList.add("fog")
      tdEl.innerHTML = "<div style='background-color: darkgray'>░</div>"
    }
  },
  tileChanges(tiles){
    let tdEl;
    for(let tile of tiles){
      tdEl = document.getElementById(tile.row + "_" + tile.col)
      tdEl.classList.remove("fog")
      tdEl.innerHTML = tile.rendering
      if(tdEl.children[0].classList.contains("animate")){
        window.TileAnimation.renderTile(window.TileAnimation, tdEl.children[0])
      }
    }
  },
  _messageTimestamp(){
    return new Date().toLocaleTimeString("en-US", this.timestampOptions)
  },
  _useDoor(direction, action){
    let payload = {direction: direction, action: action}
    this.levelChannel.push("use_door", payload)
                       .receive("error", resp => this.renderMessage(resp.msg) )
    this.actionMethod = this.move
  },
  _messageModalKeypressHandler(keyPressed){
    let linksLength = this.textLinks.length
    switch(keyPressed){
      case(40): // down
      case(83):
        this.textLinkPointer = (this.textLinkPointer + 1) % linksLength
        this._textLinkDisplayUpdate()
        break
      case(38): // up
      case(87):
        this.textLinkPointer = (linksLength + this.textLinkPointer - 1) % linksLength
        this._textLinkDisplayUpdate()
        break
      case(13):
      case(32):
        // "Click" current link
        this.textLinks[this.textLinkPointer].click()
      default:
        this.textLinkPointer = null
        $('#messageModal').modal('hide')
        break;
    }
  },
  _textLinkDisplayUpdate(){
    $(".messageLink").text(function () { return $(this).text().replace(/^./, "-"); });
    $(".messageLink").eq(this.textLinkPointer).text(function () { return $(this).text().replace(/^./, "▶"); });
  },
  actionMethod: null,
  timestampOptions: {
         hour12 : false,
         hour:  "2-digit",
         minute: "2-digit"
  },
  levelChannel: null,
  lastMessage: null,
  dungeonId: null,
  typing: false,
  textLinks: null,
  textLinkPointer: null
}

export default Level

