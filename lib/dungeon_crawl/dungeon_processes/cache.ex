defmodule DungeonCrawl.DungeonProcesses.Cache do
  use GenServer

  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Sound
  alias DungeonCrawl.Scripting.Parser

  alias DungeonCrawl.DungeonProcesses.Cache

  @moduledoc """
  Serves as a cache for records pulled from the database that may be used
  later. Caches tile templates, items, and sound effects.
  """

  defstruct tile_templates: %{},
            items: %{},
            sound_effects: %{}

  ## Client API

  @doc """
  Starts the instance process.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Returns the state of the cache, in the form of the struct of the separate caches.
  """
  def get_state(instance) do
    GenServer.call(instance, {:get_state})
  end

  @doc """
  Clears all cached records.
  """
  def clear(instance) do
    GenServer.call(instance, {:clear})
  end

  @doc """
  Looks up a tile template from the cache, falling back to getting it from the database and saving for later.
  Returns a two part tuple, the first being the tile template if found, followed by an atom indicating if it
  exists in cache, was created in the cache, or not_found.
  """
  def get_tile_template(instance, slug, author) when is_binary(slug) do
    GenServer.call(instance, {:get_tile_template, {slug, author}})
  end
  def get_tile_template(_instance, _slug, _author), do: {nil, :not_found}

  @doc """
  Looks up an item from the cache, falling back to getting it from the database and saving for later.
  Returns a two part tuple, the first being the item if found, followed by an atom indicating if it
  exists in cache, was created in the cache, or not_found. Returns `:nothing_equipped` if the slug
  is nil or empty string.
  """
  def get_item(_instance, "", _author), do: {nil, :nothing_equipped}
  def get_item(_instance, nil, _author), do: {nil, :nothing_equipped}
  def get_item(instance, slug, author) when is_binary(slug) do
    GenServer.call(instance, {:get_item, {slug, author}})
  end
  def get_item(_instance, _slug, _author), do: {nil, :not_found}


  @doc """
  Looks up a sound effect from the cache, falling back to getting it from the database and saving for later.
  Returns a two part tuple, the first being the effect if found, followed by an atom indicating if it
  exists in cache, was created in the cache, or not_found.
  """
  def get_sound_effect(instance, slug, author) when is_binary(slug) do
    GenServer.call(instance, {:get_sound_effect, {slug, author}})
  end
  def get_sound_effect(_instance, _slug, _author), do: {nil, :not_found}

  ## Defining GenServer Callbacks

  @impl true
  def init(:ok) do
    Process.set_label("Cache")
    {:ok, %Cache{}}
  end

  @impl true
  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:clear}, _from, _state) do
    {:reply, :ok, %Cache{}}
  end

  @impl true
  def handle_call({:get_tile_template, {slug, author}}, _from, %Cache{} = state) do
    _cache(state, :tile_templates, slug, author, &TileTemplates.get_tile_template/1)
  end

  @impl true
  def handle_call({:get_item, {slug, author}}, _from, %Cache{} = state) do
    _cache(state, :items, slug, author, &Equipment.get_item/1, &_parse_and_start_program/1)
  end

  @impl true
  def handle_call({:get_sound_effect, {slug, author}}, _from, %Cache{} = state) do
    _cache(state, :sound_effects, slug, author, &Sound.get_effect/1)
  end

  ## Defining useful helper functions

  defp _useable_record(record, author) do
    is_nil(author) ||
      is_nil(record.user_id) ||
      record.public ||
      author.is_admin ||
      author.id == record.user_id
  end

  defp _cache(state, cache_type, slug, author, get_record, record_prep \\ &_noop/1) do
    cache = Map.fetch!(state, cache_type)
    if record = cache[slug] do
      {:reply, {record, :exists}, state}
    else
      with record when not is_nil(record) <- get_record.(slug),
           true <- _useable_record(record, author) do
        record = record_prep.(record)
        {:reply, {record, :created}, %{ state | cache_type => Map.put(cache, slug, record) }}
      else
        _ -> {:reply, {nil, :not_found}, state}
      end
    end
  end

  defp _noop(record), do: record
  defp _parse_and_start_program(item) do
    {:ok, program} = Parser.parse(item.script)
    Map.put item, :program, program
  end
end
