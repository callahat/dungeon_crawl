defmodule DungeonCrawl.Shipping.ExportTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Shipping.Export
  alias DungeonCrawl.Repo

  test "changeset/2" do
    user = insert_user()
    dungeon = insert_dungeon()

    changeset = Export.changeset(%Export{}, %{user_id: user.id, dungeon_id: dungeon.id})

    assert changeset.valid?
    assert {:ok, record} = Repo.insert(changeset)

    changeset = Export.changeset(%Export{}, %{user_id: user.id, dungeon_id: dungeon.id})

    refute changeset.valid?
    assert changeset.errors == [{:dungeon_id, {"Already exporting", []}}]

    changeset = Export.changeset(record, %{status: :running})
    assert changeset.valid?
  end
end
