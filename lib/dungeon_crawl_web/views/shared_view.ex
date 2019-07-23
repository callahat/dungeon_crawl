defmodule DungeonCrawlWeb.SharedView do
  use DungeonCrawl.Web, :view

  def dungeon_as_table(dungeon, with_template_id \\ false) do
    dungeon.dungeon_map_tiles
    |> Enum.sort(fn(a,b) -> a.z_index > b.z_index end)
    |> DungeonCrawl.Repo.preload(:tile_template)
    |> Enum.reduce(%{}, fn(dmt,acc) -> if Map.has_key?(acc, {dmt.row, dmt.col}), do: acc, else: Map.put(acc, {dmt.row, dmt.col}, dmt.tile_template) end)
    |> rows(dungeon.height, dungeon.width, with_template_id)
  end

  defp rows(map, height, width, with_template_id) do
    Enum.to_list(0..height-1)
    |> Enum.map(fn(row) -> "<tr>#{cells(map, row, width, with_template_id)}</tr>" end ) |> Enum.join("\n")
  end

  defp cells(map, row, width, true) do
    Enum.to_list(0..width-1)
    |> Enum.map(fn(col) -> "<td id='#{row}_#{col}' data-tile-template-id='#{map[{row, col}].id}'>#{ DungeonCrawlWeb.SharedView.tile_and_style(map[{row, col}]) }</td>" end ) |> Enum.join("")
  end

  defp cells(map, row, width, false) do
    Enum.to_list(0..width-1)
    |> Enum.map(fn(col) -> "<td id='#{row}_#{col}'>#{ DungeonCrawlWeb.SharedView.tile_and_style(map[{row, col}]) }</td>" end ) |> Enum.join("")
  end

  def tile_and_style(nil, :safe), do: {:safe, ""}
  def tile_and_style(tile_template, :safe) do
    {:safe, _tile_and_style(tile_template)}
  end
  def tile_and_style(nil), do: ""
  def tile_and_style(tile_template) do
    _tile_and_style(tile_template)
  end
  defp _tile_and_style(%{color: nil, background_color: nil} = tile_template) do
    "<span>#{tile_template.character}</span>"
  end
  defp _tile_and_style(%{color: nil} = tile_template) do
    "<span style='background-color: #{tile_template.background_color}'>#{tile_template.character}</span>"
  end
  defp _tile_and_style(%{background_color: nil} = tile_template) do
    "<span style='color: #{tile_template.color}'>#{tile_template.character}</span>"
  end
  defp _tile_and_style(tile_template) do
    "<span style='color: #{tile_template.color};background-color: #{tile_template.background_color}'>#{tile_template.character}</span>"
  end
end


