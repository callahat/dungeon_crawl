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
end