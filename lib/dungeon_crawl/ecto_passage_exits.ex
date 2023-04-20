defmodule DungeonCrawl.EctoPassageExits do
  use Ecto.Type
  def type, do: :string

  # Can't use a map, since the same tile_id could have multiple exits
  # going to it

  @passage_exit_tuple "{(\\d+,[^,\s]+?)}"

  def cast(exits) when is_binary(exits) do
    case _passage_exits(exits) do
      nil ->
        :error

      exits ->
        list = _passage_exits_to_list(exits)
        {:ok, list}
    end
  end

  def cast(exits) when is_list(exits) do
    if _valid_passage_exits?(exits) do
      {:ok, exits}
    else
      :error
    end
  end

  def cast(_), do: :error

  def load(data) do
    {:ok, _passage_exits_to_list(_passage_exits(data))}
  rescue
    _ -> :error
  end

  def dump(exits) do
    if _valid_passage_exits?(exits) do
      {:ok, _stringify_passage_exits(exits)}
    else
      :error
    end
  end

  defp _valid_passage_exits?(exits) do
    Enum.all?(exits, fn {id, key} -> is_integer(id) && is_binary(key) end)
  rescue
    _ -> false
  end

  defp _passage_exits(exits) when is_binary(exits) do
    case Regex.run(
           ~r/\A#{ @passage_exit_tuple }(?:,#{ @passage_exit_tuple })*\z/,
           exits) do
      nil                -> nil
      [ _match | exits ] -> exits
    end
  end

  defp _passage_exits_to_list(exits) do
    exits
    |> Enum.map(fn passage_exit ->
      [tile_id, key] = String.split(passage_exit, ",")
      {String.to_integer(tile_id), key}
    end)
  end

  def _stringify_passage_exits(exits) do
    Enum.map(exits, fn {id, key} -> "{#{ id },#{ key}}" end)
    |> Enum.join(",")
  end
end