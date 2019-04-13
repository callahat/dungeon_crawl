defmodule DungeonCrawl.TestHelpers do
  alias DungeonCrawl.Repo

  def insert_user(attrs \\ %{}) do
    changes = Map.merge(%{
      name: "Some User",
      username: "user#{Base.encode16(:crypto.rand_bytes(8))}",
      password: "secretsauce",
    }, attrs)

    %DungeonCrawl.User{}
    |> DungeonCrawl.User.admin_changeset(changes)
    |> Repo.insert!()
  end

  def insert_dungeon(attrs \\ %{}) do
    changes = Map.merge(%{
      name: "Test",
      height: 20,
      width: 20
    }, attrs)

    dungeon = %DungeonCrawl.Dungeon{}
              |> DungeonCrawl.Dungeon.changeset(changes)
              |> Repo.insert!()

    DungeonCrawl.Dungeon.generate_dungeon_map_tiles(dungeon, DungeonCrawl.DungeonGenerator.TestRooms)
    dungeon
  end
end
