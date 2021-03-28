defmodule DungeonCrawl.Scripting.CommandTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.Scripting.Command
  alias DungeonCrawl.Scripting.Parser
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.DungeonProcesses.Instances

  import ExUnit.CaptureLog

  def program_fixture(script \\ nil) do
    script = script ||
             """
             #END
             No show this text
             :TOUCH
             testing
             #END
             """
    {:ok, program} = Parser.parse(script)
    program
  end

  test "get_command/1" do
    assert Command.get_command(" BECOME  ") == :become
    assert Command.get_command(:become) == :become
    assert Command.get_command(:change_state) == :change_state
    assert Command.get_command(:change_instance_state) == :change_instance_state
    assert Command.get_command(:change_other_state) == :change_other_state
    assert Command.get_command(:cycle) == :cycle
    assert Command.get_command(:die) == :die
    assert Command.get_command(:end) == :halt    # exception to the naming convention, cant "def end do"
    assert Command.get_command(:give) == :give
    assert Command.get_command(:go) == :go
    assert Command.get_command(:if) == :jump_if
    assert Command.get_command(:lock) == :lock
    assert Command.get_command(:move) == :move
    assert Command.get_command(:noop) == :noop
    assert Command.get_command(:passage) == :passage
    assert Command.get_command(:push) == :push
    assert Command.get_command(:put) == :put
    assert Command.get_command(:random) == :random
    assert Command.get_command(:replace) == :replace
    assert Command.get_command(:remove) == :remove
    assert Command.get_command(:restore) == :restore
    assert Command.get_command(:shift) == :shift
    assert Command.get_command(:target_player) == :target_player
    assert Command.get_command(:take) == :take
    assert Command.get_command(:text) == :text
    assert Command.get_command(:transport) == :transport
    assert Command.get_command(:try) == :try
    assert Command.get_command(:unlock) == :unlock
    assert Command.get_command(:walk) == :walk
    assert Command.get_command(:zap) == :zap

    refute Command.get_command(:fake_not_real)
  end

  test "BECOME" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, character: ".", map_instance_id: 1})
    program = program_fixture()
    params = [%{character: "~", color: "puce", health: 20}]

    %Runner{state: state} = Command.become(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert Map.take(updated_map_tile, [:character, :color]) == %{character: "~", color: "puce"}
    assert updated_map_tile.state == "health: 20"
    assert updated_map_tile.parsed_state == %{health: 20}
  end

  test "BECOME when script should be unaffected" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, character: ".", map_instance_id: 1, script: "#END\n:TOUCH\n*creak*"})
    program = state.program_contexts[map_tile.id].program
    params = [%{character: "~"}]

    %Runner{state: state, program: updated_program} = Command.become(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert updated_map_tile.character == "~"
    assert updated_program.broadcasts == []
    assert Map.has_key? state.rerender_coords, %{row: 1, col: 2}
    assert Map.take(program, Map.keys(program) -- [:broadcasts]) == Map.take(updated_program, Map.keys(updated_program) -- [:broadcasts])
  end

  test "BECOME a ttid" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, character: ".", map_instance_id: 1})
    program = program_fixture()
    squeaky_door = insert_tile_template(%{script: "#END\n:TOUCH\nSQUEEEEEEEEEK", state: "blocking: true"})
    params = [{:ttid, squeaky_door.id}]

    %Runner{program: program, state: state} = Command.become(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)

    refute Map.take(updated_map_tile, [:state]) == %{state: map_tile.state}
    refute Map.take(updated_map_tile, [:parsed_state]) == %{parsed_state: map_tile.parsed_state}
    refute Map.take(updated_map_tile, [:script]) == %{script: map_tile.script}
    assert Map.take(updated_map_tile, [:character, :color, :script]) == Map.take(squeaky_door, [:character, :color, :script])
    assert program.status == :wait
    assert %{1 => [:halt, [""]],
             2 => [:noop, "TOUCH"],
             3 => [:text, [["SQUEEEEEEEEEK"]]]} = program.instructions
    assert %{blocking: true} = updated_map_tile.parsed_state

    # BECOME a ttid with no script, when currently has script
    fake_door = insert_tile_template(%{script: "", state: "blocking: true", character: "'"})
    params = [{:ttid, fake_door.id}]

    %Runner{program: program, state: updated_state} = Command.become(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)

    refute Map.take(updated_map_tile, [:script]) == %{script: squeaky_door.script}
    assert Map.take(updated_map_tile, [:character]) == Map.take(fake_door, [:character])
    assert program.status == :dead
  end

  test "BECOME a ttid deprecated log" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, character: ".", map_instance_id: 1})
    program = program_fixture()
    squeaky_door = insert_tile_template(%{script: "#END\n:TOUCH\nSQUEEEEEEEEEK", state: "blocking: true"})
    params = [{:ttid, squeaky_door.id}]

    assert capture_log(fn ->
        Command.become(%Runner{program: program, object_id: map_tile.id, state: state}, params)
      end) =~ ~r/\[warn\] DEPRECATION - BECOME command used `TTID:#{squeaky_door.id}`, replace this with `slug: #{squeaky_door.slug}`/
  end

  test "BECOME a SLUG" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, character: ".", map_instance_id: 1})
    program = program_fixture()
    squeaky_door = insert_tile_template(%{character: "!", script: "#END\n:TOUCH\nSQUEEEEEEEEEK", state: "blocking: true", active: true, color: "red"})
    params = [%{slug: squeaky_door.slug, character: "?"}]

    %Runner{program: program, state: state} = Command.become(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)

    refute updated_map_tile.state == map_tile.state
    refute updated_map_tile.parsed_state == map_tile.parsed_state
    refute updated_map_tile.script == map_tile.script
    # Other kwarg can overwrite fields from the SLUG
    refute updated_map_tile.character == squeaky_door.character
    assert updated_map_tile.character == "?"
    assert Map.take(updated_map_tile, [:color, :script]) == Map.take(squeaky_door, [:color, :script])
    assert program.status == :wait
    assert %{1 => [:halt, [""]],
             2 => [:noop, "TOUCH"],
             3 => [:text, [["SQUEEEEEEEEEK"]]]} = program.instructions
    assert %{blocking: true} = updated_map_tile.parsed_state

    # BECOME with variables that resolve to invalid values does nothing
    params = [%{slug: squeaky_door.slug, color: {:state_variable, :character}}]
    updated_runner_state = Command.become(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    assert updated_runner_state == %Runner{program: program, object_id: map_tile.id, state: state}

    # BECOME a slug with no script, when currently has script
    fake_door = insert_tile_template(%{script: "", state: "blocking: true", character: "'", active: true})
    params = [%{slug: fake_door.slug, blocking: false}]

    %Runner{program: program, state: state} = Command.become(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)

    assert updated_map_tile.state == "blocking: false"
    refute updated_map_tile.state == squeaky_door.state
    assert updated_map_tile.parsed_state == %{blocking: false}
    refute updated_map_tile.script == squeaky_door.script
    assert updated_map_tile.character == fake_door.character
    assert program.status == :dead

    # BECOME a nonexistant slug does nothing
    params = [%{slug: "notreal"}]

    %Runner{state: state} = Command.become(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    not_updated_map_tile = Instances.get_map_tile_by_id(state, updated_map_tile)

    assert updated_map_tile.script == not_updated_map_tile.script
    assert updated_map_tile.character == not_updated_map_tile.character
  end

  test "CHANGE_STATE" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: ".", state: "one: 100, add: 8"})
    program = program_fixture()

    %Runner{state: updated_state} = Command.change_state(%Runner{program: program, object_id: map_tile.id, state: state}, [:add, "+=", 1])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "add: 9, one: 100"
    %Runner{state: updated_state} = Command.change_state(%Runner{program: program, object_id: map_tile.id, state: state}, [:one, "=", 432])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "add: 8, one: 432"
    %Runner{state: updated_state} = Command.change_state(%Runner{program: program, object_id: map_tile.id, state: state}, [:new, "+=", 1])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "add: 8, new: 1, one: 100"
  end

  test "CHANGE_INSTANCE_STATE" do
    {_map_tile, state} = Instances.create_map_tile(%Instances{state_values: %{one: 100, add: 8}}, %MapTile{id: 123, row: 1, col: 2, character: "."})

    %Runner{state: updated_state} = Command.change_instance_state(%Runner{state: state}, [:add, "+=", 1])
    assert updated_state.state_values == %{add: 9, one: 100}
    %Runner{state: updated_state} = Command.change_instance_state(%Runner{state: state}, [:one, "=", 432])
    assert updated_state.state_values == %{add: 8, one: 432}
    %Runner{state: updated_state} = Command.change_instance_state(%Runner{state: state}, [:new, "+=", 1])
    assert updated_state.state_values == %{add: 8, new: 1, one: 100}
  end

  test "CHANGE_OTHER_STATE" do
    {map_tile_1, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "@", state: "one: 100, add: 8, player: true"})
    {map_tile_2, state} = Instances.create_map_tile(state, %MapTile{id: 124, row: 0, col: 2, z_index: 0, character: ".", state: "one: 1"})
    program = program_fixture()

    runner_state = %Runner{program: program, object_id: map_tile_1.id, state: state}

    %Runner{state: updated_state} = Command.change_other_state(runner_state, [map_tile_2.id, :foo, "+=", 1])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile_2)
    assert updated_map_tile.state == "foo: 1, one: 1"
    %Runner{state: updated_state} = Command.change_other_state(runner_state, [map_tile_2.id, :one, "=", 432])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile_2)
    assert updated_map_tile.state == "one: 432"
    %Runner{state: updated_state} = Command.change_other_state(runner_state, ["north", :new, "+=", 1])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile_2)
    assert updated_map_tile.state == "new: 1, one: 1"
    %Runner{state: updated_state} = Command.change_other_state(runner_state, ["south", :new, "+=", 1])
    assert updated_state == runner_state.state
    %Runner{state: updated_state} = Command.change_other_state(runner_state, [map_tile_1.id, :new, "+=", 1])
    assert updated_state == runner_state.state
  end

  test "CYCLE" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()

    %Runner{state: state} = Command.cycle(%Runner{program: program, object_id: map_tile.id, state: state}, [3])
    map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert map_tile.state == "wait_cycles: 3"
    %Runner{state: state} = Command.cycle(%Runner{program: program, object_id: map_tile.id, state: state}, [-2])
    map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert map_tile.state == "wait_cycles: 3"
    %Runner{state: state} = Command.cycle(%Runner{program: program, object_id: map_tile.id, state: state}, [1])
    map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert map_tile.state == "wait_cycles: 1"
  end

  test "COMPOUND_MOVE" do
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    state = %{ state | rerender_coords: %{} }

    # Successful
    %Runner{program: program, state: state} = Command.compound_move(%Runner{object_id: mover.id, state: state},
                                                                    [{"west", true}, {"east", true}])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 0,
             lc: 1
           } = program
    assert Map.has_key? state.rerender_coords, %{row: 1, col: 1}
    assert Map.has_key? state.rerender_coords, %{row: 1, col: 2}
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover

    # Unsuccessful (but its a try and move that does not keep trying)
    state = %{ state | rerender_coords: %{} }
    %Runner{program: program, state: state} = Command.compound_move(%Runner{object_id: mover.id, state: state},
                                                                    [{"south", false}])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 0,
             lc: 1
           } = program
    assert state.rerender_coords == %{}
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover

    # Unsuccessful (but its a retry until successful)
    %Runner{program: program, state: state} = Command.compound_move(%Runner{object_id: mover.id, state: state},
                                                                    [{"south", true}, {"east", true}])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 0,
             lc: 0
           } = program
    assert state.rerender_coords == %{}
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover

    # Last movement already done
    runner_state = %Runner{object_id: mover.id, state: state, program: %Program{ status: :alive, lc: 2 }}
    %Runner{program: program} = Command.compound_move(runner_state, [{"idle", true}, {"east", true}])
    assert %{status: :alive,
             wait_cycles: 0,
             broadcasts: [],
             pc: 1,
             lc: 0
           } = program
    assert state.rerender_coords == %{}
  end

  test "COMPOUND_MOVE into something blocking (or a nil square) triggers a THUD event" do
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    program = program_fixture("""
                              /s/w?e?e
                              #END
                              #END
                              :THUD
                              #BECOME character: X
                              """)

    %Runner{program: program} = Command.compound_move(%Runner{program: program, object_id: mover.id, state: state}, [{"south", true}])

    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1,
             lc: 0,
             messages: [{"THUD", %{map_tile_id: nil, parsed_state: %{}}}]
           } = program
  end

  test "DIE" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 1, character: "$"})
    {under_tile, state} = Instances.create_map_tile(state, %MapTile{id: 45, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()

    %Runner{program: program, state: state} = Command.die(%Runner{program: program, object_id: map_tile.id, state: state})
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert under_tile == Instances.get_map_tile(state, map_tile)
    assert program.status == :dead
    assert program.pc == -1
    refute updated_map_tile
    assert [] = program.broadcasts
    assert Map.has_key? state.rerender_coords, %{row: 1, col: 2}
  end

  test "GIVE" do
    script = """
             #END
             :fullhealth
             Already at full health
             """
    {receiving_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: "E", row: 1, col: 1, z_index: 0, state: "health: 1"})
    {giver, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 2, col: 1, z_index: 1, state: "medkits: 3", script: script, color: "red"})

    program = program_fixture(script)

    runner_state = %Runner{object_id: giver.id, state: state, program: program}

    # give state var in direction
    %Runner{state: %{map_by_ids: map}} = Command.give(runner_state, ["health", {:state_variable, :medkits}, "north"])
    assert map[receiving_tile.id].parsed_state[:health] == 4

    # Does nothing when there's no map tile
    %Runner{state: updated_state} = Command.give(runner_state, ["health", {:state_variable, :medkits}, "south"])
    assert updated_state == state

    # Does nothing when the direction is invalid
    %Runner{state: updated_state} = Command.give(runner_state, ["health", {:state_variable, :medkits}, "norf"])
    assert updated_state == state

    # give state var to event sender (tile)
    %Runner{state: %{map_by_ids: map}} = Command.give(%{runner_state | event_sender: %{map_tile_id: receiving_tile.id}},
                                                      ["ammo", 12, [:event_sender]])
    assert map[receiving_tile.id].parsed_state[:ammo] == 12

    # give state var to event sender (player)
    runner_state_with_player = %{ runner_state |
                                    state: %{ runner_state.state |
                                                player_locations: %{receiving_tile.id => %Location{map_tile_instance_id: receiving_tile.id} }}}
    %Runner{state: %{map_by_ids: map}} = Command.give(%{runner_state_with_player | event_sender: %Location{map_tile_instance_id: receiving_tile.id}},
                                                      ["gems", 1, [:event_sender]])
    assert map[receiving_tile.id].parsed_state[:gems] == 1

    # give handles null state variable
    %Runner{state: %{map_by_ids: map}} = Command.give(%{runner_state_with_player | event_sender: %Location{map_tile_instance_id: receiving_tile.id}},
                                                      ["health", {:state_variable, :nonexistant}, [:event_sender]])
    assert map[receiving_tile.id].parsed_state[:health] == 1

    # Does nothing when there is no event sender
    %Runner{state: updated_state} = Command.give(%{runner_state | event_sender: nil}, [:health, {:state_variable, :nonexistant}, [:event_sender]])
    assert updated_state == state

    # Give a state variable
    %Runner{state: %{map_by_ids: map}} = Command.give(runner_state, [{:state_variable, :color}, 1, "north", 1, "fullhealth"])
    assert map[receiving_tile.id].parsed_state[:red] == 1

    # Give up to the max
    assert map[receiving_tile.id].parsed_state[:health] == 1
    %Runner{state: %{map_by_ids: map}} = Command.give(runner_state, ["health", 5, "north", 10, "fullhealth"])
    assert map[receiving_tile.id].parsed_state[:health] == 6
    %Runner{state: %{map_by_ids: map}} = Command.give(runner_state, ["health", 10, "north", 10])
    assert map[receiving_tile.id].parsed_state[:health] == 10

    # Give no more than the max
    %Runner{state: %{map_by_ids: map}} = Command.give(runner_state, ["health", 1, "north", 1])
    assert map[receiving_tile.id].parsed_state[:health] == 1

    # If already at max and there's a label, jump to it
    %Runner{state: updated_state, program: up} = Command.give(runner_state, ["health", 1, "north", 1, "fullhealth"])
    assert updated_state.map_by_ids[receiving_tile.id].parsed_state[:health] == 1
    assert up == %{ runner_state.program | pc: 2, status: :wait, wait_cycles: 1 }
    assert [] = updated_state.program_messages

    # Give using interpolated value
    %Runner{state: %{map_by_ids: map}} = Command.give(runner_state, [{:state_variable, :color, "_key"}, 1, "north", 1])
    assert map[receiving_tile.id].parsed_state[:red_key] == 1

    # Give using interpolated value that is not a string. (Giving param 1 must resolve to a binary, otherwise nothing is given)
    %Runner{state: %{map_by_ids: map}} = Command.give(runner_state, [{:state_variable, :medkits, "_key"}, 1, "north"])
    assert map[receiving_tile.id].parsed_state == %{health: 1}
  end

  test "GO" do
    # Basically Move with true
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    assert Command.go(%Runner{object_id: mover.id, state: state}, ["left"]) == Command.move(%Runner{object_id: mover.id, state: state}, ["left", true])

    # Unsuccessful
    assert Command.go(%Runner{object_id: mover.id, state: state}, ["down"]) == Command.move(%Runner{object_id: mover.id, state: state}, ["down", true])
  end

  test "HALT/END" do
    program = program_fixture()
