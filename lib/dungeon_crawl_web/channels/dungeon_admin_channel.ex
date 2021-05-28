defmodule DungeonCrawlWeb.DungeonAdminChannel do
  use DungeonCrawl.Web, :channel

  alias DungeonCrawl.Account
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonProcesses.MapSets

  # TODO: what prevents someone from changing the instance_id to a dungeon they are not actually in (or allowed to be in)
  # and evesdrop on broadcasts?
  def join("dungeon_admin:" <> map_set_instance_id_and_instance_id, _payload, socket) do
    [map_set_instance_id, instance_id] = map_set_instance_id_and_instance_id
                                         |> String.split(":")
                                         |> Enum.map(&String.to_integer(&1))

    with {:ok, instance_registry} <- MapSets.instance_registry(map_set_instance_id),
         {:ok, _instance} <- InstanceRegistry.lookup_or_create(instance_registry, instance_id),
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
