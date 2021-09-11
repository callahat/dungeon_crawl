defmodule DungeonCrawlWeb.TileShortlistView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.TileShortlists

  def render("tile_shortlist.json", %{tile_shortlist: tile_shortlist}) do
    details = Map.take(tile_shortlist, [:background_color,
                    :character,
                    :color,
                    :description,
                    :name,
                    :slug,
                    :script,
                    :state,
                    :animate_random,
                    :animate_colors,
                    :animate_background_colors,
                    :animate_characters,
                    :animate_period,
                    :tile_template_id,
                    :id])
    tile_pre = render_to_string(DungeonCrawlWeb.SharedView, "tile_template_pre.html", %{tile_template: details, historic: false, shortlist_id: tile_shortlist.id})

    %{tile_shortlist: details,
      tile_pre: tile_pre,
      attr_hash: TileShortlists.hash(details)}
  end

  def render("tile_shortlist.json", %{errors: tile_shortlist_errors}) do
    errors = Enum.map(tile_shortlist_errors, fn {field, detail} ->
      %{
        field: field,
        detail: _render_detail(detail)
      }
    end)

    %{errors: errors}
  end

  def render("tile_shortlist.json", %{error: error}) do
    %{error: error}
  end

  defp _render_detail({message, values}) do
    Enum.reduce values, message, fn {k, v}, acc ->
      String.replace(acc, "%{#{k}}", to_string(v))
    end
  end
  defp _render_detail(message) do
    message
  end
end
