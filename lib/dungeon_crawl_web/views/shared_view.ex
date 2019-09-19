defmodule DungeonCrawlWeb.SharedView do
  use DungeonCrawl.Web, :view

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
  def tile_and_style(tile, :safe), do: {:safe, _tile_and_style(tile)}

  def tile_and_style(nil), do: ""
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
end

