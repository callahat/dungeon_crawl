defmodule DungeonCrawlWeb.SharedView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.{Dungeon,DungeonInstances}
  alias DungeonCrawl.TileTemplates.TileTemplate

  def dungeon_as_table(dungeon, with_template_id \\ false) do
    dungeon.dungeon_map_tiles
    |> Enum.sort(fn(a,b) -> a.z_index > b.z_index end)
    |> DungeonCrawl.Repo.preload(:tile_template)
    |> Enum.reduce(%{}, fn(dmt,acc) -> if Map.has_key?(acc, {dmt.row, dmt.col}), do: acc, else: Map.put(acc, {dmt.row, dmt.col}, dmt) end)
    |> rows(dungeon.height, dungeon.width, with_template_id)
  end

  defp rows(map, height, width, with_template_id) do
    Enum.to_list(0..height-1)
    |> Enum.map(fn(row) -> "<tr>#{cells(map, row, width, with_template_id)}</tr>" end ) |> Enum.join("\n")
  end

  defp cells(map, row, width, true) do
    Enum.to_list(0..width-1)
    |> Enum.map(fn(col) -> "<td id='#{row}_#{col}' #{data_attributes(map[{row, col}])}>#{ tile_and_style(map[{row, col}]) }</td>" end )
    |> Enum.join("")
  end

  defp cells(map, row, width, false) do
    Enum.to_list(0..width-1)
    |> Enum.map(fn(col) -> "<td id='#{row}_#{col}'>#{ tile_and_style(map[{row, col}]) }</td>" end )
    |> Enum.join("")
  end

  defp data_attributes(nil) do
    ~s(data-color='' data-background-color='' data-tile-template-id='')
  end
  defp data_attributes(mt) do
    ~s(data-color='#{mt.color}' data-background-color='#{mt.background_color}' data-tile-template-id='#{mt.tile_template_id}')
  end

  def tile_and_style(nil, :safe), do: {:safe, ""}
  def tile_and_style(%Dungeon.MapTile{} = map_tile, :safe), do: {:safe, _tile_and_style(map_tile)}
  def tile_and_style(%DungeonInstances.MapTile{} = map_tile, :safe), do: {:safe, _tile_and_style(map_tile)}

  def tile_and_style(nil), do: ""
  def tile_and_style(%Dungeon.MapTile{} = map_tile), do: _tile_and_style(map_tile)
  def tile_and_style(%DungeonInstances.MapTile{} = map_tile), do: _tile_and_style(map_tile)

  # splitting these into a new method to make the standard display use a MapTile, but allow using the tile template
  # in cases where that is valid (ie, when editing/showing tile templates explicitly)
  def tile_template_and_style(nil, :safe), do: {:safe, ""}
  def tile_template_and_style(%TileTemplate{} = tile_template, :safe), do: {:safe, _tile_and_style(tile_template)}

  def tile_template_and_style(nil), do: ""
  def tile_template_and_style(%TileTemplate{} = tile_template), do: _tile_and_style(tile_template)

  defp _tile_and_style(%{color: nil, background_color: nil} = map_tile) do
    "<span>#{map_tile.character}</span>"
  end
  defp _tile_and_style(%{color: nil} = map_tile) do
    "<span style='background-color: #{map_tile.background_color}'>#{map_tile.character}</span>"
  end
  defp _tile_and_style(%{background_color: nil} = map_tile) do
    "<span style='color: #{map_tile.color}'>#{map_tile.character}</span>"
  end
  defp _tile_and_style(map_tile) do
    "<span style='color: #{map_tile.color};background-color: #{map_tile.background_color}'>#{map_tile.character}</span>"
  end
end

