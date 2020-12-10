defmodule Test.LavaProcess do
  use GenServer, restart: :temporary

  alias DungeonCrawl.DungeonProcesses.{Instances,InstanceRegistry,InstanceProcess,Supervisor}

  require Logger

  @timeout 100

  ## Client API

  @doc """
  Starts the program process.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Updates the given map_tile.
  """
  def set_initial_state(program, instance_id, map_tile_id) do
    GenServer.call(program, {:set_initial_state, {instance_id, map_tile_id}})
  end

  @doc """
  Starts the scheduler
  """
  def start_scheduler(program) do
IO.puts "shart sscheduler"
    Process.send_after(program, :perform_actions, @timeout)
  end

  @doc """
  echo a message
  """
  def message(program, message) do
    GenServer.cast(program, {:message, {message}})
  end


  ## Defining GenServer Callbacks

  @impl true
  def init(:ok) do
    {:ok, %{pc: 0, map_tile_id: nil, instance_id: nil}}
  end

  @impl true
  def handle_call({:set_initial_state, {instance_id, map_tile_id}}, _from, %{} = state) do
    {:reply, :ok, %{pc: 0, instance_id: instance_id, map_tile_id: map_tile_id}}
  end

  @impl true
  def handle_cast({:message, {message}}, %{} = state) do
    IO.puts "Program #{state.map_tile_id} got a cast message"
    IO.inspect message
    {:noreply, state}
  end

  def handle_info(:perform_actions, state) do
:timer.sleep 250
    start_ms = :os.system_time(:millisecond)

    state = _lava_thing(state)

#    IO.puts "perform_actions for program # #{state.map_tile_id} took #{(:os.system_time(:millisecond) - start_ms)} ms"

    Process.send_after(self(), :perform_actions, @timeout)

    {:noreply, state}
  end

  # simulated lava stuff, lookup the instance and then make the change to simulate each actual step in an Instances.run_with
  defp _lava_thing(%{pc: 0, instance_id: instance_id, map_tile_id: map_tile_id} = state) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, instance_id)
    InstanceProcess.run_with(instance, fn (instance_state) ->
      map_tile = Instances.get_map_tile_by_id(instance_state, %{id: map_tile_id})
      char = Enum.random(["▒", "░", "░"])
      bc = Enum.random(["red", "red", "darkorange", "orange"])

      {_map_tile, instance_state} = Instances.update_map_tile(instance_state, map_tile, %{character: char, background_color: bc})

      {:ok, instance_state}
    end)

    state
  end

  defp _lava_thing(state) do
IO.puts "lava thing state didnt match"
    %{ state | pc: 0 }
  end
end

defmodule Test.ProgramRegistry do
  use GenServer, restart: :temporary

  require Logger

  alias DungeonCrawl.DungeonProcesses.{Instances,InstanceRegistry,InstanceProcess,Supervisor}

  ## Client API

  @doc """
  Starts the program process.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def link_instance_id(server, instance_id, lavas) do
    GenServer.call(server, {:link_instance, instance_id, lavas})
  end

#  def start_program(server, program_id, elixir_commands) do
#    GenServer.call(server, {:create, program_id, elixir_commands})
#  end

#  def send_program_message(server, program_id, message) do
#    GenServer.call(server, {:send_message, program_id, message})
#  end

  def stop_all_programs(server) do
    GenServer.cast(server, {:stop_all_programs})
  end

  ## Defining GenServer Callbacks

  @impl true
  def init(:ok) do
    program_ids = %{}
    refs = %{}
    {:ok, {program_ids, refs, nil}}
  end

  @impl true
  def handle_call({:link_instance, instance_id, lavas}, _from, {program_ids, refs, nil}) do
IO.puts "linking"
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, instance_id)
    map_tile_ids = \
    InstanceProcess.run_with(instance, fn (instance_state) ->
      map_tile_ids =\
      instance_state.map_by_ids
      |> Map.to_list
      |> Enum.filter(fn {id, map_tile} -> map_tile.character == "." end)
      |> Enum.take(lavas)
      |> Enum.map(fn {id, _} -> id end)

      {map_tile_ids, instance_state}
    end)
IO.puts "starting lava"
IO.inspect map_tile_ids
    {program_ids, refs} = \
      map_tile_ids
      |> Enum.reduce({program_ids, refs}, fn map_tile_id, {program_ids, refs} ->
           _start_lava(instance_id, map_tile_id, program_ids, refs)
         end)


    #todo: set all floor as lava and kick it off
    {:reply, :ok, {program_ids, refs, instance_id}}
  end

  @impl true
  def handle_call({:link_instance, instance_id}, _from, {program_ids, refs, instance_id} = state) do
    IO.puts "INSTANCE ID ALREADY LINKED"
    IO.inspect instance_id
    {:reply, instance_id, state}
  end

  defp _start_lava(instance_id, map_tile_id, program_ids, refs) do
    {:ok, program_process} = DynamicSupervisor.start_child(Supervisor, Test.LavaProcess)

    ref = Process.monitor(program_process)
    refs = Map.put(refs, ref, map_tile_id)
    program_ids = Map.put(program_ids, map_tile_id, program_process)
IO.puts "setting initial prog stte"
    Test.LavaProcess.set_initial_state(program_process, instance_id, map_tile_id)
IO.puts "starthing schedulr"
    Test.LavaProcess.start_scheduler(program_process)
IO.puts "shcudlr started"
    {program_ids, refs}
  end

  # These first two are really to make test setup more convenient#
#  @impl true
#  def handle_call({:create, program_id, elixir_commands}, _from, {program_ids, refs, instance_id}) do
#    {:ok, program_process} = DynamicSupervisor.start_child(Supervisor, Test.ProgramProcess)

#    ref = Process.monitor(program_process)
#    refs = Map.put(refs, ref, program_id)
#    program_ids = Map.put(program_ids, program_id, program_process)

#    Test.ProgramProcess.set_initial_state(program_process, program_id, elixir_commands)
#    Test.ProgramProcess.start_scheduler(program_process)

#    {:reply, program_id, {program_ids, refs}}
#  end

  @impl true
  def handle_call({:send_message, program_id, message}, _from, {program_ids, _refs} = state) do
    case program_ids[program_id] do
      nil -> nil
      program -> Test.LavaProcess.message(program, message)
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:stop_all_programs}, {program_ids, refs, instance_id}) do
    program_ids
    |> Map.to_list
    |> Enum.each(fn {_pid, process} -> GenServer.stop(process, :shutdown) end)

    {:noreply, {program_ids, refs, nil}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, {program_ids, refs, instance_id}) do
    {program_id, refs} = Map.pop(refs, ref)
    program_ids = Map.delete(program_ids, program_id)
    {:noreply, {program_ids, refs, instance_id}}
  end
end
"""
c "perf3.exs"
{:ok, registry} = Test.ProgramRegistry.start_link([])
Test.ProgramRegistry.link_instance_id(registry, 2071)
Test.ProgramRegistry.send_program_message(registry, 1, "HEY DID YOU GET THIS")
Test.ProgramRegistry.stop_all_programs(registry)
"""
