defmodule DungeonCrawlWeb.SharedView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.DungeonProcesses.{InstanceRegistry, InstanceProcess}
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.DungeonInstances

  def dungeon_as_table(dungeon, height, width) do
    _dungeon_as_table(dungeon, height, width)
  end

  def editor_dungeon_as_table(%Dungeon.Map{} = dungeon, height, width) do
    dungeon.dungeon_map_tiles
    |> _editor_dungeon_table(height, width)
  end

  defp _dungeon_as_table(%Dungeon.Map{} = dungeon, height, width) do
    dungeon.dungeon_map_tiles
    |> _dungeon_table(height, width)
  end

  defp _dungeon_as_table(%DungeonInstances.Map{} = dungeon, height, width) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, dungeon.id)
    instance_state = InstanceProcess.get_state(instance)

    instance_state.map_by_ids
    |> Enum.map(fn({_id, map_tile}) -> map_tile end)
    |> _dungeon_table(height, width)
  end

  defp _dungeon_table(dungeon_map_tiles, height, width) do
    dungeon_map_tiles
    |> Enum.sort(fn(a,b) -> a.z_index > b.z_index end)
    |> DungeonCrawl.Repo.preload(:tile_template)
    |> Enum.reduce(%{}, fn(dmt,acc) -> if Map.has_key?(acc, {dmt.row, dmt.col}), do: acc, else: Map.put(acc, {dmt.row, dmt.col}, dmt) end)
    |> rows(height, width)
  end
# TODO: Probably move the editor stuff into the dungeon_view, since it will only be used for dungeon editing
  defp _editor_dungeon_table(dungeon_map_tiles, height, width) do
    dungeon_map_tiles
    |> DungeonCrawl.Repo.preload(:tile_template)
    |> Enum.reduce(%{}, fn(dmt,acc) -> case Map.get(acc, {dmt.row, dmt.col}) do
                                         nil ->   Map.put(acc, {dmt.row, dmt.col}, %{dmt.z_index => dmt})
                                         tiles -> Map.put(acc, {dmt.row, dmt.col}, Map.put(tiles, dmt.z_index, dmt))
                                       end
       end )
    |> editor_rows(height, width)
  end

  defp rows(map, height, width) do
    Enum.to_list(0..height-1)
    |> Enum.map(fn(row) -> "<tr>#{cells(map, row, width)}</tr>" end ) |> Enum.join("\n")
  end

  defp editor_rows(map, height, width) do
    Enum.to_list(0..height-1)
    |> Enum.map(fn(row) -> "<tr>#{editor_cells(map, row, width)}</tr>" end ) |> Enum.join("\n")
  end

#  defp cells(map, row, width, true) do
#    Enum.to_list(0..width-1)
#    |> Enum.map(fn(col) -> "<td id='#{row}_#{col}' #{data_attributes(map[{row, col}])}>#{ tile_and_style(map[{row, col}]) }</td>" end )
#    |> Enum.join("")
#  end

  defp cells(map, row, width) do
    Enum.to_list(0..width-1)
    |> Enum.map(fn(col) -> "<td id='#{row}_#{col}'>#{ tile_and_style(map[{row, col}]) }</td>" end )
    |> Enum.join("")
  end

  defp editor_cells(map, row, width) do
    Enum.to_list(0..width-1)
    |> Enum.map(fn(col) ->
        cells = (map[{row, col}] || %{})
                |> Map.to_list()
                |> Enum.sort(fn({a_z_index, _}, {b_z_index, _}) -> a_z_index > b_z_index end)
                |> Enum.map(fn({_z_index, cell}) -> cell end)

        "<td id='#{row}_#{col}'>" <>
        _editor_cells(cells) <>
        "</td>"
       end )
    |> Enum.join("")
  end

  defp _editor_cells([]), do: "<div class='blank' data-z-index=0 #{data_attributes(nil)}>#{ tile_and_style(nil) }</div>"
  defp _editor_cells([ cell | cells ]) do
    "<div data-z-index=#{cell.z_index} #{data_attributes(cell)}>#{ tile_and_style(cell) }</div>"
    <> _lower_editor_cells(cells)
  end

  defp _lower_editor_cells([]), do: ""
  defp _lower_editor_cells([ cell | cells ]) do
    "<div class='hidden' data-z-index=#{cell.z_index} #{data_attributes(cell)}>#{ tile_and_style(cell) }</div>"
    <> _lower_editor_cells(cells)
  end

  defp data_attributes(nil) do
    ~s(data-color='' data-background-color='' data-tile-template-id='' data-name='' data-character=' ' data-state='' data-script='' data-name='')
  end
  defp data_attributes(mt) do
    # TODO: add name when its supported
    "data-color='#{mt.color}' " <>
    "data-background-color='#{mt.background_color}' " <>
    "data-tile-template-id='#{mt.tile_template_id}' " <>
    "data-character='#{Phoenix.HTML.Safe.to_iodata mt.character}' " <>
    "data-state='#{Phoenix.HTML.Safe.to_iodata mt.state}' " <>
    "data-script='#{Phoenix.HTML.Safe.to_iodata mt.script}' " <>
    "data-name='#{Phoenix.HTML.Safe.to_iodata mt.name}'"
  end

  def tile_and_style(nil, :safe), do: {:safe, "<div> </div>"}
  def tile_and_style(tile, :safe), do: {:safe, _tile_and_style(tile)}

  def tile_and_style(nil), do: "<div> </div>"
  def tile_and_style(tile), do: _tile_and_style(tile)

  defp _tile_and_style(%{color: nil, background_color: nil} = map_tile) do
    "<div>#{map_tile.character}</div>"
  end
  defp _tile_and_style(%{color: nil} = map_tile) do
    "<div style='background-color: #{map_tile.background_color}'>#{map_tile.character}</div>"
  end
  defp _tile_and_style(%{background_color: nil} = map_tile) do
    "<div style='color: #{map_tile.color}'>#{map_tile.character}</div>"
  end
  defp _tile_and_style(map_tile) do
    "<div style='color: #{map_tile.color};background-color: #{map_tile.background_color}'>#{map_tile.character}</div>"
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
end

