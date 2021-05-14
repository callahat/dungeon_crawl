defmodule DungeonCrawl.Dungeon.MapSetTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Dungeon.MapSet

  @valid_attrs %{name: "BobDungeon", version: 1}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = MapSet.changeset(%MapSet{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with valid state values" do
    changeset = MapSet.changeset(%MapSet{}, Elixir.Map.put(@valid_attrs, :state, "health: 100"))
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = MapSet.changeset(%MapSet{}, @invalid_attrs)
    refute changeset.valid?
    changeset = MapSet.changeset(%MapSet{}, %{name: "test", state: "derp"})
    refute changeset.valid?
  end

  test "changeset with invalid state values" do
    changeset = MapSet.changeset(%MapSet{}, Elixir.Map.put(@valid_attrs, :state, "derp"))
    refute changeset.valid?
  end

  test "changeset with title_map_id" do
    map_set = insert_map_set()
    map = insert_stubbed_dungeon(%{map_set_id: map_set.id})
    other_map = insert_stubbed_dungeon()

    changeset = MapSet.changeset(map_set, %{title_map_id: other_map.id})
    refute changeset.valid?
    changeset = MapSet.changeset(map_set, %{title_map_id: map.id + other_map.id}) # to ensure a nonexistant map
    refute changeset.valid?
    changeset = MapSet.changeset(map_set, %{title_map_id: map.id})
    assert changeset.valid?
    changeset = MapSet.changeset(map_set, %{title_map_id: nil})
    assert changeset.valid?
    changeset = MapSet.changeset(Elixir.Map.put(map_set, :title_map_id, map.id), %{title_map_id: nil})
    assert changeset.valid?
  end
end
