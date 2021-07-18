defmodule InstanceBenchmark do
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonInstances.{Map,MapTile}
  alias DungeonCrawl.DungeonGeneration.MapGenerators.TestRooms
  alias DungeonCrawl.TileState.Parser

  alias DungeonCrawl.DungeonProcesses.InstanceProcess

  require Logger

  def measure(function) do
    function
    |> :timer.tc
    |> elem(0)
    |> Kernel./(1_000_000)
  end

  def process_vs_db(iterations \\ 10_000) do
    logger_level = Logger.level
    Logger.configure level: :warn

    IO.puts "Generating instance in DB:"
    start_ms = :os.system_time(:millisecond)
    {:ok, dungeon} = Dungeon.generate_map TestRooms, %{name: "TestBench"}
    {:ok, %{dungeon: instance = %Map{}}} = DungeonInstances.create_map(dungeon.dungeon)
    IO.puts "Took #{(:os.system_time(:millisecond) - start_ms) / 1000.0} seconds"

    IO.puts "Generating and populating GenServer instance:"
    start_ms = :os.system_time(:millisecond)
    {:ok, process} = InstanceProcess.start_link([])
    InstanceProcess.load_map(process, DungeonCrawl.Repo.preload(instance, :dungeon_map_tiles).dungeon_map_tiles)
    IO.puts "Took #{(:os.system_time(:millisecond) - start_ms) / 1000.0} seconds"

    IO.puts "Running experiements..."
    db_timing_read_only = measure(fn() ->
        for x <- 0..iterations, do: read_only_for_db(instance)
      end)
    IO.puts "DataBase  #{iterations} reads        took (seconds): #{db_timing_read_only}"

    db_timing = measure(fn() ->
        for x <- 0..iterations, do: check_state_and_move_tile_for_db(instance)
      end)
    IO.puts "DataBase  #{iterations} reads/writes took (seconds): #{db_timing}"

    gen_server_timing = measure(fn() ->
        for x <- 0..iterations, do: check_state_and_move_tile_for_process(process)
      end)
    IO.puts "GenServer #{iterations} reads        took (seconds): #{gen_server_timing_read_only}"

    gen_server_timing_read_only = measure(fn() ->
        for x <- 0..iterations, do: read_only_for_process(process)
      end)
    IO.puts "GenServer #{iterations} reads/writes took (seconds): #{gen_server_timing}"

    Logger.configure level: logger_level
  end

  defp check_state_and_move_tile_for_db(instance) do
    row = :rand.uniform(20)-1
    col = :rand.uniform(20)-1
    tile = DungeonInstances.get_map_tile(instance.id, row, col)
    {:ok, _state} = Parser.parse(tile.state) # this'll be slowish
    DungeonInstances.update_map_tile(tile, %{character: "X", z_index: :rand.uniform(5)})
  end


  defp read_only_for_db(instance) do
    row = :rand.uniform(20)-1
    col = :rand.uniform(20)-1
    tile = DungeonInstances.get_map_tile(instance.id, row, col)
  end

  defp check_state_and_move_tile_for_process(process) do
    row = :rand.uniform(20)-1
    col = :rand.uniform(20)-1
    tile = InstanceProcess.get_tile(process, row, col)
    InstanceProcess.update_tile(process, tile.id, %{character: "X", z_index: :rand.uniform(5)})
  end

  defp read_only_for_process(process) do
    row = :rand.uniform(20)-1
    col = :rand.uniform(20)-1
    tile = InstanceProcess.get_tile(process, row, col)
  end
end
