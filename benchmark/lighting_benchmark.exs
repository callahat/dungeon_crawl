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

    moves = 100

    Benchee.run(
      %{
        "full visibility" => fn -> Render.rerender_tiles(initial_state) end,
        "foggy" => fn -> Render.rerender_tiles(fog_state) end,
        "dark 1 light" => fn -> Render.rerender_tiles(dark_state_1_light) end,
        "dark 2 lights" => fn -> Render.rerender_tiles(dark_state_2_light) end,
        "dark 10 lights" => fn -> Render.rerender_tiles(dark_state_10_light) end,
        "w/ move full visibility" => fn -> Lighting.MoveRerender.moves(initial_state, player_tile, moves) end,
        "w/ move foggy" => fn -> Lighting.MoveRerender.moves(fog_state, player_tile, moves) end,
        "w/ move dark 1 light" => fn -> Lighting.MoveRerender.moves(dark_state_1_light, player_tile, moves) end,
        "w/ move dark 2 lights" => fn -> Lighting.MoveRerender.moves(dark_state_2_light, player_tile, moves) end,
        "w/ move dark 10 lights" => fn -> Lighting.MoveRerender.moves(dark_state_10_light, player_tile, moves) end
      },
      time: 10,
      print: [fast_warning: false]
    )
  end
end

#Name                              ips        average  deviation         median         99th %
#full visibility               1781.99        0.56 ms    ±10.23%        0.55 ms        0.79 ms
#foggy                         1580.62        0.63 ms     ±9.23%        0.62 ms        0.86 ms
#dark 1 light                   509.16        1.96 ms     ±6.81%        1.93 ms        2.68 ms
#dark 2 lights                  405.70        2.46 ms     ±5.33%        2.43 ms        2.96 ms
#w/ move full visibility        152.75        6.55 ms     ±8.35%        6.49 ms        8.18 ms
#dark 10 lights                 140.77        7.10 ms     ±5.02%        7.05 ms        8.38 ms
#w/ move foggy                   23.46       42.63 ms     ±3.86%       42.89 ms       45.87 ms
#w/ move dark 1 light             5.29      189.18 ms     ±4.57%      189.37 ms      216.80 ms
#w/ move dark 2 lights            4.16      240.30 ms     ±5.55%      235.53 ms      283.95 ms
#w/ move dark 10 lights           1.41      707.37 ms     ±3.64%      693.42 ms      751.52 ms
#
#Comparison:
#          full visibility               1781.99
#          foggy                         1580.62 - 1.13x slower +0.0715 ms
#                                                                  dark 1 light                   509.16 - 3.50x slower +1.40 ms
#          dark 2 lights                  405.70 - 4.39x slower +1.90 ms
#                                                    w/ move full visibility        152.75 - 11.67x slower +5.99 ms
#                                                                                               dark 10 lights                 140.77 - 12.66x slower +6.54 ms
#                                                                                                                                              w/ move foggy                   23.46 - 75.97x slower +42.07 ms
#                                                                                                                                                                                                    w/ move dark 1 light             5.29 - 337.11x slower +188.62 ms
#                                                                                                                                                                                                                                                    w/ move dark 2 lights            4.16 - 428.21x slower +239.74 ms
#                                                                                                                                                                                                                                                                                                  w/ move dark 10 lights           1.41 - 1260.53x slower +706.81 ms

Lighting.Benchmark.benchmark()
