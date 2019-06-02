defmodule DungeonCrawl.TileTemplates.TileSeeder do
  import Ecto.Query

  alias DungeonCrawl.Repo
  alias DungeonCrawl.TileTemplates.TileTemplate

  @doc """
  Seeds the DB with the basic tiles (floor, wall, rock, open/closed doors, and statue),
  returning a map of the tile's character as the key, and the existing or created tile template record
  as the value.
  """
  def basic_tiles() do
    floor = case Repo.one(from t in TileTemplate, where: t.character == ".", limit: 1, order_by: :inserted_at) do
              nil -> Repo.insert! %TileTemplate{character: ".", name: "Floor", description: "Just a dusty floor", color: "", background_color: "", responders: "{move: {:ok}}"}
              t   -> t
            end
    wall  = case Repo.one(from t in TileTemplate, where: t.character == "#", limit: 1, order_by: :inserted_at) do
              nil -> Repo.insert! %TileTemplate{character: "#", name: "Wall",  description: "A Rough wall"}
              t   -> t
            end
    rock  = case Repo.one(from t in TileTemplate, where: t.character == " ", limit: 1, order_by: :inserted_at) do
              nil -> Repo.insert! %TileTemplate{character: " ", name: "Rock",  description: "Impassible stone"}
              t   -> t
            end
    statue= case Repo.one(from t in TileTemplate, where: t.character == "@", limit: 1, order_by: :inserted_at) do
              nil -> Repo.insert! %TileTemplate{character: "@", name: "Statue",  description: "It looks oddly familiar"}
              t   -> t
            end

    open_door    = case Repo.one(from t in TileTemplate, where: t.character == "'", limit: 1, order_by: :inserted_at) do
                     nil -> Repo.insert! %TileTemplate{character: "'", name: "Open Door", description: "An open door"}
                     t   -> t
                   end
    closed_door  = case Repo.one(from t in TileTemplate, where: t.character == "+", limit: 1, order_by: :inserted_at) do
                     nil -> Repo.insert! %TileTemplate{character: "+", name: "Closed Door", description: "A closed door"}
                     t   -> t
                   end

    open_door   = Repo.update! TileTemplate.changeset(open_door, %{responders: "{move: {:ok}, close: {:ok, replace: [#{closed_door.id}]}}"})
    closed_door = Repo.update! TileTemplate.changeset(closed_door, %{responders: "{open: {:ok, replace: [#{open_door.id}]}}"})

    %{"." => floor, "#" => wall, " " => rock, "'" => open_door, "+" => closed_door, "@" => statue}
  end
end
