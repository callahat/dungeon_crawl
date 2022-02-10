defmodule DungeonCrawlWeb.ManageDungeonView do
  use DungeonCrawl.Web, :view

  def level_header_links(conn, dungeon_instance, level, dungeon) do
    for level_header <- Enum.sort(dungeon_instance.level_headers, fn(a,b) -> a.number < b.number end) do
      _level_header_link(conn, level_header, level, dungeon, dungeon_instance.id)
    end
    |> Enum.join("\n")
  end

  defp _level_header_link(_conn, %{levels: []} = level_header, level, _dungeon, _di_id) do
    """
      <span class="nav-link small #{ if level == level_header.number, do: "active", else: "" }"
         id="level#{ level_header.number }-tab"
         aria-controls="level#{ level_header.number }"
         aria-orientation="vertical"
         aria-selected="true"
         title="No level instances exist currently">
        #{ _level_text(level_header.level) }
      </span>
    """
  end

  defp _level_header_link(conn, level_header, level, dungeon, di_id) do
    """
      <a class="nav-link small #{ if level == level_header.number, do: "active", else: "" }"
         id="level#{ level_header.number }-tab"
         href="#{ Routes.manage_dungeon_path(conn, :show, dungeon, instance_id: di_id, level: level_header.number) }"
         aria-controls="level#{ level_header.number }"
         aria-orientation="vertical"
         aria-selected="true">
        #{ _level_text(level_header.level) }
      </a>
    """
  end

  defp _level_text(level) do
    prefix = if level.entrance, do: "*", else: "&nbsp;"
    "#{prefix} (#{ level.height }x#{ level.width }) #{ level.number } - #{ level.name }"
  end
end
