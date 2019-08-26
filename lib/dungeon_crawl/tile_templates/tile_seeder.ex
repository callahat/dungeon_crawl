defmodule DungeonCrawl.TileTemplates.TileSeeder do
  alias DungeonCrawl.Repo
  alias DungeonCrawl.TileTemplates

  @doc """
  Seeds the DB with the basic tiles (floor, wall, rock, open/closed doors, and statue),
  returning a map of the tile's character (as the character code and also as the string)
  as the key, and the existing or created tile template record as the value.
  """
  def basic_tiles() do
    floor = TileTemplates.find_or_create_tile_template!(%{character: ".", name: "Floor", description: "Just a dusty floor", responders: "{move: {:ok}}", state: "blocking: false"})
    wall  = TileTemplates.find_or_create_tile_template!(%{character: "#", name: "Wall",  description: "A Rough wall", state: "blocking: true"})
    rock  = rock_tile()
    statue= TileTemplates.find_or_create_tile_template!(%{character: "@", name: "Statue",  description: "It looks oddly familiar", state: "blocking: true"})

    open_door    = TileTemplates.find_or_create_tile_template!(%{character: "'", name: "Open Door", description: "An open door", state: "blocking: false, open: true"})
    closed_door  = TileTemplates.find_or_create_tile_template!(%{character: "+", name: "Closed Door", description: "A closed door", state: "blocking: true, open: false"})

    open_door   = Repo.update! TileTemplates.change_tile_template(open_door, %{responders: "{move: {:ok}, close: {:ok, replace: [#{closed_door.id}]}}"})
    closed_door = Repo.update! TileTemplates.change_tile_template(closed_door, %{responders: "{open: {:ok, replace: [#{open_door.id}]}}"})

    %{?.  => floor, ?#  => wall, ?\s => rock, ?'  => open_door, ?+  => closed_door, ?@  => statue,
      "." => floor, "#" => wall, " " => rock, "'" => open_door, "+" => closed_door, "@" => statue}
  end

  @doc """
  Seeds the DB with the basic player character tile, returning that record.
  """
  def rock_tile() do
    TileTemplates.find_or_create_tile_template!(%{character: " ", name: "Rock",  description: "Impassible stone", state: "blocking: true"})
  end

  @doc """
  Seeds the DB with the basic player character tile, returning that record.
  """
  def player_character_tile() do
    TileTemplates.find_or_create_tile_template!(%{character: "@", name: "Player",  description: "Its a player.", state: "blocking: true"})
  end
end
