defmodule DungeonCrawl.Dungeons.DungeonTest do
  use DungeonCrawl.DataCase

  require DungeonCrawl.SharedTests

  alias DungeonCrawl.Dungeons.Dungeon

  @valid_attrs %{name: "BobDungeon", version: 1}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Dungeon.changeset(%Dungeon{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with valid state values" do
    changeset = Dungeon.changeset(%Dungeon{}, Elixir.Map.put(@valid_attrs, :state, "health: 100"))
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Dungeon.changeset(%Dungeon{}, @invalid_attrs)
    refute changeset.valid?
    changeset = Dungeon.changeset(%Dungeon{}, %{name: "test", state: "derp"})
    refute changeset.valid?
  end

  test "changeset with invalid state values" do
    changeset = Dungeon.changeset(%Dungeon{}, Elixir.Map.put(@valid_attrs, :state, "derp"))
    refute changeset.valid?
  end

  test "changeset with invalid items in equipment" do
    user = insert_user(%{name: "me", user_id_hash: "234"})
    other_user = insert_user(%{name: "other", user_id_hash: "123"})
    good_item = insert_item(%{user_id: user.id, name: "ok item"})
    bad_item = insert_item(%{user_id: other_user.id, name: "bad item"})

    starting_equipment = %{"starting_equipment" => ["not_real", good_item.slug,  bad_item.slug]}

    changeset = Dungeon.changeset(%Dungeon{}, Elixir.Map.merge(@valid_attrs, %{user_id: user.id, state: starting_equipment}))

    refute changeset.valid?
    assert changeset.errors == [state: {"starting_equipment contains invalid items: `[\"not_real\", \"#{bad_item.slug}\"]`", []}]
  end

  DungeonCrawl.SharedTests.handles_state_variables_and_values_correctly(Dungeon)
end
