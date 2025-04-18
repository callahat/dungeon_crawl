let Level = {
  init(socket, sound, element){ if(!element){ return }
    let levelNumber = element.getAttribute("data-level-number"),
        ownerId = element.getAttribute("data-owner-id")
    this.dungeonId = element.getAttribute("data-dungeon-id")
    this.sound = sound
    socket.connect()

    this.setupWindowListeners()

    this.tuneInToChannel(socket, levelNumber, ownerId)

    this.fadeTimeout = setTimeout(() => { this.removeFade(1) }, 1000)

    window.addEventListener('beforeunload', (event) => {
      socket.disconnect()
    })

    this.handleLevelChange = function(msg) {
      this.levelChannel.leave()
      console.log("Left dungeon, joining level " + msg.level_number)

      document.getElementById("level_instance").setAttribute("data-level-id", msg.level_id)
      document.getElementById("level_instance").innerHTML = msg.level_render
      this.tuneInToChannel(socket, msg.level_number, msg.level_owner_id)

      if(msg.fade_overlay) {
        clearTimeout(this.fadeTimeout);
        document.getElementById("fade_overlay").innerHTML = msg.fade_overlay
        this.fadeTimeout = setTimeout(() => { this.removeFade(1) }, 100)
      }
    }

    this._soundEffectVolumeUpdate(this.soundEffectVolume)
  },
  removeFade(count, range = 1) {
    let query = []
    for(let i = 0; i < range; i++){ query.push(`.fade_range_${count + i}`) }
    let fadedCells = Array.from(document.querySelectorAll(query.join(",")))
    if(fadedCells.length > 0){
      for(let td of fadedCells){
        td.classList = []
      }
      let new_range = count < 10 ? range : range + 1
      this.fadeTimeout = setTimeout(() => { this.removeFade(count + range, new_range) }, 100)
    } else {
      document.getElementById("fade_overlay").innerHTML = ""
    }
  },
  handleLevelChange: null,
  tuneInToChannel(socket, levelNumber, ownerId) {
    this.levelChannel = socket.channel("level:" + this.dungeonId + ":" + levelNumber + ":" + (ownerId || ""))

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
              tile_id = e.target.getAttribute("data-tile-id"),
              item_slug = e.target.getAttribute("data-item-slug")
          $('#messageModal').modal('hide')
          this.levelChannel.push("message_action", {label: label, tile_id: tile_id, item_slug: item_slug})
          multilineMessageEl.innerHTML = ""
        }
      })
    }

    this.levelChannel.join()
      .receive("ok", (resp) => {
        console.log("joined the levels channel!")
      })
      .receive("error", resp => console.log("join failed", resp))
  },
  setupWindowListeners(){
    let suppressDefaultKeys = ['enter',' ','arrowup','arrowdown','arrowleft','arrowright'],
        keysPressed = {},
        direction
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

      document.getElementById("soundEffectVolume").addEventListener("change", e => {
        this._soundEffectVolumeUpdate(parseInt(e.target.value))
      })

      direction = e.key.toLowerCase()
      if(suppressDefaultKeys.indexOf(direction) >= 0) {
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
        case('e'): // e
          this.renderMessageModal(this.equippableItems)
          $('#messageModal').modal('show')
          break
        case('h'): // h
          $('#helpDetailModal').modal('show')
          break
        case('v'): // v
          $('#volumeModal').modal('show')
          break
        case('t'): // t
          this.lightTorch()
          break
        case('o'): // o
          this.renderMessage("Open Direction?", true)
          this.actionMethod = this.open
          break
        case('c'): // c
          this.renderMessage("Close Direction?")
          this.actionMethod = this.close
          break
        case('w'):
        case('arrowup'):
          this.actionMethod("up", keysPressed)
          break
        case('s'):
        case('arrowdown'):
          this.actionMethod("down", keysPressed)
          break
        case('a'):
        case('arrowleft'):
          this.actionMethod("left", keysPressed)
          break
        case('d'):
        case('arrowright'):
          this.actionMethod("right", keysPressed)
          break
      }
    })

    window.addEventListener("keyup", e => {
      delete keysPressed[e.key.toLowerCase()]
    })

    window.addEventListener("focus", e => {
      keysPressed = {}
    })
  },
  move(direction, keysPressed){
    // console.log(direction)
    let payload = {direction: direction},
        use_item = keysPressed['shift'], // shift key
        pull = keysPressed['p'],  // p
        action

    if(use_item) {
      action = "use_item"
    } else if(pull) {
      action = "pull"
    } else {
      action = "move"
    }

    this.levelChannel.push(action, payload)
      .receive("moved", (_) => this.sound.playEffect([...this.soundFootstep], this.soundEffectVolume / 100))
      .receive("error", e => console.log(e))
  },
  open(direction, shift = false){
    this._useDoor(direction, "OPEN")
  },
  close(direction, shift = false){
    this._useDoor(direction, "CLOSE")
  },
  lightTorch(){
    this.levelChannel.push("light_torch", {})
        .receive("error", e => console.log(e))
  },
  renderMessage(msg, flashMessage=false){
    if(msg == this.lastMessage) { return }
    this.lastMessage = msg

    if(flashMessage) {
      this.renderFlashingMessage(msg)
    }

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
  renderFlashingMessage(msg){
    let el = $('#flashingMessageBox')
    clearTimeout(this.flashingMessageTimeout)
    el.prop("classList").add("animate")
    el.text(msg)
    el.show()
    this.flashingMessageTimeout = setTimeout(() => { this.cleanupFlashingMessage() }, 3000)
  },
  cleanupFlashingMessage(){
    let el = $('#flashingMessageBox')
    el.hide()
    el.prop("classList").remove("animate")
    el.text("")
  },
  respawn(){
    this.levelChannel.push("respawn", {})
                       .receive("error", e => console.log(e))
  },
  sendMessage(){
    if(this.sendingMessage) { return }

    this.sendingMessage = true

    let words = document.getElementById("message_field").value.trim(),
        payload
    if(words != ""){
      payload = {words: words}
      this.levelChannel.push("speak", payload)
        .receive("error", resp => this.renderMessage("Could not send message") )
        .receive("ok", resp => {
                         if(resp.safe_words != "") {
                           this.sound.playEffect(this.soundSendMessage, this.soundEffectVolume / 100)
                           this.renderMessage("<b>Me:</b> " + resp.safe_words)
                         }
                         document.getElementById("message_field").value = ""
                         this.sendingMessage = false
                       } )
      document.getElementById("message_field").blur()
    } else {
      document.getElementById("message_field").value = ""
      this.sendingMessage = false
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
                       .receive("error", resp => this.renderMessage(resp.msg, true) )
    this.actionMethod = this.move
  },
  _messageModalKeypressHandler(keyPressed){
    let linksLength = this.textLinks.length
    switch(keyPressed){
      case('arrowdown'): // down
      case('s'):
        this.textLinkPointer = (this.textLinkPointer + 1) % linksLength
        this._textLinkDisplayUpdate()
        break
      case('arrowup'): // up
      case('w'):
        this.textLinkPointer = (linksLength + this.textLinkPointer - 1) % linksLength
        this._textLinkDisplayUpdate()
        break
      case('enter'):
      case(' '):
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
  _soundEffectVolumeUpdate(value){
    document.getElementById("soundEffectVolume").value = value
    this.soundEffectVolume = value
    document.getElementById("soundEffectVolumeDisplay").innerText =  this.soundEffectVolume + "%"
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
  textLinkPointer: null,
  fadeTimeout: null,
  flashingMessageTimeout: null,
  sendingMessage: false,
  equippableItems: [],
  sound: null,
  soundFootstep: [2.25,,8,,.06,.01,2,2.25,-19,-79,409,.01,,,6.6,,.2,.57,,.8], // bit footstep
  soundRecieveMessage: [,0,900,,.03,.03,1,1.03, 10,,,,,,,,,.31,.01],
  soundSendMessage:    [,0,900,,.03,.03,1,1.03,-10,,,,,,,,,.31,.01],
  soundEffectVolume: 100,
}

export default Level

