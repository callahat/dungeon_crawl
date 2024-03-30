defmodule DungeonCrawlWeb.Editor.DungeonView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.StateValue.StandardVariables
  alias DungeonCrawlWeb.SharedView

  def activate_or_new_version_button(conn, dungeon, location) do
    if dungeon.active do
      unless Dungeons.next_version_exists?(dungeon) do
        link "New Version", to: Routes.edit_dungeon_new_version_path(conn, :new_version, dungeon), method: :post, data: [confirm: "Are you sure?"], class: "btn btn-info btn-sm"
      end
    else
      crawl_msg = if location, do: "Your current crawl will be lost, "
      [link("Test Crawl", to: Routes.edit_dungeon_test_crawl_path(conn, :test_crawl, dungeon), method: :post, data: [confirm: "#{crawl_msg}Are you sure?"], class: "btn btn-info btn-sm"), " ",
      link("Activate", to: Routes.edit_dungeon_activate_path(conn, :activate, dungeon), method: :put, data: [confirm: "Are you sure?"], class: "btn btn-success btn-sm")]
    end
  end

  def adjacent_level_names(level) do
    names = Dungeons.adjacent_level_names(level)
    {:safe,
      """
      <table class="table table-sm compact-table">
        <tr><td>North:</td><td>#{ names.north }</td></tr>
        <tr><td>South:</td><td>#{ names.south }</td></tr>
        <tr><td>West:</td><td>#{ names.west }</td></tr>
        <tr><td>East:</td><td>#{ names.east }</td></tr>
      </table>
      """
    }
  end

  def title_level_name(nil), do: "<no levels>"
  def title_level_name(level) do
    "#{level.number} #{level.name}"
  end

  def td_status(%{details: details, status: status}) do
    {:safe,
    """
    <td title="#{ details }">#{ status }#{ if details, do: "*" }</td>
    """
    }
  end

  def diff_label(attr_key, asset_import) do
    label_text =  String.capitalize(Atom.to_string(attr_key))

    if Map.get(asset_import.attributes, attr_key) !=
         Map.get(asset_import.existing_attributes, attr_key) do
      {:safe, "<strong class=\"diff\">#{ label_text }:</strong>"}
    else
      {:safe, "<strong>#{ label_text }:</strong>"}
    end
  end

  def import_field_row(label, existing, import) when existing != import do
    {:safe,
      """
      <div class="row">
        <div class="col-2">
          <strong>#{ label }:</strong>
        </div>
        <div class="col">
          #{ existing }
        </div>
        <div class="col">
          #{ import }
        </div>
      </div>
      """
    }
  end
  def import_field_row(_,_,_), do: ""
end
