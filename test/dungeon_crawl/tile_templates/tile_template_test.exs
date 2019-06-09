defmodule DungeonCrawl.TileTemplates.TileTemplateTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.TileTemplates.TileTemplate

  @valid_attrs %{name: "A Big X", description: "A big capital X", character: "X", color: "#F00", background_color: "black", responders: nil}
  @invalid_attrs %{name: "", character: "BIG"}

  test "changeset with valid attributes" do
    changeset = TileTemplate.changeset(%TileTemplate{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = TileTemplate.changeset(%TileTemplate{}, @invalid_attrs)
    refute changeset.valid?
    changeset = TileTemplate.changeset(%TileTemplate{}, Map.put(@invalid_attrs, :character, nil))
    refute changeset.valid?
    changeset = TileTemplate.changeset(%TileTemplate{}, Map.put(@invalid_attrs, :character, ""))
    refute changeset.valid?
    changeset = TileTemplate.changeset(%TileTemplate{}, Map.put(@valid_attrs, :color, "black\""))
    refute changeset.valid?
    changeset = TileTemplate.changeset(%TileTemplate{}, Map.put(@valid_attrs, :color, "#1"))
    refute changeset.valid?
  end
end
