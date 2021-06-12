let TileAnimation = {
  init(){
    var paths = ["dungeons/\\d+",
                 "crawler",
                 "tile_templates",
                 "manage/dungeon_processes/\\d+/level_processes/\\d+"].join("|")
    if(document.URL.match(new RegExp(paths))){
      this.start()
    }
  },
  start(){
    if(!this.running){
      this.running = true
      this.intervalId = setInterval(this.animate, 100, this)
    }
  },
  stop(){
    this.running = false
    clearInterval(this.intervalId)
  },
  animate(context){
    context.tick += 1
    for(let tile of document.getElementsByClassName("animate")) { context.animateTile(context, tile) }
  },
  animateTile(context, element) {
    let period = parseInt(element.getAttribute("data-period") || 10)
    if(element.classList.contains("animate") && context.tick % period == 0){
      context.renderTile(context, element)
    }
  },
  renderTile(context, element){
    let period = parseInt(element.getAttribute("data-period") || 10)
    let characters =  element.getAttribute("data-characters"),
        colors = element.getAttribute("data-colors"),
        backgroundColors = element.getAttribute("data-background-colors"),

        pickFunction = element.classList.contains("random") ? context._random : context._sequence,

        character = pickFunction(context, period, characters, element.innerText),
        color = pickFunction(context, period, colors, element.style.color),
        backgroundColor = pickFunction(context, period, backgroundColors, element.style.backgroundColor)

    element.innerText = (character || " ")[0]
    element.style.color = color
    element.style.backgroundColor = backgroundColor
  },
  _splitList(data){
    return(data.split(",").map((d) => d.trim()))
  },
  _sequence(context, period, data, current) {
    if(data){
      let array = context._splitList(data)
      return(array[Math.floor(context.tick / period) % array.length])
    } else {
      return(current)
    }
  },
  _random(context, period, data, current){
    if(data){
      let array = context._splitList(data)
      return(array[Math.floor(Math.random() * array.length)])
    } else {
      return(current)
    }
  },
  intervalId: null,
  tick: 0,
  running: false
}

window.TileAnimation = TileAnimation
export default TileAnimation