#    stubbed_object = %{id: 1, state: ""}
#    stubbed_state = %{map_by_ids: %{1 => stubbed_object}}

    %Runner{program: program} = Command.halt(%Runner{program: program})
    assert program.status == :idle
    assert program.pc == -1
  end

  test "FACING" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: ".", state: "facing: up, rico: west"})
    {west_tile, state} = Instances.create_map_tile(state, %MapTile{id: 124, row: 1, col: 1, z_index: 1, character: "."})
    program = program_fixture()
    runner_state = %Runner{program: program, object_id: map_tile.id, state: state}

    %Runner{state: updated_state} = Command.facing(runner_state, [{:state_variable, :rico}])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "facing: west, rico: west"
    %Runner{state: updated_state} = Command.facing(runner_state, ["east"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "facing: east, rico: west"
    %Runner{state: updated_state} = Command.facing(runner_state, ["clockwise"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "facing: east, rico: west"
    %Runner{state: updated_state} = Command.facing(runner_state, ["counterclockwise"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "facing: west, rico: west"
    %Runner{state: updated_state} = Command.facing(runner_state, ["reverse"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "facing: south, rico: west"
    %Runner{state: updated_state} = Command.facing(runner_state, ["player"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "facing: idle, rico: west, target_player_map_tile_id: nil"

    # Facing to player direction targets that player when it is not targeting a player
    {fake_player, state} = Instances.create_player_map_tile(state, %MapTile{id: 43201, row: 2, col: 2, z_index: 0, character: "@"}, %Location{})
    runner_state = %Runner{program: program, object_id: map_tile.id, state: state}
    %Runner{state: updated_state} = Command.facing(runner_state, ["player"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "facing: south, rico: west, target_player_map_tile_id: 43201"

    # Facing to player direction when there is no players sets facing to idle and the target player to nil
    {_fake_player, state} = Instances.delete_map_tile(state, fake_player)
    runner_state = %Runner{program: program, object_id: map_tile.id, state: state}
    %Runner{state: updated_state} = Command.facing(runner_state, ["player"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "facing: idle, rico: west, target_player_map_tile_id: nil"

    # facing tile id
    %Runner{state: state} = Command.facing(%Runner{program: program, object_id: map_tile.id, state: state}, [west_tile.id])
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert updated_map_tile.state == "facing: west, rico: west"
  end

  test "FACING - derivative when facing state var does not exist" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "."})
    {_west_tile, state} = Instances.create_map_tile(state, %MapTile{id: 124, row: 1, col: 1, z_index: 1, character: "."})
    program = program_fixture()

    %Runner{state: state} = Command.facing(%Runner{program: program, object_id: map_tile.id, state: state}, ["clockwise"])
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert updated_map_tile.state == "facing: idle"
    %Runner{state: state} = Command.facing(%Runner{program: program, object_id: map_tile.id, state: state}, ["counterclockwise"])
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert updated_map_tile.state == "facing: idle"
    %Runner{state: state} = Command.facing(%Runner{program: program, object_id: map_tile.id, state: state}, ["reverse"])
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert updated_map_tile.state == "facing: idle"
    %Runner{state: state} = Command.facing(%Runner{program: program, object_id: map_tile.id, state: state}, [111])
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert updated_map_tile.state == "facing: idle"
  end

  test "JUMP_IF when state check is TRUE" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, state: "thing: true", color: "red", background_color: "white"})
    program = program_fixture()
#    map_tile = %{id: 1, state: "thing: true", parsed_state: %{thing: true}}
#    state = %Instances{map_by_ids: %{1 => stubbed_object}}
    params = [{:state_variable, :thing}, "TOUCH"]

    %Runner{program: updated_program} = Command.jump_if(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 3

    # with explicit check
    params = [[{:state_variable, :thing}, "==", true], "TOUCH"]

    %Runner{program: updated_program} = Command.jump_if(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 3

    # check the special state_variables
    params = [[{:state_variable, :color}, "==", "red"], "TOUCH"]
    %Runner{program: updated_program} = Command.jump_if(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    assert updated_program.pc == 3
  end

  test "JUMP_IF when state check is FALSE" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, state: "thing: true"})
    program = program_fixture()
#    stubbed_object = %{state: "thing: true", parsed_state: %{thing: true}}
    params = [["!", {:state_variable, :thing}], "TOUCH"]

    assert program.status == :alive
    %Runner{program: updated_program} = Command.jump_if(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 1

    # with explicit check
    params = [["!", {:state_variable, :thing}, "==", true], "TOUCH"]

    %Runner{program: updated_program} = Command.jump_if(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 1

    # with explicit check
    params = [["!", {:state_variable, :thing}, "==", {:state_variable, :thing}], "TOUCH"]

    %Runner{program: updated_program} = Command.jump_if(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 1

    # check the special state_variables
    params = [[{:state_variable, :background_color}, "==", "black"], "TOUCH"]
    %Runner{program: updated_program} = Command.jump_if(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    assert updated_program.pc == 1

    params = [[{:state_variable, :name}, "==", "Russ"], "TOUCH"]
    %Runner{program: updated_program} = Command.jump_if(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    assert updated_program.pc == 1
  end

  test "JUMP_IF when state check is TRUE but no active label" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, state: "thing: true"})
    program = program_fixture()
    params = [{:state_variable, :thing}, "TOUCH"]

    program = %{ program | labels: %{"TOUCH" => [[3, true]]} }
    %Runner{program: program} = Command.jump_if(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    assert program.status == :alive
    assert program.pc == 1
  end

  test "JUMP_IF when no label given" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, state: "thing: true"})
    program = program_fixture()
    runner_state = %Runner{program: program, object_id: map_tile.id, state: state}

    # when true, does not modify pc
    params = [{:state_variable, :thing}]
    %Runner{program: updated_program} = Command.jump_if(runner_state, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 1

    # when flase, modifes the pc to skip the next instruction
    params = [{:state_variable, :notathing}]
    %Runner{program: updated_program} = Command.jump_if(runner_state, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 2
  end

  test "JUMP_IF when using a check against a variable on the event sender" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1})
    event_sender = %{parsed_state: %{health: "50"}}
    program = program_fixture()
    params = [[{:event_sender_variable, :health}, ">", 25], "TOUCH"]
    runner_state = %Runner{program: program, object_id: map_tile.id, state: state, event_sender: event_sender}

    assert program.status == :alive
    %Runner{program: updated_program} = Command.jump_if(runner_state, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 3

    # No event sender
    runner_state = %{ runner_state | event_sender: nil}
    %Runner{program: updated_program} = Command.jump_if(runner_state, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 1
  end

  test "JUMP_IF when using a check against an instance state value" do
    {map_tile, state} = Instances.create_map_tile(%Instances{state_values: %{red_flag: true}}, %MapTile{id: 1})
    program = program_fixture()
    params = [{:instance_state_variable, :red_flag}, "TOUCH"]
    runner_state = %Runner{program: program, object_id: map_tile.id, state: state}

    assert program.status == :alive
    %Runner{program: updated_program} = Command.jump_if(runner_state, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 3
  end

  test "JUMP_IF when using a check against a tile in a direction" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, row: 1, col: 1})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, row: 0, col: 1, state: "password: bob"})
    program = program_fixture()
    params = [[{{:direction, "north"}, :password}, "==", "bob"], "TOUCH"]
    runner_state = %Runner{program: program, object_id: map_tile.id, state: state}

    assert program.status == :alive
    %Runner{program: updated_program} = Command.jump_if(runner_state, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 3

    # No tile in that direction
    params = [[{{:direction, "south"}, :password}, "==", "bob"], "TOUCH"]
    %Runner{program: updated_program} = Command.jump_if(runner_state, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 1
  end

  test "LOCK" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()

    %Runner{state: state} = Command.lock(%Runner{program: program, object_id: map_tile.id, state: state}, [])
    map_tile = Instances.get_map_tile(state, map_tile)
    assert map_tile.state == "locked: true"
    assert map_tile.parsed_state == %{locked: true}
  end

  test "MOVE with one param" do
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 4, character: "#", row: 0, col: 1, z_index: 0, state: "blocking: true"})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    state = %{ state | rerender_coords: %{} }

    # Successful
    %Runner{program: program, state: state} = Command.move(%Runner{object_id: mover.id, state: state}, ["left"])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert Map.has_key? state.rerender_coords, %{row: 1, col: 1}
    assert Map.has_key? state.rerender_coords, %{row: 1, col: 2}
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover
    assert [{1, "touch", %{map_tile_id: 3}}] = state.program_messages
    state = %{state | program_messages: []}
    state = %{ state | rerender_coords: %{} }

    # Unsuccessful (but its a try and move that does not keep trying)
    %Runner{program: program, state: state} = Command.move(%Runner{object_id: mover.id, state: state}, ["down"])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert state.rerender_coords == %{}
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover
    assert [] = state.program_messages
    state = %{state | program_messages: []}

    # Unsuccessful - uses the wait cycles from the state
    %Runner{program: program, state: state} = Command.move(%Runner{object_id: mover.id, state: state}, ["up"])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert state.rerender_coords == %{}
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover
    assert [{4, "touch", %{map_tile_id: 3}}] = state.program_messages
    state = %{state | program_messages: []}

    # Idle
    %Runner{program: program, state: state} = Command.move(%Runner{object_id: mover.id, state: state}, ["idle"])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert state.rerender_coords == %{}
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover
    assert [] = state.program_messages

    # Moving in player direction targets a player when it is not targeting a player
    {fake_player, state} = Instances.create_player_map_tile(state, %MapTile{id: 43201, row: 2, col: 2, z_index: 0, character: "@"}, %Location{})
    %Runner{state: state} = Command.move(%Runner{object_id: mover.id, state: state}, ["player"])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{row: 1,
             col: 2,
             character: "c",
             state: "facing: east, target_player_map_tile_id: 43201",
             z_index: 1} = mover

    # Moving in player direction keeps after that player
    {another_fake_player, state} = Instances.create_player_map_tile(state, %MapTile{id: 43215, row: 1, col: 5, z_index: 0, character: "@"}, %Location{})
    %Runner{program: program, state: state} = Command.move(%Runner{object_id: mover.id, state: state}, ["player"])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{row: 2,
             col: 2,
             character: "c",
             state: "facing: south, target_player_map_tile_id: 43201",
             z_index: 1} = mover

    # When target player leaves dungeon, another target is chosen
    {_, state} = Instances.delete_map_tile(state, fake_player)
    %Runner{state: state} = Command.facing(%Runner{program: program, object_id: mover.id, state: state}, ["player"])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{row: 2,
             col: 2,
             character: "c",
             state: "facing: north, target_player_map_tile_id: 43215",
             z_index: 1} = mover
    {_, state} = Instances.delete_map_tile(state, another_fake_player)

    # Move towards player (will end up being unchanged since no players remaining)
    %Runner{program: program, state: state} = Command.move(%Runner{object_id: mover.id, state: state}, ["player"])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert %{row: 2,
             col: 2,
             character: "c",
             state: "facing: north, target_player_map_tile_id: nil",
             z_index: 1} = mover
  end

  test "MOVE with two params" do
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    state = %{ state | rerender_coords: %{} }

    %Runner{program: program, state: updated_state} = Command.move(%Runner{object_id: mover.id, state: state}, ["left", true])
    mover = Instances.get_map_tile_by_id(updated_state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert Map.has_key? updated_state.rerender_coords, %{row: 1, col: 1}
    assert Map.has_key? updated_state.rerender_coords, %{row: 1, col: 2}
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover

    # Unsuccessful
    %Runner{program: program, state: updated_state} = Command.move(%Runner{object_id: mover.id, state: state}, ["down", true])
    mover = Instances.get_map_tile_by_id(updated_state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 0 # decremented so when runner increments the PC it will still be the current move command
           } = program
    assert updated_state.rerender_coords == %{}
    assert %{row: 1, col: 2, character: "c", z_index: 1} = mover
  end

  test "MOVE using a state variable" do
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1, state: "facing: west"})

    %Runner{program: program, state: state} = Command.move(%Runner{object_id: mover.id, state: state}, [{:state_variable, :facing}, true])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert Map.has_key? state.rerender_coords, %{row: 1, col: 1}
    assert Map.has_key? state.rerender_coords, %{row: 1, col: 2}
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover
  end

  test "MOVE into something blocking (or a nil square) triggers a THUD event" do
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 4, character: ".", row: 2, col: 2, z_index: 0, state: "blocking: true"})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    program = program_fixture("""
                              #MOVE south
                              #END
                              #END
                              :THUD
                              #BECOME character: X
                              """)

    %Runner{program: program} = Command.move(%Runner{program: program, object_id: mover.id, state: state}, ["south", true])

    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1,
             messages: [{"THUD", %{map_tile_id: 4, parsed_state: %{blocking: true}}}]
           } = program
  end

  test "NOOP" do
    program = program_fixture()
    stubbed_object = %{id: 1, state: "thing: true"}
    stubbed_state = %Instances{map_by_ids: %{ 1 => stubbed_object } }
    runner_state = %Runner{object_id: stubbed_object.id, program: program, state: stubbed_state}
    assert runner_state == Command.noop(runner_state)
  end

  test "PASSAGE" do
    {map_tile_1, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, character: "<"})
    {map_tile_2, state} = Instances.create_map_tile(state, %MapTile{id: 124, row: 1, col: 4, character: ">", background_color: "puce"})

    %Runner{state: state} = Command.passage(%Runner{state: state, object_id: map_tile_1.id}, ["gray"])
    assert state.passage_exits == [{map_tile_1.id, "gray"}]
    %Runner{state: state} = Command.passage(%Runner{state: state, object_id: map_tile_2.id}, [{:state_variable, :background_color}])
    assert state.passage_exits == [{map_tile_2.id, "puce"}, {map_tile_1.id, "gray"}]
  end

  test "PULL" do
    state = %Instances{}
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 1, character: ".", row: 0, col: 1, z_index: 0})
    {pulled, state} = Instances.create_map_tile(state, %MapTile{id: 5, character: "P", row: 0, col: 1, z_index: 1, state: "pullable: true"})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 1, z_index: 0})
    {puller, state} = Instances.create_map_tile(state, %MapTile{id: 4, character: "@", row: 1, col: 1, z_index: 1, script: "#PULL south\n#NOOP"})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: ".", row: 2, col: 1, z_index: 0})

    program = program_fixture("""
                              #PULL south
                              #END
                              #END
                              :THUD
                              #BECOME character: X
                              """)

    # pull
    runner_state = %Runner{object_id: puller.id, state: state, program: program}
    %Runner{program: program, state: state} = Command.pull(runner_state, ["south"])
    pulled = Instances.get_map_tile_by_id(state, pulled)
    puller = Instances.get_map_tile_by_id(state, puller)
    assert %{broadcasts: [],
            status: :wait,
            wait_cycles: 5,
            pc: 1
           } = program
    assert Map.has_key? state.rerender_coords, %{row: 0, col: 1}
    assert Map.has_key? state.rerender_coords, %{row: 1, col: 1}
    assert Map.has_key? state.rerender_coords, %{row: 2, col: 1}

    assert %{row: 1, col: 1, character: "P", z_index: 1} = Instances.get_map_tile_by_id(state, pulled)
    assert %{row: 2, col: 1, character: "@", z_index: 1} = Instances.get_map_tile_by_id(state, puller)

    # Pull, but blocked
    updated_runner_state = Command.pull(runner_state, ["west"])
    assert updated_runner_state.program == %{ updated_runner_state.program | pc: 1, status: :wait, wait_cycles: 5}

    # pull with second param as false is the same as without it
    assert Command.pull(runner_state, ["west"]) == Command.pull(runner_state, ["west", false])
    assert Command.pull(runner_state, ["south"]) == Command.pull(runner_state, ["south", false])
    assert Command.pull(runner_state, ["north"]) == Command.pull(runner_state, ["north", false])

    # Pull, but blocked and retry
    %Runner{program: program} = Command.pull(runner_state, ["west", true])
    assert program == %{ runner_state.program | pc: 1,
                                                status: :wait,
                                                wait_cycles: 5,
                                                messages: [{"THUD", %{map_tile_id: nil, parsed_state: %{}}}]}
  end

  test "PUSH" do
    state = %Instances{}
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 1, character: ".", row: 0, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 5, character: "@", row: 0, col: 1, z_index: 1, state: "pushable: true, blocking: true"})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: ".", row: 2, col: 1, z_index: 0})
    {pusher, state} = Instances.create_map_tile(state, %MapTile{id: 4, character: "P", row: 3, col: 1, z_index: 0, state: "facing: north, side: norf, pushable: true"})

    # Nothing in range
    runner_state = %Runner{object_id: pusher.id, state: state}
    updated_runner_state = Command.push(runner_state, ["left"])
    assert runner_state == updated_runner_state

    # Pushable cannot be pushed
    updated_runner_state = Command.push(runner_state, ["left", 3])
    assert runner_state == updated_runner_state

    # Pushes
    {pushed, state} = Instances.create_map_tile(state, %MapTile{id: 6, character: "2", row: 2, col: 1, z_index: 1, state: "pushable: true, blocking: true"})
    runner_state = %Runner{object_id: pusher.id, state: state}
    %Runner{program: program, state: state} = Command.push(runner_state, [{:state_variable, :facing}, 3])
    pushed = Instances.get_map_tile_by_id(state, pushed)
    assert %{broadcasts: []} = program
    assert Map.has_key? state.rerender_coords, %{col: 1, row: 1}
    assert Map.has_key? state.rerender_coords, %{col: 1, row: 2}
    assert %{row: 1, col: 1, character: "2", z_index: 1} = pushed
  end

  test "PUT" do
    instance = insert_stubbed_dungeon_instance(%{},
      [%MapTile{character: ".", row: 1, col: 2, z_index: 0, color: "orange"},
       %MapTile{character: ".", row: 1, col: 3, z_index: 0},
       %MapTile{character: ".", row: 1, col: 4, z_index: 0},
       %MapTile{character: ".", row: 1, col: 5, z_index: 0}])

    # Quik and dirty state init
    state = Repo.preload(instance, :dungeon_map_tiles).dungeon_map_tiles
            |> Enum.reduce(%Instances{}, fn(dmt, state) ->
                 {_, state} = Instances.create_map_tile(state, dmt)
                 state
               end)
    state = Map.put(state, :state_values, %{rows: 20, cols: 20})

    map_tile = Instances.get_map_tile(state, %{row: 1, col: 2})

    program = program_fixture()
    squeaky_door = insert_tile_template(%{character: "!", script: "#END\n:TOUCH\nSQUEEEEEEEEEK", state: "blocking: true", active: true})
    params = [%{slug: squeaky_door.slug, character: "?", direction: "south"}]
    runner_state = %Runner{program: program, object_id: map_tile.id, state: state}

    %Runner{program: program, state: updated_state} = Command.put(runner_state, params)
    new_map_tile = Instances.get_map_tile(updated_state, %{row: 2, col: 2})
    assert new_map_tile.character == "?"
