defmodule DungeonCrawl.EctoProgramMessages do
  use Ecto.Type
  def type, do: :jsonb

  def cast(data) do
    cond do
      is_nil(data) || data == []->
        {:ok, []}

      _valid_inner_tuple(data) ->
        detupled_data =
          data
          |> Enum.map(fn {message, sender} -> [message, sender] end)

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
        |> Enum.map(fn [message, sender] -> {message, sender} end)

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

  # The data being saved/loaded is internal, so it should not be subject to
  # bad user input. However its good to double check, but any errors the
  # user cannot do anything about.
  # Basically checks for corrupt data.
  defp _valid_inner_tuple(data) do
    is_list(data) &&
      Enum.all?(data, fn
        {message, sender} -> is_binary(message) && is_map(sender)
        _ -> false
      end)
  end

  defp _valid_inner_list(data) do
    is_list(data) &&
      Enum.all?(data, fn
        [message, sender] -> is_binary(message) && is_map(sender)
        _ -> false
      end)
  end
end