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
    let soundEffect = [...params]
    // first param (position 0) is the volume, defaults to 1
    soundEffect[0] = soundEffect[0] ? (soundEffect[0] * volumeModifier) : volumeModifier
    this.zzfx(...soundEffect)
  },
  paramsRegex: /-?\d*\.?\d*(?:,-?\d*\.?\d*){13,19}/, // up to 20 parameters
  zzfx: null
}

export default Sound