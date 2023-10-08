defmodule DungeonCrawl.DungeonInstances.LevelTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Repo
  alias DungeonCrawl.DungeonInstances.Level
  alias DungeonCrawl.Player.Location

  test "on_delete deletes all associated player_locations" do
    level_instance = insert_autogenerated_level_instance()
    player_loc = insert_player_location(%{level_instance_id: level_instance.id})
    assert Repo.preload(level_instance, :locations).locations != []
    assert Repo.delete(level_instance)
    refute Repo.get_by(Location, %{user_id_hash: player_loc.user_id_hash})
    assert Repo.preload(level_instance, :locations).locations == []
  end

  test "level_instance number must be unique for dungeon and owner" do
    level_instance = insert_autogenerated_level_instance()
    changeset = Level.changeset(
                  %Level{player_location_id: nil},
                  Map.take(level_instance, [:number, :name, :level_id, :dungeon_instance_id, :height, :width])
                )

    assert {:error, %{errors: [number: {"Level Number already exists", _}]}} = Repo.insert(changeset)

    # level instance that is owned by a player
    other_player = insert_player_location(%{level_instance_id: level_instance.id})
    changeset = Level.changeset(
      %Level{},
      Map.take(level_instance, [:number, :name, :level_id, :dungeon_instance_id, :height, :width])
      |> Map.merge(%{player_location_id: other_player.id})
    )

    assert {:ok, _level} = Repo.insert(changeset)

    assert {:error, %{errors: [number: {"Level Number already exists", _}]}} = Repo.insert(changeset)
  end

  test "passage_exits" do
    level_instance_no_exits = insert_autogenerated_level_instance()
    level_instance = insert_autogenerated_level_instance(%{passage_exits: [{3, "seeded"}]})

    # retrieval
    assert [{3, "seeded"}] == level_instance.passage_exits
    assert [] == level_instance_no_exits.passage_exits

    # invalid passage exits
    assert %{errors: [{:passage_exits, {"is invalid", _}}]} =
        Level.changeset(level_instance, %{passage_exits: [{"123", "junk"}]})
    assert %{errors: [{:passage_exits, {"is invalid", _}}]} =
             Level.changeset(level_instance, %{passage_exits: "just wrong"})

    # valid passage exits
    assert [] == Level.changeset(level_instance, %{passage_exits: [{123, "junk"}]}).errors
    assert [] == Level.changeset(level_instance, %{passage_exits: [{123, "junk"},{1,"grey"}]}).errors
  end

  test "program_contexts" do
    program_contexts = %{
      3571654 => %{
        event_sender: %{
          name: "Fireball",
          state: %{
            "blocking" => false,
            "facing" => "up",
            "flying" => true,
            "light_range" => 2,
            "light_source" => true,
            "not_pushing" => true,
            "not_squishing" => true,
            "owner" => 3571971,
            "wait_cycles" => 2
          },
          tile_id: "new_0"
        },
        object_id: 3571654,
        program: %DungeonCrawl.Scripting.Program{
          broadcasts: [],
          instructions: %{
            1 => [:halt, [""]],
            2 => [:noop, "OPEN"],
            3 => [:become, [%{"slug" => "open_door"}]]
          },
          labels: %{"open" => [[2, true]]},
          lc: 0,
          locked: false,
          messages: [],
          pc: 0,
          responses: [],
          status: :idle,
          wait_cycles: 0
        }
      },
      3571881 => %{
        event_sender: nil,
        object_id: 3571881,
        program: %DungeonCrawl.Scripting.Program{
          broadcasts: [],
          instructions: %{
            1 => [:halt, [""]],
            2 => [:noop, "touch"],
            3 => [:jump_if, [event_sender_variable: :player]],
            4 => [:text, [["That lava looks hot, better not touch it."]]]
          },
          labels: %{
            "touch" => [[2, true]]
          },
          lc: 0,
          locked: false,
          messages: [],
          pc: 3,
          responses: [],
          status: :idle,
          wait_cycles: 0
        }
      },
      3571593 => %{
        event_sender: %DungeonCrawl.Player.Location{
          id: 3177,
          name: "Doc",
          state: %{
            "already_touched" => false,
            "ammo" => 6,
            "blocking" => true,
            "bullet_damage" => 10,
            "cash" => 0,
            "equipment" => ["gun"],
            "equipped" => "gun",
            "gems" => 0,
            "health" => 100,
            "lives" => -1,
            "player" => true,
            "pushable" => true,
            "score" => 0,
            "soft" => true,
            "starting_equipment" => "gun",
            "steps" => 13,
            "torches" => 0
          },
          tile_instance_id: 3572819,
          user_id_hash: "9fqSkIyUEajmy60SE5N4T6wvR6Dc7SL0"
        },
        object_id: 3571593,
        program: %DungeonCrawl.Scripting.Program{
          broadcasts: [],
          instructions: %{
            1 => [:noop, "top"],
            2 => [:compound_move, [{"idle", true}]],
            3 => [:sound, ["computing"]],
            4 => [:send_message, ["top"]]
          },
          labels: %{"top" => [[1, true]]},
          lc: 1,
          locked: false,
          messages: [],
          pc: 2,
          responses: [],
          status: :wait,
          wait_cycles: 1
        }
      }
    }

    level_instance_no_program_contexts = insert_autogenerated_level_instance()
    level_instance = insert_autogenerated_level_instance(%{program_contexts: program_contexts})

    # retrieval
    # make sure that after it goes into the DB and back out into the Level struct that it
    # matches exactly; atoms back to atoms, tuples back to tuples, labels with string keys
    assert program_contexts == Repo.get(Level, level_instance.id).program_contexts
    assert %{} == Repo.get(Level, level_instance_no_program_contexts.id).program_contexts
  end
end
