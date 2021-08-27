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
        "w/ move dark 10 lights" => fn -> Lighting.MoveRerender.moves(%{dark_state_10_light | rerender_coords: %{}}, player_tile, moves) end,
        "w/ 100 move full visibility" => fn -> Lighting.MoveRerender.moves(%{initial_state| rerender_coords: %{}}, player_tile, 100) end,
        "w/ 100 move foggy" => fn -> Lighting.MoveRerender.moves(%{fog_state| rerender_coords: %{}}, player_tile, 100) end,
        "w/ 100 move dark 1 light" => fn -> Lighting.MoveRerender.moves(%{dark_state_1_light | rerender_coords: %{}}, player_tile, 100) end,
        "w/ 100 move dark 2 lights" => fn -> Lighting.MoveRerender.moves(%{dark_state_2_light | rerender_coords: %{}}, player_tile, 100) end,
        "w/ 100 move dark 10 lights" => fn -> Lighting.MoveRerender.moves(%{dark_state_10_light | rerender_coords: %{}}, player_tile, 100) end
      },
      time: 10,
      print: [fast_warning: false]
    )
  end
end

Lighting.Benchmark.benchmark()
