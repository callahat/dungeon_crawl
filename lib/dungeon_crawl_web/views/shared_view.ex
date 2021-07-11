defmodule DungeonCrawlWeb.SharedView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.DungeonProcesses.{Levels, LevelProcess, Registrar}
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.StateValue
  alias DungeonCrawl.TileTemplates.TileTemplate

  # todo: pass in if its foggy instead maybe
  def level_as_table(level, height, width, admin \\ false)
  def level_as_table(%Levels{state_values: state_values} = level, height, width, admin) do
    if state_values[:visibility] == "fog" && not admin do
      rows(%{}, height, width, &fog_cells/3)
    else
      _level_as_table(level, height, width)
    end
  end

  def level_as_table(level, height, width, _admin) do
    _level_as_table(level, height, width)
  end

  def fade_overlay_table(%{state_values: %{visibility: "fog"}}, _height, _width, _player_coord_id) do
    ""
  end

  def fade_overlay_table(_level, height, width, player_coord_id) do
    fade_overlay_table(height, width, player_coord_id)
  end

  def fade_overlay_table(height, width, player_coord_id) do
    rows(%{}, height, width, player_coord_id, &fade_overlay_cells/4)
  end

  def editor_level_as_table(%Dungeons.Level{} = level, height, width) do
    _edge(width, "north") <>
    _editor_level_table(level.tiles, height, width) <>
    _edge(width, "south")
  end

  defp _edge(width, side) do
    incells = Enum.map(0..width-1, fn col -> "<td id='#{side}_#{col}' class='edge #{side}'></td>" end)
    "<tr><td class='edge'></td>#{ incells }<td class='edge'></td></tr>"
  end

  defp _level_as_table(%Dungeons.Level{} = level, height, width) do
    level.tiles
    |> _level_table(height, width)
  end

  defp _level_as_table(%DungeonInstances.Level{} = level, height, width) do
    {:ok, instance} = Registrar.instance_process(level.dungeon_instance_id, level.id)
    instance_state = LevelProcess.get_state(instance)

    instance_state.map_by_ids
    |> Enum.map(fn({_id, tile}) -> tile end)
    |> _level_table(height, width)
  end

  defp _level_as_table(%Levels{} = instance_state, height, width) do
    instance_state.map_by_ids
    |> Enum.map(fn({_id, tile}) -> tile end)
    |> _level_table(height, width)
  end

  defp _level_table(tiles, height, width) do
    tiles
    |> Enum.sort(fn(a,b) -> a.z_index > b.z_index end)
    |> Enum.reduce(%{}, fn(t,acc) -> if Map.has_key?(acc, {t.row, t.col}), do: acc, else: Map.put(acc, {t.row, t.col}, t) end)
    |> rows(height, width, &cells/3)
  end
