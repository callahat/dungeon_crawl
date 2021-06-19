let StateVariableSubform = {
  init(element){ if(!element){ return }
    let field_name_prefix = element.getAttribute("data-field-name-prefix")

    document.getElementById(field_name_prefix + "_add_state_field_button").addEventListener('click', e => {
      this.createNewRow(element);
    })
    element.addEventListener('click', e => {
      this.deleteRow(e.target);
    })
    element.addEventListener('input', e => {
      this.filterCommaAndParen(e.target)
    })
  },
  generateInitialRows(element, state_string) { if(!element){ return }
    let field_name_prefix = element.getAttribute("data-field-name-prefix")

    $(".tile_template_state_data_row").remove()

    if(state_string != undefined && state_string != "") {
      let pair_map = state_string.split(",").map( key_value => {
                       return key_value.split(":").map(half => { return half.trim() })
                     })
      pair_map.forEach( ([variable, value]) => {
        this.createNewRow(element, variable, value)
      })
    }
    this.createNewRow(element)
  },
  createNewRow(element, variable = "", value = "") {
    let twoFields = document.createElement("tr"),
        field_name_prefix = element.getAttribute("data-field-name-prefix")

    twoFields.classList.add(field_name_prefix + "_state_data_row")
    twoFields.innerHTML = `
      <td><input class="form-control" name="${field_name_prefix}[state_variables][]" type="text" value="${variable}"></td>
      <td><input class="form-control" name="${field_name_prefix}[state_values][]" type="text" value="${value}"></td>
      <td><button type="button" class="btn btn-danger delete-state-fields-row">X</button></td>
    `
    element.insertBefore(twoFields, document.getElementById(field_name_prefix + "_add_state_field_row"))
  },
  deleteRow(target) { if(!target.matches('.delete-state-fields-row')) { return }
    target.parentElement.parentElement.remove()
  },
  filterCommaAndParen(target) { if(!target.matches("[type=\"text\"]")) { return }
    target.value = target.value.replaceAll(/[,:]/g, "")
  }
}

export default StateVariableSubform