#    assert new_map_tile.slug == squeaky_door.slug
    assert Map.take(new_map_tile, [:color, :script]) == Map.take(squeaky_door, [:color, :script])
    assert program.broadcasts == []
    assert Map.has_key? updated_state.rerender_coords, %{row: 2, col: 2}
    assert %{blocking: true} = new_map_tile.parsed_state
    assert updated_state.new_ids == %{"new_0" => 0}
    assert updated_state.map_by_ids["new_0"]

    # PUT a clone
    params = [%{clone: map_tile.id, direction: "east", cloned: true}]
    %Runner{program: program, state: updated_state} = Command.put(runner_state, params)
    map_tile_1_3 = Instances.get_map_tile(updated_state, %{row: 1, col: 3})
    assert map_tile_1_3.parsed_state[:cloned]
    assert Map.take(map_tile_1_3, [:character, :color]) == Map.take(map_tile, [:character, :color])
    assert program.broadcasts == []
    assert Map.has_key? updated_state.rerender_coords, %{row: 1, col: 3}

    # PUT a clone noop if bad clone id
    params = [%{clone: 12312312312, direction: "east", cloned: true}]
    %Runner{program: program, state: updated_state} = Command.put(runner_state, params)
    assert updated_state == runner_state.state
    assert program.broadcasts == []

    # PUT with shape kwargs
    params = [%{slug: squeaky_door.slug, direction: "east", range: 2, shape: "line", include_origin: false}]
    %Runner{program: program, state: updated_state} = Command.put(runner_state, params)
    map_tile_1_3 = Instances.get_map_tile(updated_state, %{row: 1, col: 3})
    map_tile_1_4 = Instances.get_map_tile(updated_state, %{row: 1, col: 4})
    assert map_tile_1_3.character == "!"
    assert map_tile_1_4.character == "!"
    assert program.broadcasts == []
    assert Map.has_key? updated_state.rerender_coords, %{row: 1, col: 3}
    assert Map.has_key? updated_state.rerender_coords, %{row: 1, col: 4}
    assert updated_state.new_ids == %{"new_0" => 0, "new_1" => 0}
    assert updated_state.map_by_ids["new_0"]
    assert updated_state.map_by_ids["new_1"]

    params = [%{slug: squeaky_door.slug, direction: "east", range: 2, shape: "cone", include_origin: false}]
    %Runner{program: program, state: updated_state} = Command.put(runner_state, params)
    assert [] = program.broadcasts
    assert updated_state.rerender_coords != %{}

    params = [%{slug: squeaky_door.slug, range: 2, shape: "circle"}]
    %Runner{program: program, state: _updated_state} = Command.put(runner_state, params)
    assert [] = program.broadcasts
    assert updated_state.rerender_coords != %{}

    params = [%{slug: squeaky_door.slug, range: 2, shape: "blob"}]
    %Runner{program: program, state: _updated_state} = Command.put(runner_state, params)
    assert [] = program.broadcasts
    assert updated_state.rerender_coords != %{}

    # PUT with bad shape does nothing
    params = [%{slug: squeaky_door.slug, direction: "east", range: 2, shape: "banana", include_origin: false}]
    updated_runner_state = Command.put(runner_state, params)
    assert updated_runner_state == %{ runner_state |
             state: %{ runner_state.state | tile_template_slug_cache: updated_runner_state.state.tile_template_slug_cache }}

    state = %{ runner_state.state  | tile_template_slug_cache: updated_runner_state.state.tile_template_slug_cache }
    runner_state = %{ runner_state | state: state }

    # PUT with varialbes that resolve to invalid values does nothing
    params = [%{slug: squeaky_door.slug, color: {:state_variable, :character}, direction: "south"}]
    updated_runner_state = Command.put(runner_state, params)
    assert updated_runner_state == runner_state

    # PUT a nonexistant slug does nothing
    params = [%{slug: "notreal"}]

    %Runner{state: updated_state} = Command.put(runner_state, params)
    assert updated_state == state

    # PUT in a direction that goes off the map does nothing
    params = [%{slug: squeaky_door.slug, direction: "north"}]

    %Runner{state: updated_state} = Command.put(runner_state, params)
    assert updated_state == state
  end

  test "PUT using coordinates" do
    instance = insert_stubbed_dungeon_instance(%{},
      [%MapTile{character: ".", row: 1, col: 2, z_index: 0}])

    # Quik and dirty state init
    state = Repo.preload(instance, :dungeon_map_tiles).dungeon_map_tiles
            |> Enum.reduce(%Instances{}, fn(dmt, state) ->
                 {_, state} = Instances.create_map_tile(state, dmt)
                 state
               end)
    state = Map.put(state, :state_values, %{rows: 20, cols: 20})

    map_tile = Instances.get_map_tile(state, %{row: 1, col: 2})

    program = program_fixture()
    squeaky_door = insert_tile_template(%{character: "!", script: "#END\n:TOUCH\nSQUEEEEEEEEEK", state: "blocking: true", active: true})
    params = [%{slug: squeaky_door.slug, character: "?", row: 4, col: 2}]

    %Runner{program: program, state: updated_state} = Command.put(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    new_map_tile = Instances.get_map_tile(updated_state, %{row: 4, col: 2})
    assert program.broadcasts == []
    assert Map.has_key? updated_state.rerender_coords, %{row: 4, col: 2}
    assert %{blocking: true} = new_map_tile.parsed_state
    assert new_map_tile.character == "?"

    # PUT in a direction with coords
    params = [%{slug: squeaky_door.slug, direction: "north", row: 4, col: 2}]

    %Runner{state: updated_state} = Command.put(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    new_map_tile = Instances.get_map_tile(updated_state, %{row: 3, col: 2})
    assert new_map_tile.character == "!"

    # PUT at invalid coords does nothing
    params = [%{slug: squeaky_door.slug, row: 33, col: 33}]

    %Runner{state: updated_state} = Command.put(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    assert updated_state == %{ state | tile_template_slug_cache: updated_state.tile_template_slug_cache }
  end

  test "RANDOM" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: ".", state: ""})

    # range
    %Runner{state: updated_state} = Command.random(%Runner{object_id: map_tile.id, state: state}, ["cookies", "5 - 10"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert Enum.member?(5..10, updated_map_tile.parsed_state[:cookies])

    # list of values
    %Runner{state: updated_state} = Command.random(%Runner{object_id: map_tile.id, state: state}, ["answer", "yes", "no"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert Enum.member?(["yes", "no"], updated_map_tile.parsed_state[:answer])

    # bad range acts like a value
    %Runner{state: updated_state} = Command.random(%Runner{object_id: map_tile.id, state: state}, ["flaw", " - 5"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert Enum.member?(["- 5"], updated_map_tile.parsed_state[:flaw])
  end

  test "REPLACE tile in a direction" do
    # Replace uses BECOME, so mainly just verify that the right tiles are getting replaced
    state = %Instances{}
    {tile_123, state}  = Instances.create_map_tile(state, %MapTile{id: 123,  character: ".", row: 1, col: 2, z_index: 0, script: "#END", map_instance_id: 1})
    {_tile_255, state} = Instances.create_map_tile(state, %MapTile{id: 255,  character: ".", row: 1, col: 2, z_index: 1, script: "#END", map_instance_id: 1})
    {_tile_999, state} = Instances.create_map_tile(state, %MapTile{id: 999,  character: "c", row: 3, col: 2, z_index: 0, map_instance_id: 1})
    {obj, state} = Instances.create_map_tile(state, %MapTile{id: 1337, character: "c", row: 2, col: 2, z_index: 0, state: "facing: north", map_instance_id: 1, script: "#end"})

    state = %{ state | rerender_coords: %{} }

    tile_program = %Program{ pc: 3 }
    runner_state = %Runner{state: state, object_id: obj.id, program: tile_program}

    %Runner{state: updated_state, program: program} = Command.replace(runner_state, [%{target: "north", target_color: "red", color: "beige", target_foo: "a"}])
    assert updated_state == state
    assert program.broadcasts == []
    assert program.pc == tile_program.pc

    %Runner{state: updated_state, program: program} = Command.replace(runner_state, [%{target: "north", color: "beige"}])
    assert Instances.get_map_tile_by_id(updated_state, %{id: 255}).color == "beige"
    assert Instances.get_map_tile_by_id(updated_state, %{id: 123}).color == tile_123.color
    assert program.broadcasts == []
    assert Map.has_key? updated_state.rerender_coords, %{row: 1, col: 2}

    %Runner{state: updated_state, program: program} = Command.replace(runner_state, [%{target: "south", color: "beige"}])
    assert Instances.get_map_tile_by_id(updated_state, %{id: 999}).color == "beige"
    assert program.broadcasts == []
    assert Map.has_key? updated_state.rerender_coords, %{row: 3, col: 2}

    # Also works if the direction is in a state variable
    %Runner{state: updated_state, program: program} = Command.replace(runner_state, [%{target: {:state_variable, :facing}, color: "beige"}])
    assert Instances.get_map_tile_by_id(updated_state, %{id: 255}).color == "beige"
    refute Instances.get_map_tile_by_id(updated_state, %{id: 123}).color == "beige"
    assert program.broadcasts == []
    assert Map.has_key? updated_state.rerender_coords, %{row: 1, col: 2}


    # Doesnt break if nonexistant state var
    %Runner{state: updated_state, program: program} = Command.replace(runner_state, [%{target: {:state_variable, :fake}, color: "beige"}])
    assert updated_state == state
    assert program.broadcasts == []
    assert updated_state.rerender_coords == %{}
  end

  test "REPLACE tiles by name" do
    # Replace uses BECOME, so mainly just verify that the right tiles are getting replaced
    squeaky_door = insert_tile_template(%{character: "!", script: "#END\n:TOUCH\nSQUEEEEEEEEEK", state: "blocking: true", active: true, color: "red"})

    state = %Instances{}
    {tile_123, state} = Instances.create_player_map_tile(state, %MapTile{id: 123,  name: "A", character: ".", row: 1, col: 2, z_index: 0, script: "#END", map_instance_id: 1}, %Location{})
    {tile_255, state} = Instances.create_map_tile(state, %MapTile{id: 255,  name: "A", character: ".", row: 1, col: 2, z_index: 1, script: "#END", map_instance_id: 1})
    {tile_999, state} = Instances.create_map_tile(state, %MapTile{id: 999,  name: "C", character: "c", row: 3, col: 2, z_index: 0, script: "#END", map_instance_id: 1})
    {obj, state} = Instances.create_map_tile(state, %MapTile{id: 1337, name: nil, character: "c", row: 2, col: 2, z_index: 0, map_instance_id: 1})

    state = %{ state | rerender_coords: %{} }

    tile_program = %Program{ pc: 3 }
    runner_state = %Runner{state: state, object_id: obj.id, program: tile_program}

    # must match all target kwargs
    %Runner{state: updated_state, program: program} = Command.replace(runner_state, [%{target: "a", target_color: "puce", slug: squeaky_door.slug}])
    assert Instances.get_map_tile_by_id(updated_state, %{id: 255}) == tile_255
    assert Instances.get_map_tile_by_id(updated_state, %{id: 123}) == tile_123
    assert Instances.get_map_tile_by_id(updated_state, %{id: 999}) == tile_999
    assert program.broadcasts == []
    assert program.pc == tile_program.pc

    %Runner{state: updated_state, program: program} = Command.replace(runner_state, [%{target: "a", slug: squeaky_door.slug}])
    assert Instances.get_map_tile_by_id(updated_state, %{id: 255}).character == squeaky_door.character
    assert Instances.get_map_tile_by_id(updated_state, %{id: 123}) == tile_123
    assert Instances.get_map_tile_by_id(updated_state, %{id: 999}) == tile_999
    assert program.broadcasts == []
    assert Map.has_key? updated_state.rerender_coords, %{row: 1, col: 2}
    assert program.pc == tile_program.pc

    %Runner{state: updated_state, program: program} = Command.replace(runner_state, [%{target: "C", slug: squeaky_door.slug}])
    assert Instances.get_map_tile_by_id(updated_state, %{id: 999}).character == squeaky_door.character
    assert Instances.get_map_tile_by_id(updated_state, %{id: 255}) == tile_255
    assert Instances.get_map_tile_by_id(updated_state, %{id: 123}) == tile_123
    assert program.broadcasts == []
    assert Map.has_key? updated_state.rerender_coords, %{row: 3, col: 2}
    assert program.pc == tile_program.pc

    %Runner{state: updated_state, program: program} = Command.replace(runner_state, [%{target: "noname", slug: squeaky_door.slug}])
    assert program.broadcasts == []
    assert updated_state.rerender_coords == %{}
  end

  test "REPLACE with only target_ kwargs" do
    # Replace uses BECOME, so mainly just verify that the right tiles are getting replaced
    squeaky_door = insert_tile_template(%{character: "!", script: "#END\n:TOUCH\nSQUEEEEEEEEEK", state: "blocking: true", active: true, color: "red"})

    state = %Instances{}
    {tile_123, state} = Instances.create_player_map_tile(state, %MapTile{id: 123,  character: ".", row: 1, col: 2, z_index: 0, script: "#END", map_instance_id: 1}, %Location{})
    {_tile_255, state} = Instances.create_map_tile(state, %MapTile{id: 255, character: ".", row: 1, col: 2, z_index: 1, color: "red", state: "me: true", script: "#END", map_instance_id: 1})
    {tile_999, state} = Instances.create_map_tile(state, %MapTile{id: 999, character: "c", row: 3, col: 2, z_index: 0, script: "#END", map_instance_id: 1})
    {obj, state} = Instances.create_map_tile(state, %MapTile{id: 1337, name: nil, character: "c", row: 2, col: 2, z_index: 0, map_instance_id: 1})

    # must match all target kwargs
    %Runner{state: updated_state} = Command.replace(%Runner{state: state, object_id: obj.id}, [%{target_me: true, target_color: "red", slug: squeaky_door.slug}])
    assert Instances.get_map_tile_by_id(updated_state, %{id: 255}).character == squeaky_door.character
    assert Instances.get_map_tile_by_id(updated_state, %{id: 123}) == tile_123
    assert Instances.get_map_tile_by_id(updated_state, %{id: 999}) == tile_999
    assert updated_state.program_messages == []
  end

  test "REMOVE tile in a direction" do
    state = %Instances{}
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 123,  character: ".", row: 1, col: 2, z_index: 0, script: "#END"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 255,  character: ".", row: 1, col: 2, z_index: 1, script: "#END"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 999,  character: "c", row: 3, col: 2, z_index: 0})
    {obj, state} = Instances.create_map_tile(state, %MapTile{id: 1337, character: "c", row: 2, col: 2, z_index: 0, state: "facing: north"})

    state = %{ state | rerender_coords: %{} }

    runner_state = %Runner{state: state, object_id: obj.id}

    %Runner{state: updated_state, program: program} = Command.remove(runner_state, [%{target: "north"}])
    refute Instances.get_map_tile_by_id(updated_state, %{id: 255})
    assert Instances.get_map_tile_by_id(updated_state, %{id: 123})
    assert program.broadcasts == []
    assert Map.has_key? updated_state.rerender_coords, %{row: 1, col: 2}

    %Runner{state: updated_state, program: program} = Command.remove(runner_state, [%{target: "south"}])
    refute Instances.get_map_tile_by_id(updated_state, %{id: 999})
    assert program.broadcasts == []
    assert Map.has_key? updated_state.rerender_coords, %{row: 3, col: 2}

    # Also works if the direction is in a state variable
    %Runner{state: updated_state, program: program} = Command.remove(runner_state, [%{target: {:state_variable, :facing}}])
    refute Instances.get_map_tile_by_id(updated_state, %{id: 255})
    assert Instances.get_map_tile_by_id(updated_state, %{id: 123})
    assert program.broadcasts == []
    assert Map.has_key? updated_state.rerender_coords, %{row: 1, col: 2}

    # Doesnt break if nonexistant state var
    %Runner{state: updated_state, program: program} = Command.remove(runner_state, [%{target: {:state_variable, :fake}}])
    assert updated_state == state
    assert program.broadcasts == []
    assert updated_state.rerender_coords == %{}
  end

  test "REMOVE tiles by name" do
    state = %Instances{}
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 123,  name: "A", character: ".", row: 1, col: 2, z_index: 0, script: "#END"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 255,  name: "A", character: ".", row: 1, col: 2, z_index: 1, script: "#END"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 999,  name: "C", character: "c", row: 3, col: 2, z_index: 0, script: "#END"})
    {obj, state} = Instances.create_map_tile(state, %MapTile{id: 1337, name: nil, character: "c", row: 2, col: 2, z_index: 0})

    %Runner{state: updated_state} = Command.remove(%Runner{state: state, object_id: obj.id}, [%{target: "a", target_color: "red"}])
    assert Instances.get_map_tile_by_id(updated_state, %{id: 255})
    assert Instances.get_map_tile_by_id(updated_state, %{id: 123})

    %Runner{state: updated_state} = Command.remove(%Runner{state: state, object_id: obj.id}, [%{target: "a"}])
    refute Instances.get_map_tile_by_id(updated_state, %{id: 255})
    refute Instances.get_map_tile_by_id(updated_state, %{id: 123})

    %Runner{state: updated_state} = Command.remove(%Runner{state: state, object_id: obj.id}, [%{target: "C"}])
    refute Instances.get_map_tile_by_id(updated_state, %{id: 999})

    %Runner{state: updated_state} = Command.remove(%Runner{state: state, object_id: obj.id}, [%{target: "noname"}])
    assert updated_state.program_messages == []
  end

  test "REMOVE tiles with only other target KWARGS" do
    state = %Instances{}
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 123,  character: ".", row: 1, col: 2, z_index: 0, color: "red"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 255,  character: ".", row: 1, col: 2, z_index: 1, state: "moo: cow"})
    {_, state}   = Instances.create_player_map_tile(state, %MapTile{id: 999,  character: "c", row: 3, col: 2, z_index: 0, color: "red"}, %Location{})
    {obj, state} = Instances.create_map_tile(state, %MapTile{id: 1337, character: "c", row: 2, col: 2, z_index: 0})

    runner_state = %Runner{state: state, object_id: obj.id}

    %Runner{state: updated_state} = Command.remove(runner_state, [%{target_moo: "blu", target_color: "red"}])
    assert Instances.get_map_tile_by_id(updated_state, %{id: 255})
    assert Instances.get_map_tile_by_id(updated_state, %{id: 123})

    %Runner{state: updated_state} = Command.remove(runner_state, [%{target_color: "red"}])
    assert Instances.get_map_tile_by_id(updated_state, %{id: 999})
    refute Instances.get_map_tile_by_id(updated_state, %{id: 123})
  end

  test "RESTORE" do
    program = %Program{ labels: %{"thud" => [[1, false], [5, false], [9, true]]} }

    runner_state = Command.restore(%Runner{program: program}, ["thud"])
    assert %{"thud" => [[1,false], [5,true], [9,true]]} == runner_state.program.labels

    runner_state = Command.restore(%{ runner_state | program: runner_state.program}, ["thud"])
    assert %{"thud" => [[1,true], [5,true], [9,true]]} == runner_state.program.labels

    assert runner_state == Command.restore(runner_state, ["thud"])
    assert runner_state == Command.restore(runner_state, ["derp"])
  end

  test "SEND message to self" do
    program = program_fixture()
    stubbed_object = Map.put(%MapTile{id: 1337}, :parsed_state, %{})
    state = %Instances{map_by_ids: %{1337 => stubbed_object}}
    stubbed_id = %{map_tile_id: stubbed_object.id, parsed_state: stubbed_object.parsed_state}

    %Runner{state: state} = Command.send_message(%Runner{program: program, object_id: stubbed_object.id, state: state}, ["touch"])
    assert state.program_messages == [{1337, "touch", stubbed_id}]

    # program_messages has more recent messages at the front of the list
    %Runner{state: state} = Command.send_message(%Runner{program: program, object_id: stubbed_object.id, state: state}, ["tap", "self"])
    assert state.program_messages == [{1337, "tap", stubbed_id}, {1337, "touch", stubbed_id}]
  end

  test "SEND message to event sender" do
    sender = %{map_tile_id: 9001}
    stubbed_object = Map.put(%MapTile{id: 1337, name: "test"}, :parsed_state, %{})
    state = %Instances{map_by_ids: %{1337 => stubbed_object}}
    stubbed_sender = %{map_tile_id: stubbed_object.id, parsed_state: stubbed_object.parsed_state, name: "test"}

    %Runner{state: state} = Command.send_message(%Runner{object_id: stubbed_object.id, event_sender: sender, state: state}, ["touch", [:event_sender]])
    assert state.program_messages == [{9001, "touch", stubbed_sender}]

    # program_messages has more recent messages at the front of the list
    %Runner{state: state} = Command.send_message(%Runner{state: state, object_id: stubbed_object.id, event_sender: sender}, ["tap", [:event_sender]])
    assert state.program_messages == [{9001, "tap", stubbed_sender}, {9001, "touch", stubbed_sender}]

    # also works when sender was a player
    player = %Location{map_tile_instance_id: 12345}
    stubbed_player_sender = %{map_tile_id: stubbed_object.id, parsed_state: stubbed_object.parsed_state, name: stubbed_object.name}
    %Runner{state: state} = Command.send_message(%Runner{state: state, object_id: stubbed_object.id, event_sender: player}, ["tap", [:event_sender]])
    assert state.program_messages == [{12345, "tap", stubbed_player_sender}, {9001, "tap", stubbed_sender}, {9001, "touch", stubbed_sender}]

    # doesnt break when event sender is junk
    state = %Instances{map_by_ids: %{1337 => stubbed_object}}
    %Runner{state: state} = Command.send_message(%Runner{state: state, object_id: stubbed_object.id, event_sender: nil}, ["tap", [:event_sender]])
    assert state.program_messages == []
  end

  test "SEND message to others" do
    program = program_fixture()
    stubbed_object = Map.put(%MapTile{id: 1337, name: "test"}, :parsed_state, %{})
    stubbed_sender = %{map_tile_id: stubbed_object.id, parsed_state: stubbed_object.parsed_state, name: "test"}
    state = %Instances{program_contexts: %{1337 => %Program{}, 55 => %Program{}, 1 => %Program{}, 9001 => %Program{}}, map_by_ids: %{1337 => stubbed_object}}

    %Runner{state: state} = Command.send_message(%Runner{state: state, program: program, object_id: stubbed_object.id}, ["tap", "others"])
    assert state.program_messages == [{9001, "tap", stubbed_sender}, {55, "tap", stubbed_sender}, {1, "tap", stubbed_sender}]
  end

  test "SEND message to all" do
    program = program_fixture()
    stubbed_object = Map.put(%MapTile{id: 1337, name: "test"}, :parsed_state, %{})
    stubbed_sender = %{map_tile_id: stubbed_object.id, parsed_state: stubbed_object.parsed_state, name: "test"}
    state = %Instances{program_contexts: %{1337 => %Program{}, 55 => %Program{}, 1 => %Program{}, 9001 => %Program{}}, map_by_ids: %{1337 => stubbed_object}}

    %Runner{state: state} = Command.send_message(%Runner{state: state, program: program, object_id: stubbed_object.id}, ["dance", "all"])
    assert state.program_messages == [{9001, "dance", stubbed_sender}, {1337, "dance", stubbed_sender}, {55, "dance", stubbed_sender}, {1, "dance", stubbed_sender}]
  end

  test "SEND message to tiles in a direction" do
    state = %Instances{}
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 123,  character: ".", row: 1, col: 2, z_index: 0, script: "#END"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 255,  character: ".", row: 1, col: 2, z_index: 1, script: "#END"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 999,  character: "c", row: 3, col: 2, z_index: 0, script: "#END"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 998,  character: ".", row: 2, col: 2, z_index: -1, script: ""})
    {obj, state} = Instances.create_map_tile(state, %MapTile{id: 1337, character: "c", row: 2, col: 2, z_index: 0, state: "facing: north"})
    sender = %{map_tile_id: obj.id, parsed_state: obj.parsed_state, name: nil}

    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object_id: obj.id}, ["touch", "north"])
    assert updated_state.program_messages == [{123, "touch", sender}, {255, "touch", sender}]

    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object_id: obj.id}, ["touch", "south"])
    assert updated_state.program_messages == [{999, "touch", sender}]

    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object_id: obj.id}, ["touch", "here"])
    assert updated_state.program_messages == [{998, "touch", sender}, {1337, "touch", sender}]

    # Also works if the direction is in a state variable
    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object_id: obj.id}, ["touch", {:state_variable, :facing}])
    assert updated_state.program_messages == [{123, "touch", sender}, {255, "touch", sender}]

    # Doesnt break if nonexistant state var
    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object_id: obj.id}, ["touch", {:state_variable, :fake}])
    assert updated_state.program_messages == []
  end

  test "SEND message to tiles by name" do
    state = %Instances{}
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 123,  name: "A", character: ".", row: 1, col: 2, z_index: 0, script: "#END"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 255,  name: "A", character: ".", row: 1, col: 2, z_index: 1, script: "#END"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 999,  name: "C", character: "c", row: 3, col: 2, z_index: 0, script: "#END"})
    {obj, state} = Instances.create_map_tile(state, %MapTile{id: 1337, name: nil, character: "c", row: 2, col: 2, z_index: 0})
    sender = %{map_tile_id: obj.id, parsed_state: %{}, name: nil}

    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object_id: obj.id}, ["name", "a"])
    assert updated_state.program_messages == [{255, "name", sender}, {123, "name", sender}]

    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object_id: obj.id}, ["name", "C"])
    assert updated_state.program_messages == [{999, "name", sender}]

    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object_id: obj.id}, ["name", "noname"])
    assert updated_state.program_messages == []
  end

  test "SEQUENCE" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: ".", state: ""})

    program = program_fixture("#sequence c, red, gold, blue")
    runner_state = %Runner{object_id: map_tile.id, state: state, program: program}

    %Runner{state: updated_state, program: updated_program} = Command.sequence(runner_state, ["c", "red", "gold", "blue"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.parsed_state[:c] == "red"
    assert %{ 1 => [:sequence, ["c", "gold", "blue", "red"]] } = updated_program.instructions
  end

  test "SHIFT" do
    state = %Instances{}
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 123,  character: ".", row: 1, col: 1, z_index: 0})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 601,  character: "o", row: 1, col: 1, z_index: 1, state: "blocking: true, pushable: true"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 124,  character: ".", row: 1, col: 2, z_index: 0})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 125,  character: "#", row: 1, col: 3, z_index: 0, state: "blocking: true"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 126,  character: ".", row: 2, col: 3, z_index: 0})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 602,  character: "o", row: 2, col: 3, z_index: 1, state: "blocking: true, pushable: true"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 127,  character: ".", row: 3, col: 1, z_index: 0})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 128,  character: ".", row: 3, col: 2, z_index: 0})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 603,  character: "o", row: 3, col: 2, z_index: 1, state: "blocking: true, pushable: true"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 129,  character: ".", row: 3, col: 3, z_index: 0})
    {obj, state} = Instances.create_map_tile(state, %MapTile{id: 1337, character: "/", row: 2, col: 2, z_index: 0})

    state = %{ state | rerender_coords: %{} }

    obj_123 = Instances.get_map_tile_by_id(state, %{id: 123})
    obj_124 = Instances.get_map_tile_by_id(state, %{id: 124})
    obj_125 = Instances.get_map_tile_by_id(state, %{id: 125})
    obj_126 = Instances.get_map_tile_by_id(state, %{id: 126})
    obj_127 = Instances.get_map_tile_by_id(state, %{id: 127})
    obj_128 = Instances.get_map_tile_by_id(state, %{id: 128})
    obj_129 = Instances.get_map_tile_by_id(state, %{id: 129})

    %Runner{state: updated_state, program: program} = Command.shift(%Runner{state: state, object_id: obj.id}, ["clockwise"])
    assert %{id: 601, row: 1, col: 2, z_index: 1} = Instances.get_map_tile_by_id(updated_state, %{id: 601})
    assert %{id: 602, row: 3, col: 3, z_index: 1} = Instances.get_map_tile_by_id(updated_state, %{id: 602})
    assert %{id: 603, row: 3, col: 1, z_index: 1} = Instances.get_map_tile_by_id(updated_state, %{id: 603})
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert Map.has_key? updated_state.rerender_coords, %{col: 1, row: 1}
    assert Map.has_key? updated_state.rerender_coords, %{col: 2, row: 1}
    assert Map.has_key? updated_state.rerender_coords, %{col: 3, row: 2}
    assert Map.has_key? updated_state.rerender_coords, %{col: 1, row: 3}
    assert Map.has_key? updated_state.rerender_coords, %{col: 2, row: 3}
    assert Map.has_key? updated_state.rerender_coords, %{col: 3, row: 3}

    assert obj_123 == Instances.get_map_tile_by_id(updated_state, %{id: 123})
    assert obj_124 == Instances.get_map_tile_by_id(updated_state, %{id: 124})
    assert obj_125 == Instances.get_map_tile_by_id(updated_state, %{id: 125})
    assert obj_126 == Instances.get_map_tile_by_id(updated_state, %{id: 126})
    assert obj_127 == Instances.get_map_tile_by_id(updated_state, %{id: 127})
    assert obj_128 == Instances.get_map_tile_by_id(updated_state, %{id: 128})
    assert obj_129 == Instances.get_map_tile_by_id(updated_state, %{id: 129})

    %Runner{state: updated_state, program: program} = Command.shift(%Runner{state: updated_state, object_id: obj.id}, ["clockwise"])
    assert %{id: 601, row: 1, col: 2, z_index: 1} = Instances.get_map_tile_by_id(updated_state, %{id: 601})
    assert %{id: 602, row: 3, col: 2, z_index: 1} = Instances.get_map_tile_by_id(updated_state, %{id: 602})
    assert %{id: 603, row: 3, col: 1, z_index: 1} = Instances.get_map_tile_by_id(updated_state, %{id: 603})
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert Map.has_key? updated_state.rerender_coords, %{col: 2, row: 3}
    assert Map.has_key? updated_state.rerender_coords, %{col: 3, row: 3}

    updated_state = %{ updated_state | rerender_coords: %{} }
    %Runner{state: updated_state, program: program} = Command.shift(%Runner{state: updated_state, object_id: obj.id}, ["clockwise"])
    assert %{id: 601, row: 1, col: 2, z_index: 1} = Instances.get_map_tile_by_id(updated_state, %{id: 601})
    assert %{id: 602, row: 3, col: 2, z_index: 1} = Instances.get_map_tile_by_id(updated_state, %{id: 602})
    assert %{id: 603, row: 3, col: 1, z_index: 1} = Instances.get_map_tile_by_id(updated_state, %{id: 603})
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: []
           } = program
    assert updated_state.rerender_coords == %{}

    %Runner{state: updated_state, program: program} = Command.shift(%Runner{state: updated_state, object_id: obj.id}, ["counterclockwise"])
    assert %{id: 601, row: 1, col: 1, z_index: 1} = Instances.get_map_tile_by_id(updated_state, %{id: 601})
    assert %{id: 602, row: 3, col: 3, z_index: 1} = Instances.get_map_tile_by_id(updated_state, %{id: 602})
    assert %{id: 603, row: 3, col: 2, z_index: 1} = Instances.get_map_tile_by_id(updated_state, %{id: 603})
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert Map.has_key? updated_state.rerender_coords, %{col: 1, row: 1}
    assert Map.has_key? updated_state.rerender_coords, %{col: 2, row: 1}
    assert Map.has_key? updated_state.rerender_coords, %{col: 1, row: 3}
    assert Map.has_key? updated_state.rerender_coords, %{col: 2, row: 3}
    assert Map.has_key? updated_state.rerender_coords, %{col: 3, row: 3}
  end

  test "SHOOT" do
    DungeonCrawl.TileTemplates.TileSeeder.BasicTiles.bullet_tile

    instance = insert_stubbed_dungeon_instance(%{},
      [%MapTile{character: ".", row: 1, col: 2, z_index: 0},
       %MapTile{character: ".", row: 2, col: 2, z_index: 0},
       %MapTile{character: "#", row: 3, col: 2, z_index: 0, state: "blocking: true"},
       %MapTile{character: "@", row: 2, col: 2, z_index: 1}])

    # Quik and dirty state init
    state = Repo.preload(instance, :dungeon_map_tiles).dungeon_map_tiles
            |> Enum.reduce(%Instances{}, fn(dmt, state) ->
                 {_, state} = Instances.create_map_tile(state, dmt)
                 state
               end)

    obj = Instances.get_map_tile(state, %{row: 2, col: 2})

    # shooting into an empty space spawns a bullet heading in that direction
    %Runner{state: updated_state} = Command.shoot(%Runner{state: state, object_id: obj.id}, ["north"])
    assert bullet = Instances.get_map_tile(updated_state, %{row: 2, col: 2})

    assert bullet.character == "◦"
    assert bullet.parsed_state[:facing] == "north"
    assert updated_state.program_contexts[bullet.id]
    assert updated_state.program_messages == []
    assert updated_state.new_pids == [bullet.id]
    assert updated_state.program_contexts[bullet.id].program.status == :alive

    # bad direction / idle also does not spawn a bullet or do anything
    %Runner{state: updated_state} = Command.shoot(%Runner{state: state, object_id: obj.id}, ["gibberish"])
    tile = Instances.get_map_tile(updated_state, %{row: 2, col: 2})

    assert tile.character == "@"
    assert updated_state == state

    # can use the state variable
