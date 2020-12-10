# To use, run via iex -S mix phx.server, in the browser start an instance, take that instance id and use it with the functions below

defmodule Test do
  alias DungeonCrawl.DungeonProcesses.{Instances, InstanceRegistry, InstanceProcess}

  def test_solo(instance_id, count) do
    # one at a time
    colors = ["red", "green", "blue", "purple"]
    characters = ["A", "B", "C"]

    tiles = for row <- 1..25, col <- 1..25, do: %{row: row, col: col, character: "X", color: "gray", background_color: nil}
     start = :os.system_time(:millisecond)
    _solo(instance_id, count, tiles, characters, colors)
    IO.puts "Took #{:os.system_time(:millisecond) - start} ms"
  end

  defp _solo(instance_id, 0, _, _, _), do: :done
  defp _solo(instance_id, count, tiles, characters, colors) do
    tiles
    |> Enum.each(fn tile ->
         tile = Map.merge(tile, %{color: Enum.at(colors, round(:math.fmod(count,4))), character: Enum.at(characters, round(:math.fmod(count,3)))})
         payload = %{tiles: [ Map.put(Map.take(tile, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(tile)) ]}

         DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{instance_id}", "tile_changes", payload)
       end)
    _solo(instance_id, count - 1, tiles, characters, colors)
  end

  def test_bundle(instance_id, count) do
    # one at a time
    colors = ["red", "green", "blue", "purple"]
    characters = ["A", "B", "C"]

    tiles = for row <- 1..25, col <- 1..25, do: %{row: row, col: col, character: "X", color: "gray", background_color: nil}
     start = :os.system_time(:millisecond)
    _bundle(instance_id, count, tiles, characters, colors)
    IO.puts "Took #{:os.system_time(:millisecond) - start} ms"
  end

  defp _bundle(instance_id, 0, _, _, _), do: :done
  defp _bundle(instance_id, count, tiles, characters, colors) do
    tile_changes = \
    tiles
    |> Enum.map(fn tile ->
         tile = Map.merge(tile, %{color: Enum.at(colors, round(:math.fmod(count,4))), character: Enum.at(characters, round(:math.fmod(count,3)))})
         Map.put(Map.take(tile, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(tile))
       end)
    payload = %{tiles: tile_changes}

    DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{instance_id}", "tile_changes", payload)

    _bundle(instance_id, count - 1, tiles, characters, colors)
  end

  def test_refresh(instance_id, count) do
    coords = for row <- 1..25, col <- 1..25, do: %{row: row, col: col}
     start = :os.system_time(:millisecond)
    _refresh(instance_id, count, coords)
    IO.puts "Took #{:os.system_time(:millisecond) - start} ms"
  end

  def _refresh(_, 0, _), do: :done
  def _refresh(instance_id, count, coords) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, instance_id)
    InstanceProcess.run_with(instance, fn (instance_state) ->
      # todo: make a render func for Instances
      tile_changes = \
      coords
      |> Enum.map(fn coord ->
           tile = Instances.get_map_tile(instance_state, coord)
           Map.put(Map.take(tile, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(tile))
         end)
      payload = %{tiles: tile_changes}

      DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{instance_id}", "tile_changes", payload)
      {:ok, instance_state}
    end)
    _refresh(instance_id, count - 1, coords)
  end
end
