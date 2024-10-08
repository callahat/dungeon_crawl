defmodule DungeonCrawlWeb.LevelAdminChannel do
  use DungeonCrawl.Web, :channel

  alias DungeonCrawl.Account
  alias DungeonCrawl.DungeonProcesses.LevelProcess
  alias DungeonCrawl.DungeonProcesses.LevelRegistry
  alias DungeonCrawl.DungeonProcesses.Registrar

  def join("level_admin:" <> dungeon_instance_id_number_and_owner_id, _payload, socket) do
    [dungeon_instance_id, level_number, owner_id] = dungeon_instance_id_number_and_owner_id
                                                   |> String.split(":")
                                                   |> Enum.map(&_to_integer(&1))

    with {:ok, instance_registry} <- Registrar.instance_registry(dungeon_instance_id),
         {:ok, _instance} <- LevelRegistry.lookup_or_create(instance_registry, level_number, owner_id),
         %{is_admin: true} <- Account.get_by_user_id_hash(socket.assigns.user_id_hash) do
      socket = assign(socket, :level_number, level_number)
               |> assign(:level_owner_id, owner_id)
               |> assign(:instance_registry, instance_registry)

      {:ok, %{dungeon_instance_id: dungeon_instance_id, level_number: level_number, level_owner_id: owner_id}, socket}
    else
      %{is_admin: false} -> {:error, %{message: "Could not join channel"}}
      _ -> {:error, %{message: "Not found", reload: true}}
    end
  end

  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  def handle_in("rerender", _, socket) do
    {:ok, instance} = _get_instance_process(socket.assigns)

    level_table =
      LevelProcess.run_with(instance, fn (instance_state) ->
        %{"rows" => height, "cols" => width} = instance_state.state_values
        level_table = DungeonCrawlWeb.SharedView.level_as_table(instance_state, height, width)

        {level_table, instance_state}
      end)

    {:reply, {:ok, level_table}, socket}
  end

  defp _to_integer(""), do: nil
  defp _to_integer(str) when is_binary(str), do: String.to_integer(str)

  defp _get_instance_process(%{instance_registry: registry, level_number: number, level_owner_id: owner_id}) do
    {:ok, {_instance_id, process}} = LevelRegistry.lookup_or_create(registry, number, owner_id)
    {:ok, process}
  end
end
