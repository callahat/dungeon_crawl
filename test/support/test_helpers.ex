defmodule DungeonCrawl.TestHelpers do
  alias DungeonCrawl.Repo

  def insert_user(attrs \\ %{}) do
    changes = Map.merge(%{
      name: "Some User",
      username: "user#{Base.encode16(:crypto.rand_bytes(8))}",
      password: "secretsauce",
    }, attrs)

    %DungeonCrawl.User{}
    |> DungeonCrawl.User.registration_changeset(changes)
    |> Repo.insert!()
  end
end
