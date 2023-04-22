defmodule DungeonCrawl.EctoPassageExits do
  use Ecto.Type
  def type, do: :jsonb

  def cast(data) do
    cond do
      is_nil(data) || data == []->
        {:ok, []}

      _valid_inner_tuple(data) ->
        detupled_data =
          data
          |> Enum.map(fn {tile_id, key} -> [tile_id, key] end)

        { :ok, detupled_data }

      _valid_inner_list(data) ->
        {:ok, data}

      true -> :error
    end
  end

  def load(data) do
    if _valid_inner_list(data) do
      tupled_data =
        data
        |> Enum.map(fn [tile_id, key] -> {tile_id, key} end)

      {:ok, tupled_data}
    else
      :error
    end
  end

  def dump(data) do
    if _valid_inner_list(data) do
      {:ok, data}
    else
      :error
    end
  end

  defp _valid_inner_tuple(data) do
    is_list(data) &&
      Enum.all?(data, fn
        {tile_id, passage_key} -> is_integer(tile_id) && is_binary(passage_key)
        _ -> false
      end)
  end

  defp _valid_inner_list(data) do
    is_list(data) &&
      Enum.all?(data, fn
        [tile_id, passage_key] -> is_integer(tile_id) && is_binary(passage_key)
        _ -> false
      end)
  end
end