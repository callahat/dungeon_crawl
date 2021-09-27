defmodule Lighting.MoveRerender do
  alias DungeonCrawl.Action.Move
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.DungeonProcesses.Render

  @directions ["north", "south", "east", "west"]

  def moves(state, _player_tile, 0), do: state

  def moves(state, player_tile, steps) do
    target = Levels.get_tile(state, player_tile, Enum.random(@directions))
    state = case Move.go(player_tile, target, state) do
              {_, state} -> state
              _ -> state
            end
    Render.rerender_tiles(state)
    moves(%{state | rerender_coords: %{}}, player_tile, steps - 1)
  end
end

defmodule Lighting.Benchmark do
  alias DungeonCrawl.DungeonGeneration.MapGenerators.TestRooms
  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.DungeonProcesses.Render

  def benchmark do
    basic_mapping = %{?' => %{state: "blocking: false"},
                      ?+ => %{state: "blocking: true"},
                      ?# => %{state: "blocking: true"},
                      ?\s => %{state: "blocking: true"},
                      ?♂ => %{state: "blocking: true"},
                      ?. => %{state: "blocking: false"},
                      ?? => %{state: "blocking: true"}}

    tiles =
    TestRooms.generate("ignored", "ignored")
    |> Enum.to_list
    |> Enum.reduce([], fn({{row,col}, tile}, tiles) ->
          [ %Tile{id: row * 1000 + col, row: row, col: col, character: "#{[tile]}", state: basic_mapping[tile].state}
            | tiles ]
       end)
    initial_state = %Levels{instance_id: 1, state_values: %{rows: 20, cols: 20}}
    initial_state = Enum.reduce(tiles, initial_state, fn(tile, state) ->
                      {_, state} = Levels.create_tile(state, tile)
                      state
                    end)

    floor_tiles = Enum.reject(tiles, fn tile -> tile.character != "." end)

    player_tile = Enum.random(floor_tiles) # it isn't really, but we'll pretend it is for sake of a test
    {player_tile, initial_state} = Levels.create_tile(initial_state, %{player_tile | z_index: 1, id: 9_000_000})
    player_location = %Location{id: 9_000_000, tile_instance_id: player_tile.id}

    {_, initial_state} = Levels.create_player_tile(initial_state, player_tile, player_location)

    other_player_count = 10

    other_players = Enum.shuffle(floor_tiles)
                    |> Enum.take(other_player_count)

    initial_state = Enum.reduce(other_players, initial_state, fn other_player_tile, state ->
        tile_id = 9_000_001 + Enum.find_index(other_players, fn i -> i == other_player_tile end)
        {other_player_tile, state} = Levels.create_tile(state, %{other_player_tile | z_index: 1, id: tile_id})
        player_location = %Location{id: tile_id, tile_instance_id: other_player_tile.id}
        {_, state} = Levels.create_player_tile(state, other_player_tile, player_location)
        state
      end)

    fog_state = %{ initial_state | state_values: Map.put(initial_state.state_values, :visibility, "fog")}

    {_, dark_state_1_light} = %{ initial_state | state_values: Map.put(initial_state.state_values, :visibility, "dark")}
                              |> Levels.update_tile_state(player_tile, %{light_source: true})
    {_, dark_state_2_light} = Levels.update_tile_state(dark_state_1_light, Enum.random(floor_tiles), %{light_source: true})

    dark_state_10_light = Enum.shuffle(floor_tiles)
                          |> Enum.take(8)
                          |> Enum.reduce(dark_state_2_light, fn floor, state ->
                               {_, state} = Levels.update_tile_state(state, floor, %{light_source: true})
                               state
                             end)

    moves = 1

    Benchee.run(
      %{
        "full visibility" => fn -> Render.rerender_tiles(initial_state) end,
        "foggy" => fn -> Render.rerender_tiles(fog_state) end,
        "dark 1 light" => fn -> Render.rerender_tiles(dark_state_1_light) end,
        "dark 2 lights" => fn -> Render.rerender_tiles(dark_state_2_light) end,
        "dark 10 lights" => fn -> Render.rerender_tiles(dark_state_10_light) end,
        "w/ move full visibility" => fn -> Lighting.MoveRerender.moves(%{initial_state| rerender_coords: %{}}, player_tile, moves) end,
        "w/ move foggy" => fn -> Lighting.MoveRerender.moves(%{fog_state| rerender_coords: %{}}, player_tile, moves) end,
        "w/ move dark 1 light" => fn -> Lighting.MoveRerender.moves(%{dark_state_1_light | rerender_coords: %{}}, player_tile, moves) end,
        "w/ move dark 2 lights" => fn -> Lighting.MoveRerender.moves(%{dark_state_2_light | rerender_coords: %{}}, player_tile, moves) end,
        "w/ move dark 10 lights" => fn -> Lighting.MoveRerender.moves(%{dark_state_10_light | rerender_coords: %{}}, player_tile, moves) end
      },
      time: 10,
      print: [fast_warning: false]
    )
  end
end

# The moves step once, which should be a minor change to rerender (instead of calculating everything)
#Name                              ips        average  deviation         median         99th %
#w/ move full visibility      16874.12      0.0593 ms    ±58.21%      0.0726 ms       0.118 ms
#w/ move foggy                 2465.76        0.41 ms    ±13.96%        0.40 ms        0.62 ms
#full visibility               1807.34        0.55 ms     ±7.90%        0.54 ms        0.71 ms
#foggy                         1650.43        0.61 ms     ±8.79%        0.59 ms        0.83 ms
#w/ move dark 1 light           519.94        1.92 ms    ±10.00%        1.86 ms        2.66 ms
#dark 1 light                   474.57        2.11 ms     ±9.54%        2.03 ms        2.88 ms
#w/ move dark 2 lights          380.64        2.63 ms     ±9.17%        2.54 ms        3.43 ms
#dark 2 lights                  361.27        2.77 ms     ±7.48%        2.70 ms        3.54 ms
#w/ move dark 10 lights         125.91        7.94 ms     ±5.01%        7.91 ms        9.09 ms
#dark 10 lights                 123.79        8.08 ms     ±4.81%        8.06 ms        9.23 ms
#
#Comparison:
#          w/ move full visibility      16874.12
#          w/ move foggy                 2465.76 - 6.84x slower +0.35 ms
#                                                    full visibility               1807.34 - 9.34x slower +0.49 ms
#                                                                                                         foggy                         1650.43 - 10.22x slower +0.55 ms
#                                                                                                                                                                     w/ move dark 1 light           519.94 - 32.45x slower +1.86 ms
#                                                                                                                                                                                                                              dark 1 light                   474.57 - 35.56x slower +2.05 ms
#w/ move dark 2 lights          380.64 - 44.33x slower +2.57 ms
#                                                            dark 2 lights                  361.27 - 46.71x slower +2.71 ms
#w/ move dark 10 lights         125.91 - 134.01x slower +7.88 ms
#dark 10 lights                 123.79 - 136.31x slower +8.02 ms

Lighting.Benchmark.benchmark()
