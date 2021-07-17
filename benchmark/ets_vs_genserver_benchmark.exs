# Initially from here: https://github.com/devonestes/fast-elixir/blob/master/code/general/ets_vs_gen_server_write.exs
# Modified to see how multiple values/multple state changes impacts the speeds
defmodule RetrieveState.Fast do
  def put_state(ets_pid, []), do: :done
  def put_state(ets_pid, [state | states]) do
    :ets.insert(ets_pid, {:stored_state, state})
    put_state(ets_pid, states)
  end
end

defmodule StateHolder do
  use GenServer

  def init(_), do: {:ok, {:ets.new(:state_store, [:set, :private]), %{}}}

  def start_link(state \\ []), do: GenServer.start_link(__MODULE__, state, name: __MODULE__)

  def put_state(value), do: GenServer.call(__MODULE__, {:put_state, value})

  def put_state_in_ets(value), do: GenServer.call(__MODULE__, {:put_state_ets, value})

  def handle_call({:put_state, value}, _from, {ets, state}) do
   updated_state = _state_helper(state, value)
   {:reply, true, {ets, updated_state}}
  end

  def _state_helper(state, []), do: state
  def _state_helper(state, [value | values]), do: Map.put(state, :stored_state, value) |> _state_helper(values)

  def handle_call({:put_state_ets, value}, _from, {ets, _state} = internal) do
    _ets_state_helper(ets, value)
    {:reply, true, internal}
  end

  def _ets_state_helper(ets, values) do
    Enum.each values, fn value -> :ets.insert(ets, {:stored_state, value}) end
  end
end

defmodule RetrieveState.Medium do
  def put_state(value) do
    StateHolder.put_state(value)
  end

  def put_state_in_ets(value) do
    StateHolder.put_state_in_ets(value)
  end
end

defmodule RetrieveState.Slow do
  def put_state([]), do: nil
  def put_state([value | values]) do
    :persistent_term.put(:stored_state, value)
    put_state(values)
  end
end

defmodule RetrieveState.Benchmark do
  def benchmark do
    ets_pid = :ets.new(:state_store, [:set, :public])
    StateHolder.start_link()
    # locally, when less than 100 ets wins; as that value goes higher, the gen server starts to win
    values = 1..500 |> Enum.to_list

    Benchee.run(
      %{
        "ets table" => fn -> RetrieveState.Fast.put_state(ets_pid, values) end,
        "gen server" => fn -> RetrieveState.Medium.put_state(values) end,
        "gen server w ets" => fn -> RetrieveState.Medium.put_state_in_ets(values) end,
        "persistent term" => fn -> RetrieveState.Slow.put_state(values) end
      },
      time: 10,
      print: [fast_warning: false]
    )
  end
end

RetrieveState.Benchmark.benchmark()
