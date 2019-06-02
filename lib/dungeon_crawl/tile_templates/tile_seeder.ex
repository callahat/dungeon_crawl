defmodule DungeonCrawl.TileTemplates.TileSeeder do
  import Ecto.Query

  alias DungeonCrawl.Repo
  alias DungeonCrawl.TileTemplates

  @doc """
  Seeds the DB with the basic tiles (floor, wall, rock, open/closed doors, and statue),
  returning a map of the tile's character as the key, and the existing or created tile template record
  as the value.
  """
  def basic_tiles() do
    floor = TileTemplates.find_or_create_tile_template!(%{character: ".", name: "Floor", description: "Just a dusty floor", color: "", background_color: "", responders: "{move: {:ok}}"})
    wall  = TileTemplates.find_or_create_tile_template!(%{character: "#", name: "Wall",  description: "A Rough wall"})
    rock  = TileTemplates.find_or_create_tile_template!(%{character: " ", name: "Rock",  description: "Impassible stone"})
    statue= TileTemplates.find_or_create_tile_template!(%{character: "@", name: "Statue",  description: "It looks oddly familiar"})

    open_door    = TileTemplates.find_or_create_tile_template!(%{character: "'", name: "Open Door", description: "An open door"})
    closed_door  = TileTemplates.find_or_create_tile_template!(%{character: "+", name: "Closed Door", description: "A closed door"})

    open_door   = Repo.update! TileTemplates.change_tile_template(open_door, %{responders: "{move: {:ok}, close: {:ok, replace: [#{closed_door.id}]}}"})
    closed_door = Repo.update! TileTemplates.change_tile_template(closed_door, %{responders: "{open: {:ok, replace: [#{open_door.id}]}}"})

    %{"." => floor, "#" => wall, " " => rock, "'" => open_door, "+" => closed_door, "@" => statue}
  end
end
