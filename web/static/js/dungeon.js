let Dungeon = {
  init(socket, element){ if(!element){ return }
    let dungeonId = element.getAttribute("data-dungeon-id")
console.log("dungeonId: ")
console.log(dungeonId)
console.log("Connecting...")
    socket.connect()
console.log("Dungeoned inited")
    this.onReady(dungeonId, socket)
  },
  onReady(dungeonId, socket){
    let dungeonChannel   = socket.channel("dungeons:" + dungeonId)
console.log("joining channel: " + "dungeons:" + dungeonId)
    window.addEventListener("keydown", e => {
      let direction = e.keyCode || e.which
          console.log(direction)
      //WASD or arrow keys
      switch(direction){
        case(38,87):
          console.log("Up")
          break
        case(40,83):
          console.log("Down")
          break
        case(37,65):
          console.log("Left")
          break
        case(39,68):
          console.log("Right")
          break
      }

//      if(code sgInput.value == ""){ return }
//     let payload = {body: msgInput.value, at: Player.getCurrentTime()}
//      vidChannel.push("new_annotation", payload)
//                .receive("error", e => console.log(e))
//      msgInput.value = ""
    })
/*
    vidChannel.on("new_annotation", (resp) => {
      vidChannel.params.last_seen_id = resp.id
      this.renderAnnotation(msgContainer, resp)
    })

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
        console.log(resp)
//        let ids = resp.annotations.map(ann => ann.id)
//        if(ids.length > 0) {vidChannel.params.last_seen_id = Math.max(...ids)}
//        this.scheduleMessages(msgContainer, resp.annotations)
      })
      .receive("error", resp => console.log("join failed", resp))
    dungeonChannel.on("ping", ({count}) => console.log("PING", count))
  }
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