# TODO: Probably move the editor stuff into the dungeon_view, since it will only be used for dungeon editing
  defp _editor_level_table(tiles, height, width) do
    tiles
    |> Enum.reduce(%{}, fn(t,acc) -> case Map.get(acc, {t.row, t.col}) do
                                       nil ->   Map.put(acc, {t.row, t.col}, %{t.z_index => t})
                                       tiles -> Map.put(acc, {t.row, t.col}, Map.put(tiles, t.z_index, t))
                                     end
                        end )
    |> rows(height, width, &editor_cells/3)
  end

  defp rows(level, height, width, player_coord_id, cells_func) do
    Enum.to_list(0..height-1)
    |> Enum.map(fn(row) ->
        "<tr>#{cells_func.(level, row, width, player_coord_id)}</tr>"
       end )
    |> Enum.join("\n")
  end

  defp rows(level, height, width, cells_func) do
    Enum.to_list(0..height-1)
    |> Enum.map(fn(row) ->
        "<tr>#{cells_func.(level, row, width)}</tr>"
       end )
    |> Enum.join("\n")
  end

  defp cells(level, row, width) do
    Enum.to_list(0..width-1)
    |> Enum.map(fn(col) -> "<td id='#{row}_#{col}'>#{ tile_and_style(level[{row, col}]) }</td>" end )
    |> Enum.join("")
  end

  defp editor_cells(level, row, width) do
    "<td id='west_#{row}' class='edge west'></td>" <>
    (Enum.to_list(0..width-1)
    |> Enum.map(fn(col) ->
        cells = (level[{row, col}] || %{})
                |> Map.to_list()
                |> Enum.sort(fn({a_z_index, _}, {b_z_index, _}) -> a_z_index > b_z_index end)
                |> Enum.map(fn({_z_index, cell}) -> cell end)

        "<td id='#{row}_#{col}'>" <>
        _editor_cells(cells) <>
        "</td>"
       end )
    |> Enum.join("")) <>
    "<td id='east_#{row}' class='edge east'></td>"
  end

  defp _editor_cells([]), do: "<div class='blank' data-z-index=0 #{data_attributes(nil)}>#{ tile_and_style(nil) }</div>"
  defp _editor_cells([ cell | cells ]) do
    "<div data-z-index=#{cell.z_index} #{data_attributes(cell)}>#{ tile_and_style(cell) }</div>"
    <> _lower_editor_cells(cells)
  end

  defp _lower_editor_cells([]), do: ""
  defp _lower_editor_cells([ cell | cells ]) do
    "<div class='hidden#{animate_class(cell)}' data-z-index=#{cell.z_index} #{data_attributes(cell)}>#{ tile_and_style(cell) }</div>"
    <> _lower_editor_cells(cells)
  end

  defp fade_overlay_cells(_, row, width, player_coord_id) do
    [player_row, player_col] = String.split(player_coord_id, "_") |> Enum.map(&String.to_integer/1)
    Enum.to_list(0..width-1)
    |> Enum.map(fn(col) ->
         range = Enum.max [abs(row - player_row), abs(col - player_col)]
         div_class = if {row, col} == {player_row, player_col}, do: "", else: "fade_overlay fade_range_#{range}"
         "<td><div class='#{div_class}'> </div></td>"
       end)
    |> Enum.join("")
  end

  defp fog_cells(_, row, width) do
    Enum.to_list(0..width-1)
    |> Enum.map(fn(col) -> "<td id='#{row}_#{col}'><div style='background-color: darkgray'>░</div></td>" end )
    |> Enum.join("")
  end

  defp data_attributes(nil) do
    ~s(data-color='' data-background-color='' data-tile-template-id='' data-name='' data-character=' ' data-state='' data-script='' data-name='')
  end
  defp data_attributes(mt) do
    "data-color='#{mt.color}' " <>
    "data-background-color='#{mt.background_color}' " <>
    "data-tile-template-id='#{mt.tile_template_id}' " <>
    "data-character='#{Phoenix.HTML.Safe.to_iodata mt.character}' " <>
    "data-state='#{Phoenix.HTML.Safe.to_iodata mt.state}' " <>
    "data-script='#{Phoenix.HTML.Safe.to_iodata mt.script}' " <>
    "data-name='#{Phoenix.HTML.Safe.to_iodata mt.name}' " <>
    animate_attributes(mt)
  end

  defp animate_attributes(nil), do: ""
  defp animate_attributes(mt) do
    "data-random='#{mt.animate_random}' " <>
    "data-period='#{mt.animate_period}' " <>
    "data-characters='#{mt.animate_characters}' " <>
    "data-colors='#{mt.animate_colors}' " <>
    "data-background-colors='#{mt.animate_background_colors}'"
  end

  defp animate_class(nil), do: nil
  defp animate_class(mt) do
    if to_string(mt.animate_colors) != "" || to_string(mt.animate_characters) != "" || to_string(mt.animate_background_colors) != "" do
      " animate" <> if(mt.animate_random, do: " random", else: "")
    end
  end

  def tile_and_style(nil, :safe), do: {:safe, "<div> </div>"}
  def tile_and_style(tile, :safe), do: {:safe, _tile_and_style(tile)}

  def tile_and_style(nil), do: "<div> </div>"
  def tile_and_style(tile), do: _tile_and_style(tile)

  defp _tile_and_style(%{color: nil, background_color: nil} = tile) do
    "<div#{ _tile_style_animate(tile)}>#{tile.character}</div>"
  end
  defp _tile_and_style(%{color: nil} = tile) do
    "<div#{ _tile_style_animate(tile)} style='background-color: #{tile.background_color}'>#{tile.character}</div>"
  end
  defp _tile_and_style(%{background_color: nil} = tile) do
    "<div#{ _tile_style_animate(tile)} style='color: #{tile.color}'>#{tile.character}</div>"
  end
  defp _tile_and_style(tile) do
    "<div#{ _tile_style_animate(tile)} style='color: #{tile.color};background-color: #{tile.background_color}'>#{tile.character}</div>"
  end

  defp _tile_style_animate(tile) do
    if ac = animate_class(tile) do
     " class='#{ac}' #{animate_attributes(tile)}"
    end
  end

# Use this to generate, then drop the markup into the template
  def character_quick_list_html() do
    #[?!..?~] |> Enum.map(&Enum.to_list/1) # Generates the top line
    ("!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~" <>
     "Öö¢£¤¥§¶×þƜƱǂΦΨπϮϴ∘∙▪∗∝∞█▓▒░▲▶▼◀◆●■☀☘☠☢☣☥☹☺☿♀♁♂♅♠♣♥♦♪♮♯✝✱")
    |> String.split("", trim: true)
    |> Enum.map(fn char ->
              "<pre class='tile_template_preview embiggen' name='character_picker'><div>#{char}</div></pre>"
            end)
    |> Enum.join("\n")
  end

  defp _tile_template_id(%TileTemplate{id: id}), do: id
  defp _tile_template_id(%{tile_template_id: id}), do: id
end

