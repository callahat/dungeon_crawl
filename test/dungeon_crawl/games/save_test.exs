defmodule DungeonCrawl.Dungeons.SaveTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Games.Save

  @valid_attrs %{
    user_id_hash: "asdf",
    row: 1,
    col: 1,
    state: "player: true",
    level_name: "meh",
    host_name: "someguy"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Save.changeset(%Save{}, Map.put(@valid_attrs, :level_instance_id, insert_stubbed_level_instance().id))
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Save.changeset(%Save{}, @invalid_attrs)
    refute changeset.valid?
  end
end
