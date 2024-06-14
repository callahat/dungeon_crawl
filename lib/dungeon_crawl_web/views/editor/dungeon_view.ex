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

  def import_character_row(existing, import) do
    existing = ~s|<pre class="tile_template_preview">#{ existing }</pre>|
    import = ~s|<pre class="tile_template_preview">#{ import }</pre>|
    import_field_row("Character", existing, import)
  end

  def import_sound_effect_row(existing, import) do
    existing =
      """
      <div class="input-group">
        <div class="input-group-prepend user-select-none">
          <span class="input-group-text play-effect smaller" title="Click to preview the sound effect">▶</span>
        </div>
        <input type="text" class="form-control smaller" disabled=true value="#{ existing }"></input>
      </div>
      """
    import =
      """
      <div class="input-group">
        <div class="input-group-prepend user-select-none">
          <span class="input-group-text play-effect smaller" title="Click to preview the sound effect">▶</span>
        </div>
        <input type="text" class="form-control smaller" disabled=true value="#{ import }"></input>
      </div>
      """
    import_field_row("Zzfx Params", existing, import)
  end

  def import_field_row(label, existing, import) when existing != import do
    {:safe,
      """
      <div class="row">
        <div class="col-2">
          <strong>#{ label }:</strong>
        </div>
        <div class="col">
          <div style="width: 100%">#{ existing }</div>
        </div>
        <div class="col">
          <div style="width: 100%">#{ import }</div>
        </div>
      </div>
      """
    }
  end
  def import_field_row(_,_,_), do: ""

  def waiting_or_dungeon_link(socket, import) do
    cond do
      import.dungeon_id ->
        link(import.dungeon.name, to: Routes.edit_dungeon_path(socket, :show, import.dungeon_id))

      import.status == :waiting ->
        link("Update", to: Routes.edit_dungeon_import_path(socket, :dungeon_import_show, import.id), class: "btn btn-info btn-sm")

      true-> ""
    end
  end
end
