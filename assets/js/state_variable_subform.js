let StateVariableSubform = {
  init(element){ if(!element){ return }
    this.element = element

    this.field_name_prefix = element.getAttribute("data-field-name-prefix")

    document.getElementById("add_state_field_button").addEventListener('click', e => {
      this.createNewRows();
    })
    element.addEventListener('click', e => {
      this.deleteRow(e.target);
    })
    element.addEventListener('input', e => {
      this.filterCommaAndParen(e.target)
    })
  },
  createNewRows() {
    let twoFields = document.createElement("tr")
    twoFields.innerHTML = `
      <td><input class="form-control" name="${this.field_name_prefix}[state_variables][]" type="text"></td>
      <td><input class="form-control" name="${this.field_name_prefix}[state_values][]" type="text"></td>
      <td><button type="button" class="btn btn-danger delete-state-fields-row">X</button></td>
    `
    this.element.insertBefore(twoFields, document.getElementById("add_state_field_row"))
  },
  deleteRow(target) { if(!target.matches('.delete-state-fields-row')) { return }
    target.parentElement.parentElement.remove()
  },
  filterCommaAndParen(target) { if(!target.matches("[type=\"text\"]")) { return }
    target.value = target.value.replaceAll(/[,:]/g, "")
  },
  element: null,
  field_name_prefix: null
}

export default StateVariableSubform
