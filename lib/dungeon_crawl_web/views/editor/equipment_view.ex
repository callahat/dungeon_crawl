defmodule DungeonCrawlWeb.Editor.EquipmentView do
  use DungeonCrawl.Web, :view

  def error_pre_tag(form, field) do
    if error = form.errors[field] do
      content_tag :pre, translate_error(error), class: "help-block"
    end
  end
end
