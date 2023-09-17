defmodule DungeonCrawl.TileTemplates.TileTemplateTest do
  use DungeonCrawl.DataCase

  require DungeonCrawl.SharedTests

  alias DungeonCrawl.TileTemplates.TileTemplate

  @valid_attrs %{name: "A Big X", description: "A big capital X", character: "X", color: "#F00", background_color: "black", script: nil}
  @invalid_attrs %{name: "", character: "BIG", script: "#NOCOMMAND", state: "badstate", color: "#mm", background_color: "#mm", animate_period: 0}

  test "groups/0" do
    assert ["terrain", "doors", "monsters", "items", "misc", "custom"] == TileTemplate.groups
  end

  test "changeset with valid attributes" do
    changeset = TileTemplate.changeset(%TileTemplate{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = TileTemplate.changeset(%TileTemplate{}, @invalid_attrs)
    refute changeset.valid?
    errs = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
               Enum.reduce(opts, msg, fn {key, value}, acc ->
                 String.replace(acc, "%{#{key}}", to_string(value))
               end)
             end)
    assert errs[:script] == ["Unknown command: `NOCOMMAND` - near line 1"]
    assert errs[:state] == ["is invalid"]
    assert errs[:character] == ["should be at most 1 character(s)"]
    assert errs[:color] == ["has invalid format"]
    assert errs[:background_color] == ["has invalid format"]
    assert errs[:name] == ["can't be blank"]
    assert errs[:description] == ["can't be blank"]
    assert errs[:animate_period] == ["must be greater than 0"]

    changeset = TileTemplate.changeset(%TileTemplate{}, Map.put(@invalid_attrs, :character, nil))
    refute changeset.valid?
    changeset = TileTemplate.changeset(%TileTemplate{}, Map.put(@invalid_attrs, :character, ""))
    refute changeset.valid?
    changeset = TileTemplate.changeset(%TileTemplate{}, Map.put(@valid_attrs, :color, "black\""))
    refute changeset.valid?
    changeset = TileTemplate.changeset(%TileTemplate{}, Map.put(@valid_attrs, :color, "#1"))
    refute changeset.valid?
  end

  test "changeset with a parseable script that fails program validation" do
    script = """
             #BECOME character: bad, color: #000, background_color: #moose
             this line is ok
             #IF @something, NOTALABEL
             """
    changeset = TileTemplate.changeset(%TileTemplate{}, Map.put(@invalid_attrs, :script, script))
    refute changeset.valid?
    errs = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
               Enum.reduce(opts, msg, fn {key, value}, acc ->
                 String.replace(acc, "%{#{key}}", to_string(value))
               end)
             end)
    assert errs[:script] == ["""
                             Line 1: BECOME command has errors: `background_color - has invalid format`
                             Line 3: IF command references nonexistant label `NOTALABEL`
                             """ |> String.trim ]
  end

  test "changeset with a group" do
    changeset = TileTemplate.changeset(%TileTemplate{}, Map.put(@valid_attrs, :group_name, nil))
    assert changeset.valid?
    changeset = TileTemplate.changeset(%TileTemplate{}, Map.put(@valid_attrs, :group_name, "items"))
    assert changeset.valid?
    changeset = TileTemplate.changeset(%TileTemplate{}, Map.put(@valid_attrs, :group_name, "badgroup"))
    refute changeset.valid?
    errs = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
               Enum.reduce(opts, msg, fn {key, value}, acc ->
                 String.replace(acc, "%{#{key}}", to_string(value))
               end)
             end)
    assert errs[:group_name] == ["is invalid"]
  end

  DungeonCrawl.SharedTests.handles_state_variables_and_values_correctly(TileTemplate)
end
