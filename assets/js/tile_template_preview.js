let TileTemplatePreview = {
  init(element){ if(!element){ return }

    for(let field of ['tile_template_character',
                      'tile_template_color',
                      'tile_template_background_color',
                      'tile_template_animate_random',
                      'tile_template_animate_period',
                      'tile_template_animate_characters',
                      'tile_template_animate_colors',
                      'tile_template_animate_background_colors']){
      document.getElementById(field).addEventListener('change', e => { this.updatePreview(element) });
    }
    this.updatePreview(element);
  },
  updatePreview(previewArea){
    let character = document.getElementById("tile_template_character").value,
        color = document.getElementById("tile_template_color").value,
        background_color = document.getElementById("tile_template_background_color").value,
        animate_random = document.getElementById("tile_template_animate_random").checked,
        animate_period = document.getElementById("tile_template_animate_period").value,
        animate_characters = document.getElementById("tile_template_animate_characters").value,
        animate_colors = document.getElementById("tile_template_animate_colors").value,
        animate_background_colors = document.getElementById("tile_template_animate_background_colors").value

    if(color == "" && background_color == ""){
      var style = "";
    } else if(color != "" && background_color == ""){
      var style = " style='color:" + color + "'";
    } else if(color == "" && background_color != ""){
      var style = " style='background-color:" + background_color + "'";
    } else {
      var style = " style='color:" + color + ";background-color:" + background_color + "'";
    }

    if(animate_characters != "" || animate_colors != "" || animate_background_colors != ""){
      var animation = " class='animate" + (animate_random ? " random" : "" ) + "'"
      animation += animate_period ? " data-period='" + animate_period + "'" : ""
      animation += animate_characters ? " data-characters='" + animate_characters + "'" : ""
      animation += animate_colors ? " data-colors='" + animate_colors + "'" : ""
      animation += animate_background_colors ? " data-background-colors='" + animate_background_colors + "'" : ""
    } else {
      var animation = ""
    }

    previewArea.innerHTML = "<span" + style + " " + animation + ">" + character + "</span>";
  }
}

export default TileTemplatePreview

