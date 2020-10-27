let CharacterPicker = {
  init(showCharacterPickerEl) { if(!showCharacterPickerEl){ return }
    showCharacterPickerEl.addEventListener("click", function(event){
      $('#characterPickModal').modal({show: true})
    })

    for(let character of document.getElementsByName("character_picker")){
      character.addEventListener('click', e => {
        if(!e.target) { return }
        console.log(e.target.textContent)
        document.getElementById("tile_template_character").value = e.target.textContent
        document.getElementById("tile_template_character").dispatchEvent(new Event("change"))
        $("#characterPickModal").modal('hide')
      });
    }
  }
}

export default CharacterPicker
