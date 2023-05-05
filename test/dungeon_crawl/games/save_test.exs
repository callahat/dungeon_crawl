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
    level_instance = insert_stubbed_level_instance()
    location = insert_player_location(%{level_instance_id: level_instance.id})
    other_attrs = %{level_instance_id: level_instance.id, player_location_id: location.id}
    changeset = Save.changeset(%Save{}, Map.merge(@valid_attrs, other_attrs))
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Save.changeset(%Save{}, @invalid_attrs)
    refute changeset.valid?
  end
end
