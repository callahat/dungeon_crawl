defmodule DungeonCrawlWeb.SharedView do
  use DungeonCrawl.Web, :view

  def dungeon_as_table(player_location) do
    player_location.dungeon.dungeon_map_tiles
    |> Enum.reduce(%{}, fn(dmt,acc) -> Map.put(acc, {dmt.row, dmt.col}, dmt.tile_template.character) end)
    |> put_player_location(player_location)
    |> rows(player_location.dungeon.height, player_location.dungeon.width)
  end

  defp put_player_location(map, player_location) do
    Map.put(map, {player_location.row, player_location.col}, :@)
  end

  defp rows(map, height, width) do
    Enum.to_list(0..height-1)
    |> Enum.map(fn(row) -> "<tr>#{cells(map, row, width)}</tr>" end ) |> Enum.join("\n")
  end

  defp cells(map, row, width) do
    Enum.to_list(0..width-1)
    |> Enum.map(fn(col) -> "<td id='#{row}_#{col}'>#{map[{row, col}]}</td>" end ) |> Enum.join("")
  end

  def tile_and_style(tile_template) do
    {:safe, _tile_and_style(tile_template)}
  end
  def _tile_and_style(%{color: nil, background_color: nil} = tile_template) do
    "<span>#{tile_template.character}</span>"
  end
  def _tile_and_style(%{color: nil} = tile_template) do
    "<span style='background-color: #{tile_template.background_color}'>#{tile_template.character}</span>"
  end
  def _tile_and_style(%{background_color: nil} = tile_template) do
    "<span style='color: #{tile_template.color}'>#{tile_template.character}</span>"
  end
  def _tile_and_style(tile_template) do
    "<span style='color: #{tile_template.color};background-color: #{tile_template.background_color}'>#{tile_template.character}</span>"
  end
end


