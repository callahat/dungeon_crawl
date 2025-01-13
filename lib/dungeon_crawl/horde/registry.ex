defmodule DungeonCrawl.Horde.Registry do
  use Horde.Registry

  # TODO: should this be moved/absorbed by DungeonRegistry? Might also be useful to
  # keep it separated for organizational purposes

  require Logger

  def start_link(_) do
    Horde.Registry.start_link(__MODULE__, [keys: :unique], name: __MODULE__)
  end

  def init(init_arg) do
    [members: members()]
    |> Keyword.merge(init_arg)
    |> Horde.Registry.init()
  end

  def add_dungeon_process_meta(dungeon_id, pid) do
    _put_meta({:dungeon_id, dungeon_id}, {:pid, pid})
    _put_meta({:pid, pid}, {:dungeon_id, dungeon_id})
  end

  def get_dungeon_process_meta({type, _key_value} = key)
      when type == :dungeon_id or type == :pid do
    _meta(key)
  end

  def remove_dungeon_process_meta({type, key_value} = key)
      when type == :dungeon_id or type == :pid do
    case _meta(key) do
      {:ok, {:dungeon_id, dungeon_id}} ->
        _put_meta({:dungeon_id, dungeon_id}, nil)
        _put_meta({:pid, key_value}, nil)
      {:ok, {:pid, pid}} ->
        _put_meta({:dungeon_id, key_value}, nil)
        _put_meta({:pid, pid}, nil)
      :error -> nil # not sure anything can be done, maybe log it?
        Logger.info "Recieved remove meta request for #{ inspect key } " <>
                    "but it was not found - maybe already cleared?"
    end

    :ok
  end

  defp _put_meta(key, value) do
    Horde.Registry.put_meta(__MODULE__, key, value)
  end

  defp _meta(key) do
    Horde.Registry.meta(__MODULE__, key)
  end

  defp members() do
    Enum.map([Node.self() | Node.list()], &{__MODULE__, &1})
  end
end
