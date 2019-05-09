let Dungeon = {
  init(socket, element){ if(!element){ return }
    let dungeonId = element.getAttribute("data-dungeon-id")
    socket.connect()

    let dungeonChannel   = socket.channel("dungeons:" + dungeonId)

    this.actionMethod = this.move

    window.addEventListener("keydown", e => {
      let direction = e.keyCode || e.which
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
      return(false)
//      if(code sgInput.value == ""){ return }
//     let payload = {body: msgInput.value, at: Player.getCurrentTime()}
//      vidChannel.push("new_annotation", payload)
//                .receive("error", e => console.log(e))
//      msgInput.value = ""
    })
    dungeonChannel.on("tile_update", (resp) => {
      console.log("Got tile_update")
      console.log(resp)
      console.log(dungeonChannel.params)
      let old_location = resp.old_location
      let new_location = resp.new_location
      document.getElementById(old_location.row + "_" + old_location.col).innerHTML = old_location.tile
      document.getElementById(new_location.row + "_" + new_location.col).innerHTML = "@"
//      dungeonChannel.params.last_seen_id = resp.id
//      this.renderAnnotation(msgContainer, resp)
    })
    dungeonChannel.on("door_changed", (resp) => {
      console.log("Got door_changed")
      console.log(resp)
      console.log(dungeonChannel.params)
      let door_location = resp.door_location
      document.getElementById(door_location.row + "_" + door_location.col).innerText = door_location.tile
//      dungeonChannel.params.last_seen_id = resp.id
//      this.renderAnnotation(msgContainer, resp)
    })

/*
    msgContainer.addEventListener("click", e => {
      e.preventDefault()
      let seconds = e.target.getAttribute("data-seek") || e.target.parentNode.getAttribute("data-seek")
      if(!seconds) { return }
      Player.seekTo(seconds)
    })
*/
    dungeonChannel.join()
      .receive("ok", (resp) => {
        console.log("joined the dungeons channel!")
//        let ids = resp.annotations.map(ann => ann.id)
//        if(ids.length > 0) {vidChannel.params.last_seen_id = Math.max(...ids)}
//        this.scheduleMessages(msgContainer, resp.annotations)
      })
      .receive("error", resp => console.log("join failed", resp))
    dungeonChannel.on("ping", ({count}) => console.log("PING", count))
  },
  move(dungeonChannel, direction){
    console.log(direction)
    let payload = {direction: direction}
    dungeonChannel.push("move", payload)
                  .receive("error", e => console.log(e))
  },
  open(dungeonChannel, direction){
    let payload = {direction: direction}
    dungeonChannel.push("open", payload)
                  .receive("baddoor", resp => document.getElementById("short_comm").innerHTML = resp.msg)
                  .receive("error", e => console.log(e))
    this.actionMethod = this.move
    document.getElementById("short_comm").innerText = "Moving..."
  },
  close(dungeonChannel, direction){
    let payload = {direction: direction}
    dungeonChannel.push("close", payload)
                  .receive("baddoor", resp => document.getElementById("short_comm").innerHTML = resp.msg)
                  .receive("error", e => console.log(e))
    this.actionMethod = this.move
    document.getElementById("short_comm").innerText = "Moving..."
  },
  actionMethod: null
/*  esc(str){
    let div = document.createElement("div")
    div.appendChild(document.createTextNode(str))
    return div.innerHTML
  },
  renderAnnotation(msgContainer, {user, body, at}){
    let template = document.createElement("div")
    template.innerHTML = `
      <a href="#" data-seek="${this.esc(at)}">
        [${this.formatTime(at)}]
        <b>${this.esc(user.username)}</b>: ${this.esc(body)}
      </a>
    `
    msgContainer.appendChild(template)
    msgContainer.scrollTop = msgContainer.scrollHeight
  }, 
  scheduleMessages(msgContainer, annotations){
    setTimeout(() => {
      let ctime = Player.getCurrentTime()
      let remaining = this.renderAtTime(annotations, ctime, msgContainer)
      this.scheduleMessages(msgContainer, remaining)
    }, 1000)
  },
  renderAtTime(annotations, seconds, msgContainer){
    return annotations.filter( ann => {
      if(ann.at > seconds){
        return true
      } else {
        this.renderAnnotation(msgContainer, ann)
        return false
      }
    })
  },
  formatTime(at){
    let date = new Date(null)
    date.setSeconds(at / 1000)
    return date.toISOString().substr(14,5)
  } */
}

export default Dungeon