#    obj = %{obj | parsed_state: %{facing: "north"}}
    {obj, state} = Instances.update_map_tile_state(updated_state, obj, %{facing: "north"})
    %Runner{state: updated_state} = Command.shoot(%Runner{state: state, object_id: obj.id}, [{:state_variable, :facing}])
    assert bullet = Instances.get_map_tile(updated_state, %{row: 2, col: 2})

    assert bullet.character == "◦"
  end

  test "TAKE" do
    script = """
             #END
             :toopoor
             /i
             You don't have enough
             """
    {losing_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: "E", row: 1, col: 1, z_index: 0, state: "health: 10, red: 1, cash: 2"})
    {taker, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", color: "red", row: 2, col: 1, z_index: 1, state: "damage: 3", script: script})

    program = program_fixture(script)

    runner_state = %Runner{object_id: taker.id, state: state, program: program}

    # Take a state variable but no matching map tile
    %Runner{state: updated_state} = Command.take(runner_state, ["gems", 1, 12354, "toopoor"])
    assert state == updated_state

    # take state var in direction
    %Runner{state: %{map_by_ids: map}} = Command.take(runner_state, ["health", {:state_variable, :damage}, "north"])
    assert map[losing_tile.id].parsed_state[:health] == 7

    # Take a state variable as the attrbiute
    %Runner{state: %{map_by_ids: map}} = Command.take(runner_state, [{:state_variable, :color}, 1, "north", "toopoor"])
    assert map[losing_tile.id].parsed_state[:red] == 0

    # take nothing when there's no map tile
    %Runner{state: updated_state} = Command.take(runner_state, ["health", {:state_variable, :damage}, "south"])
    assert updated_state == state

    # take nothing when the direction is invalid
    %Runner{state: updated_state} = Command.take(runner_state, ["health", {:state_variable, :damage}, "norf"])
    assert updated_state == state

    # take but not enough
    %Runner{state: updated_state} = Command.take(runner_state, ["cash", 3, "north"])
    assert updated_state == state

    # take but not enough health so tile dies
    %Runner{state: updated_state} = Command.take(runner_state, ["health", 20, "north"])
    refute updated_state.map_by_ids[losing_tile.id]
    assert updated_state.dirty_ids[losing_tile.id] == :deleted

    # take but not state entry
    %Runner{state: updated_state} = Command.take(runner_state, ["gems", 20, "north"])
    assert updated_state == state

    # take but not enough and label given, but no event sender
    %Runner{state: updated_state} = Command.take(runner_state, ["gems", 2, "north", "toopoor"])
    assert updated_state == state

    # take but not enough and label given
    runner_state_with_player = %{ runner_state |
                                    state: %{ runner_state.state |
                                                player_locations: %{losing_tile.id => %Location{map_tile_instance_id: losing_tile.id} }}}
    %Runner{state: updated_state, program: up} = Command.take(%{runner_state_with_player | event_sender: %Location{map_tile_instance_id: losing_tile.id}},
                                                 ["gems", 2, "north", "toopoor"])
    assert up == %{ runner_state.program | pc: 2, status: :wait, wait_cycles: 1 }
    assert [] = updated_state.program_messages

    # take state var to event sender (tile)
    %Runner{state: %{map_by_ids: map}} = Command.take(%{runner_state | event_sender: %{map_tile_id: losing_tile.id}},
                                                      ["health", 2, [:event_sender]])
    assert map[losing_tile.id].parsed_state[:health] == 8

    # take state var to event sender (player)
    %Runner{state: %{map_by_ids: map}} = Command.take(%{runner_state_with_player | event_sender: %Location{map_tile_instance_id: losing_tile.id}},
                                                      ["health", 1, [:event_sender]])
    assert map[losing_tile.id].parsed_state[:health] == 9

    # take handles null state variable
    %Runner{state: %{map_by_ids: map}} = Command.take(%{runner_state_with_player | event_sender: %Location{map_tile_instance_id: losing_tile.id}},
                                                      ["health", {:state_variable, :nonexistant}, [:event_sender]])
    assert map[losing_tile.id].parsed_state[:health] == 10

    # Does nothing when there is no event sender
    %Runner{state: updated_state} = Command.take(%{runner_state | event_sender: nil}, [:health, {:state_variable, :nonexistant}, [:event_sender]])
    assert updated_state == state
  end

  test "TARGET_PLAYER" do
    # setup
    state = %Instances{}
    {_, state} = Instances.create_player_map_tile(state,
                                                  %MapTile{id: 43201, row: 2, col: 2, z_index: 0, character: "A"},
                                                  %Location{})
    {_, state} = Instances.create_player_map_tile(state,
                                                  %MapTile{id: 43202, row: 3, col: 14, z_index: 0, character: "B"},
                                                  %Location{})
    {_, state} = Instances.create_player_map_tile(state,
                                                  %MapTile{id: 43203, row: 3, col: 3, z_index: 0, character: "C"},
                                                  %Location{})
    {object_1, state} = Instances.create_map_tile(state, %MapTile{id: 1, character: "X", row: 2, col: 3, z_index: 0, state: ""})
    {object_2, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: "Y", row: 5, col: 20, z_index: 0, state: ""})

    # nearest uses the nearest player tile
    runner_state = %Runner{object_id: object_1.id, state: state}
    %Runner{state: updated_state} = Command.target_player(runner_state, ["nearest"])
    object_tile = Instances.get_map_tile_by_id(updated_state, object_1)
    target_tile = Instances.get_map_tile_by_id(updated_state, %{id: object_tile.parsed_state[:target_player_map_tile_id]})
    assert Enum.member?(["A", "C"], target_tile.character)

    runner_state = %Runner{object_id: object_2.id, state: state}
    %Runner{state: updated_state} = Command.target_player(runner_state, ["nearest"])
    object_tile = Instances.get_map_tile_by_id(updated_state, object_2)
    target_tile = Instances.get_map_tile_by_id(updated_state, %{id: object_tile.parsed_state[:target_player_map_tile_id]})
    assert target_tile.character == "B"

    # random uses a random player tile
    runner_state = %Runner{object_id: object_2.id, state: state}
    %Runner{state: updated_state} = Command.target_player(runner_state, ["random"])
    object_tile = Instances.get_map_tile_by_id(updated_state, object_2)
    target_tile = Instances.get_map_tile_by_id(updated_state, %{id: object_tile.parsed_state[:target_player_map_tile_id]})
    assert Enum.member?(["A", "B", "C"], target_tile.character)

    # bad parameter does not cause a crash, even though the program validator should make this not possible
    # under normal conditions
    assert runner_state == Command.target_player(runner_state, ["qwerty"])
  end

  test "TERMINATE" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()

    %Runner{program: program, state: state} = Command.terminate(%Runner{program: program, object_id: map_tile.id, state: state})
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert updated_map_tile == Instances.get_map_tile(state, map_tile)
    assert program.status == :dead
    assert program.pc == -1
    assert updated_map_tile.script == ""
  end

  test "TEXT" do
    program = program_fixture("One line<script>")
    stubbed_object = %{id: 1, state: "thing: true"}
    state = %Instances{map_by_ids: %{1 => stubbed_object}}
    runner_state = %Runner{program: program, object_id: stubbed_object.id, state: state}

    # also html escapes the text
    %Runner{program: updated_program} = Command.text(runner_state, ["One line<script>"])
    assert updated_program.responses == [{"message", %{message: "One line&lt;script&gt;"}}]
    assert updated_program.status == program.status
    assert updated_program.pc == 1

    # text with label get a modal, even when only one line
    program = program_fixture("!label;One line\n#end\n:label")
    runner_state = %{ runner_state | program: program }
    %Runner{program: updated_program, state: updated_state} = Command.text(runner_state, ["One line", "label"])
    assert updated_program.responses ==
       [{"message",
        %{message: ["    <span class='btn-link messageLink' data-label='label' data-tile-id='1'>▶One line</span>"],
          modal: true}}]
    assert updated_state.message_actions == %{}

    # when event_sender is a player it adds the messages to the registry for that player
    runner_state = %{ runner_state | program: program }
    event_sender = %Location{map_tile_instance_id: 444}
    runner_state = %{ runner_state | program: program, event_sender: event_sender }
    %Runner{program: updated_program, state: updated_state} = Command.text(runner_state, ["One line", "label"])
    assert updated_program.responses ==
       [{"message",
        %{message: ["    <span class='btn-link messageLink' data-label='label' data-tile-id='1'>▶One line</span>"],
          modal: true}}]
    assert updated_state.message_actions == %{444 => ["label"]}

    # multiline
    program = program_fixture("""
                              One line
                              !label;Yes
                              !no;NO!!!!
                              #END
                              :label
                              well, ok
                              :no
                              """)
    runner_state = %{ runner_state | program: program }
    %Runner{program: updated_program, state: updated_state} = Command.text(runner_state, ["ignord"])
    assert updated_program.responses ==
       [{"message",
        %{message: ["One line",
                    "    <span class='btn-link messageLink' data-label='label' data-tile-id='1'>▶Yes</span>",
                    "    <span class='btn-link messageLink' data-label='no' data-tile-id='1'>▶NO!!!!</span>"],
          modal: true}}]
    assert updated_program.status == program.status
    assert updated_program.pc == 3
    assert updated_state.message_actions == %{444 => ["no", "label"]}
  end

  test "TEXT with interpolation" do
    program = program_fixture("${ true } My id is: ${ @id } here is junk ${ 12.4 } ${ boring text } ${ @@flag }")

    stubbed_object = %{id: 2, state: "thing: true"}
    state = %Instances{map_by_ids: %{1 => stubbed_object}, state_values: %{flag: "OK"}}
    runner_state = %Runner{program: program, object_id: stubbed_object.id, state: state}

    # also html escapes the text
    %Runner{program: updated_program} = Command.text(runner_state, [["ignored"]])
    assert updated_program.responses == [{"message", %{message: "true My id is: 2 here is junk 12.4 boring text OK"}}]
    assert updated_program.status == program.status
    assert updated_program.pc == 1
  end

  test "TRANSPORT" do
    # it calls Travel.passage, so a lot of testing will be redundant. What will be useful is testing the various params do what they should
    defmodule TravelMock1 do
      def passage(%Location{} = player_location, passage, level_number, state) do
        player_map_tile = Instances.get_map_tile_by_id(state, %{id: player_location.map_tile_instance_id})
        assert %{match_key: nil} == passage
        assert level_number == 4
        {_, state} = Instances.delete_map_tile(state, player_map_tile, false)
        {:ok, state}
      end
    end
    defmodule TravelMock2 do
      def passage(%Location{} = player_location, passage, level_number, state) do
        player_map_tile = Instances.get_map_tile_by_id(state, %{id: player_location.map_tile_instance_id})
        assert %{row: 1, col: 1, match_key: "red"} = passage
        assert level_number == 2
        {_, state} = Instances.delete_map_tile(state, player_map_tile, false)
        {:ok, state}
      end
    end

    {floor, state} = Instances.create_map_tile(%Instances{number: 3}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {fake_player, state} = Instances.create_player_map_tile(state,
                                                            %MapTile{id: 43201, row: 2, col: 2, z_index: 0, character: "@"},
                                                            %Location{map_tile_instance_id: 43201})

    # paths that are ok; "up"
    assert %Runner{state: updated_state} = Command.transport(%Runner{state: state}, [fake_player, "up"], TravelMock1)
    assert updated_state.player_locations == %{}
    # "down" with a match key
    assert %Runner{state: updated_state} = Command.transport(%Runner{object_id: floor.id, state: state, event_sender: %{map_tile_instance_id: fake_player.id}}, [[:event_sender], "down", "red"], TravelMock2)
    assert updated_state.player_locations == %{}
    # hard coded level number
    assert %Runner{state: updated_state} = Command.transport(%Runner{state: state}, [fake_player, 4], TravelMock1)
    assert updated_state.player_locations == %{}
    # not an actual player, so the tile is not moved and nothing happens
    assert %Runner{state: updated_state} = Command.transport(%Runner{object_id: floor.id, state: state}, [floor, {:state_variable, :id}], TravelMock1)
    refute updated_state.player_locations == %{}
    assert updated_state == state
    # not an actual player, so the tile is not moved and nothing happens
    assert %Runner{state: updated_state} = Command.transport(%Runner{state: state}, [[:event_sender], {:state_variable, :id}], TravelMock1)
    refute updated_state.player_locations == %{}
    assert updated_state == state
  end

  test "TRY" do
    # Basically Move with false
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    assert Command.try(%Runner{object_id: mover.id, state: state}, ["left"]) == Command.move(%Runner{object_id: mover.id, state: state}, ["left", false])

    # Unsuccessful
    assert Command.try(%Runner{object_id: mover.id, state: state}, ["down"]) == Command.move(%Runner{object_id: mover.id, state: state}, ["down", false])
  end

  test "UNLOCK" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()

    %Runner{state: state} = Command.unlock(%Runner{program: program, object_id: map_tile.id, state: state}, [])
    map_tile = Instances.get_map_tile(state, map_tile)
    assert map_tile.state == "locked: false"
    assert map_tile.parsed_state == %{locked: false}
  end

  test "WALK" do
    # Basically Move with until it cannot move
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    expected_runner_state = Command.move(%Runner{object_id: mover.id, state: state}, ["left", false])
    expected_runner_state = %Runner{ expected_runner_state | program: %{ expected_runner_state.program | pc: 0 } }

    assert Command.walk(%Runner{state: state, object_id: mover.id}, ["left"]) == expected_runner_state

    # Unsuccessful
    assert Command.walk(%Runner{state: state, object_id: mover.id}, ["down"]) == Command.move(%Runner{object_id: mover.id, state: state}, ["down", false])
  end

  test "WALK with a continue and facing" do
    # Basically Move with until it cannot move
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1, state: "facing: west"})

    expected_runner_state = Command.move(%Runner{object_id: mover.id, state: state}, ["west", false])
    expected_runner_state = %Runner{ expected_runner_state | program: %{ expected_runner_state.program | pc: 0 } }

    assert Command.walk(%Runner{object_id: mover.id, state: state}, ["continue"]) == expected_runner_state
  end

  test "ZAP" do
    program = %Program{ labels: %{"thud" => [[1, true], [5, true]]} }

    runner_state = Command.zap(%Runner{program: program}, ["thud"])
    assert %{"thud" => [[1,false],[5,true]]} == runner_state.program.labels

    runner_state = Command.zap(%{ runner_state | program: runner_state.program}, ["thud"])
    assert %{"thud" => [[1,false],[5,false]]} == runner_state.program.labels

    assert runner_state == Command.zap(runner_state, ["thud"])
    assert runner_state == Command.zap(runner_state, ["derp"])
  end
end
