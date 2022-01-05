let Sound = {
  init(zzfx){
    this.zzfx = zzfx

    let effectPreviewElement = document.getElementById("sound_effect_previews")

    if(effectPreviewElement){
      effectPreviewElement.addEventListener("click", (e) => {
        if(e.target.classList.contains("play-effect")){
          this.playEffectString(e.target.parentElement.nextElementSibling.value)
        }
      })
    }
  },
  playEffectString(str, volumeModifier = 1){
    // real lazy match; just grab the digits and commas, can be within the [], or even the
    // whole string copied from the zzfx web tool
    let paramString = str.match(this.paramsRegex),
        params
    if(paramString){
      params = paramString[0].split(",").map(i => i === "" ? undefined : parseFloat(i))
      this.playEffect(params, volumeModifier)
    }
  },
  playEffect(params, volumeModifier = 1){
    // first param (position 0) is the volume, defaults to 1
    params[0] = params[0] ? params[0] * volumeModifier : volumeModifier
    this.zzfx(...params)
  },
  paramsRegex: /-?\d*\.?\d*(?:,-?\d*\.?\d*){15,19}/, // up to 19 parameters
  zzfx: null
}

export default Sound