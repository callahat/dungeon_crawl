defmodule DungeonCrawl.Shipping.ImportTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Shipping.Import
  alias DungeonCrawl.Repo

  test "changeset/2" do
    user = insert_user()

    changeset = Import.changeset(%Import{}, %{user_id: user.id, data: "{}", file_name: "test.json"})

    assert changeset.valid?
    assert {:ok, record} = Repo.insert(changeset)

    changeset = Import.changeset(%Import{}, %{user_id: user.id, data: "{}", file_name: "test.json"})

    refute changeset.valid?
    assert changeset.errors == [{:file_name, {"Already importing", []}}]

    changeset = Import.changeset(record, %{status: :running})
    assert changeset.valid?
  end

  test "changeset/2 with a line_identifier" do
    user = insert_user()
    dungeon = insert_dungeon(%{user_id: user.id})

    changeset = Import.changeset(%Import{},
      %{user_id: user.id, data: "{}", file_name: "test.json", line_identifier: dungeon.line_identifier})
    assert changeset.valid?

    changeset = Import.changeset(%Import{},
      %{user_id: user.id, data: "{}", file_name: "test.json", line_identifier: -1})
    refute changeset.valid?
    assert changeset.errors == [{:line_identifier, {"Invalid Line Identifier", []}}]
  end
end
