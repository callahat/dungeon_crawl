let AvatarPreview = {
  init(element){ if(!element){ return }

    for(let field of ['user_color',
                      'user_background_color']){
      document.getElementById(field).addEventListener('change', e => { this.updatePreview(element) });
    }
    this.updatePreview(element);
  },
  updatePreview(previewArea){
    let character = "@",
        color = document.getElementById("user_color").value,
        background_color = document.getElementById("user_background_color").value

    if(color == "" && background_color == ""){
      var style = "";
    } else if(color != "" && background_color == ""){
      var style = " style='color:" + color + "'";
    } else if(color == "" && background_color != ""){
      var style = " style='background-color:" + background_color + "'";
    } else {
      var style = " style='color:" + color + ";background-color:" + background_color + "'";
    }

    previewArea.innerHTML = "<span" + style + ">" + character + "</span>";
  }
}

export default AvatarPreview

