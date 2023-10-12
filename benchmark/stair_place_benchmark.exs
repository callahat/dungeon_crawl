defmodule StairPlaceBenchmark do
  alias DungeonCrawl.DungeonGeneration.MapGenerators.ConnectedRooms
  alias DungeonCrawl.DungeonGeneration.MapGenerators.Labrynth

  require Logger

  def measure(function) do
    function
    |> :timer.tc
    |> elem(0)
    |> Kernel./(1_000_000)
  end

  def guess_random_coords_vs_filter_a_random_space(iterations \\ 10_000) do
    logger_level = Logger.level
    Logger.configure level: :warning

    IO.puts "Generating maps:"
    start_ms = :os.system_time(:millisecond)
    map = ConnectedRooms.generate
    labrynth = Labrynth.generate
    IO.puts "Took #{(:os.system_time(:millisecond) - start_ms) / 1000.0} seconds"

    IO.puts DungeonCrawl.DungeonGeneration.MapGenerators.Utils.stringify map, 80

    IO.puts "Running experiements..."
    placing_by_random_guess = measure(fn() ->
        for _ <- 0..iterations, do: stairs_up_by_trying_random_coords_til_finding_a_space map, 40, 80
      end)
    IO.puts "Random Guess  #{iterations}         took (seconds): #{placing_by_random_guess}"

    placing_by_random_filtered_space = measure(fn() ->
        for _ <- 0..iterations, do: stairs_up_finding_random_space_via_filtering map
      end)
    IO.puts "Random Space  #{iterations}         took (seconds): #{placing_by_random_filtered_space}"

    labrynth_space = measure(fn() ->
        for _ <- 0..iterations, do: labrynth_random_space labrynth, 40, 80
      end)
    IO.puts "Labrynth Space  #{iterations}        took (seconds): #{labrynth_space}"

    labrynth_corner = measure(fn() ->
        for _ <- 0..iterations, do: labrynth_random_corner labrynth, 40, 80
      end)
    IO.puts "Labrynth Corner  #{iterations}       took (seconds): #{labrynth_corner}"

    Logger.configure level: logger_level
  end

  # results
  # Random Guess  10000         took (seconds): 0.021185
  # Random Space  10000         took (seconds): 1.953516
  #
  # Another run:
  # Random Guess  10000         took (seconds): 0.018641
  # Random Space  10000         took (seconds): 1.832377
  # Labrynth Space  10000        took (seconds): 0.017928
  # Labrynth Corner  10000       took (seconds): 0.034325

  def stairs_up_by_trying_random_coords_til_finding_a_space(map, cave_height, cave_width) do
    row = _rand_range(0, cave_height-1)
    col = _rand_range(0, cave_width-1)
    if map[{row, col}] == ?. do
      Map.put(map, {row, col}, ?▟)
    else
      stairs_up_by_trying_random_coords_til_finding_a_space(map, cave_height, cave_width)
    end
  end

  defp _rand_range(min, max), do: :rand.uniform(max - min + 1) + min - 1

  def stairs_up_finding_random_space_via_filtering(map) do
    {{row, col}, _} = map
                      |> Enum.filter(fn {coords, char} -> char == ?. end)
                      |> Enum.random

    Map.put(map, {row, col}, ?▟)
  end

  def labrynth_random_space(map, cave_height, cave_width) do
    row = :rand.uniform(cave_height) - 1
    col = :rand.uniform(cave_width) - 1

    if map[{row, col}] == ?. do
      Map.put(map, {row, col}, ?▟)
    else
      labrynth_random_space(map, cave_height, cave_width)
    end
  end

  def labrynth_random_corner(map, cave_height, cave_width) do
    row = :rand.uniform(cave_height) - 1
    col = :rand.uniform(cave_width) - 1

    if map[{row, col}] == ?. && _adjacent_walls(map, row, col) == 3 do
      Map.put(map, {row, col}, ?▟)
    else
      labrynth_random_space(map, cave_height, cave_width)
    end
  end

  defp _adjacent_walls(map, row, col) do
    [ map[{row+1, col}],
      map[{row-1, col}],
      map[{row, col+1}],
      map[{row, col-1}] ]
    |> Enum.filter(fn char -> char == ?# end)
    |> length
  end
end
