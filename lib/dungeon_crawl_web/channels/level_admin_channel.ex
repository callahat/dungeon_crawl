defmodule DungeonCrawlWeb.LevelAdminChannel do
  use DungeonCrawl.Web, :channel

  alias DungeonCrawl.Account
  alias DungeonCrawl.DungeonProcesses.LevelRegistry
  alias DungeonCrawl.DungeonProcesses.Registrar

  def join("level_admin:" <> dungeon_instance_id_and_instance_id, _payload, socket) do
    [dungeon_instance_id, instance_id] = dungeon_instance_id_and_instance_id
                                         |> String.split(":")
                                         |> Enum.map(&String.to_integer(&1))

    with {:ok, instance_registry} <- Registrar.instance_registry(dungeon_instance_id),
         {:ok, _instance} <- LevelRegistry.lookup_or_create(instance_registry, instance_id),
         %{is_admin: true} <- Account.get_by_user_id_hash(socket.assigns.user_id_hash) do
      socket = assign(socket, :instance_id, instance_id)
               |> assign(:instance_registry, instance_registry)

      {:ok, %{instance_id: instance_id}, socket}
    else
      %{is_admin: false} -> {:error, %{message: "Could not join channel"}}
      _ -> {:error, %{message: "Not found", reload: true}}
    end
  end

  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end
end
