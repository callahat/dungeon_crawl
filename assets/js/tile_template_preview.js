let TileTemplatePreview = {
  init(element){ if(!element){ return }

    for(let field of ['tile_template_character', 'tile_template_color', 'tile_template_background_color']){
      document.getElementById(field).addEventListener('change', e => { this.updatePreview(element) });
    }
    this.updatePreview(element);
  },
  updatePreview(previewArea){
    let character = document.getElementById("tile_template_character").value;
    let color = document.getElementById("tile_template_color").value;
    let background_color = document.getElementById("tile_template_background_color").value;

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

export default TileTemplatePreview

