let Sound = {
  init(zzfx){
    this.zzfx = zzfx

    let effectInput = document.getElementById('effect_zzfx_params')

    if(effectInput) {
      document.getElementById('play_effect').addEventListener('click', () => {
        this.playEffectString(effectInput.value) })
    }
  },
  playEffectString(str, volumeModifier = 1){
    // real lazy match; just grab the digits and commas, can be within the [], or even the
    // whole string copied from the zzfx web tool
    let paramString = str.match(this.paramsRegex),
        params
    if(paramString){
      params = paramString[0].split(",").map(i => i === "" ? undefined : parseFloat(i))
      this.playEffect(params)
    }
  },
  playEffect(params, volumeModifier = 1){
    // first param (position 0) is the volume, defaults to 1
    params[0] = params[0] ? params[0] * volumeModifier : volumeModifier
    this.zzfx(...params)
  },
  paramsRegex: /[,\d][,\d\.]+/,
  zzfx: null
}

export default Sound