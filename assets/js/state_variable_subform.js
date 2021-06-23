let StateVariableSubform = {
  init(element){ if(!element){ return }
    let fieldNamePrefix = element.getAttribute("data-field-name-prefix"),
        standardVariableDropdownList = document.getElementById(fieldNamePrefix + "_standard_variable_dropdown_list")

    document.getElementById(fieldNamePrefix + "_add_state_field_button").addEventListener('click', e => {
      this.createNewRow(element);
    })
    document.getElementById(fieldNamePrefix + "_standard_variable_dropdown_button").addEventListener('click', e => {
      // update to enable/disable the items based on the existing state values in the field
      this.updateStandardVariables(element, standardVariableDropdownList)
    })
    standardVariableDropdownList.addEventListener('click', e => {
      this.addStandardVariable(element, e.target)
    })
    element.addEventListener('click', e => {
      this.deleteRow(e.target);
    })
    element.addEventListener('input', e => {
      this.filterCommaAndParen(e.target)
    })
  },
  generateInitialRows(element, state_string) { if(!element){ return }
    let fieldNamePrefix = element.getAttribute("data-field-name-prefix")

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
        fieldNamePrefix = element.getAttribute("data-field-name-prefix")

    twoFields.classList.add(fieldNamePrefix + "_state_data_row")
    twoFields.innerHTML = `
      <td><input class="form-control" name="${fieldNamePrefix}[state_variables][]" type="text" value="${variable}"></td>
      <td><input class="form-control" name="${fieldNamePrefix}[state_values][]" type="text" value="${value}"></td>
      <td><button type="button" class="btn btn-danger delete-state-fields-row">X</button></td>
    `
    element.insertBefore(twoFields, document.getElementById(fieldNamePrefix + "_add_state_field_row"))
  },
  updateStandardVariables(element, standardVariableDropdownListElement){
    let fieldNamePrefix = element.getAttribute("data-field-name-prefix"),
        existingRows = element.getElementsByClassName(fieldNamePrefix + "_state_data_row"),
        existingVariables = Array.from(existingRows).map(e => {return e.getElementsByClassName("form-control")[0].value})

    for(let standardVariable of standardVariableDropdownListElement.getElementsByClassName("dropdown-item")){
      if(existingVariables.includes(standardVariable.innerText)){
        standardVariable.classList.add("disabled")
      } else {
        standardVariable.classList.remove("disabled")
      }
    }
  },
  addStandardVariable(element, standardListTarget){ if(standardListTarget.tagName != "A") { return }
    let fieldNamePrefix = element.getAttribute("data-field-name-prefix"),
        existingRows = element.getElementsByClassName(fieldNamePrefix + "_state_data_row"),
        lastRow = existingRows[existingRows.length - 1]
    if(lastRow.getElementsByClassName("form-control")[0].value == ""){
      lastRow.remove()
    }
    this.createNewRow(element, standardListTarget.innerText)
    this.createNewRow(element)
  },
  deleteRow(target) { if(!target.matches('.delete-state-fields-row')) { return }
    target.parentElement.parentElement.remove()
  },
  filterCommaAndParen(target) { if(!target.matches("[type=\"text\"]")) { return }
    target.value = target.value.replaceAll(/[,:]/g, "")
  }
}

export default StateVariableSubform
