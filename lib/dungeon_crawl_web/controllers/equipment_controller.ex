defmodule DungeonCrawlWeb.EquipmentController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Equipment.Item

  plug :authenticate_user
  plug :assign_item when action in [:show, :edit, :update, :delete]
  plug :assigns_item_params when action in [:create, :update]
  plug :strip_user_id_when_invalid when action in [:update]

  def index(conn, params) do
    items = cond do
              !conn.assigns.current_user.is_admin || params["list"] == "mine" ->
                Equipment.list_items(conn.assigns.current_user)
              params["list"] == "nil" -> Equipment.list_items(:nouser)
              true -> Equipment.list_items
            end

    render(conn, "index.html", items: items)
  end

  def new(conn, _params) do
    changeset = Equipment.change_item(%Item{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"item" => _item_params}) do
    case Equipment.create_item(conn.assigns.item_params) do
      {:ok, _item} ->
        conn
        |> put_flash(:info, "Item created successfully.")
        |> redirect(to: Routes.equipment_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => _id}) do
    item = conn.assigns.item
    owner_name = if item.user_id, do: Repo.preload(item, :user).user.name, else: "<None>"

    render(conn, "show.html", item: item, owner_name: owner_name)
  end

  def edit(conn, %{"id" => _id}) do
    item = conn.assigns.item
    changeset = Equipment.change_item(item)
    render(conn, "edit.html", item: item, changeset: changeset)
  end

  def update(conn, %{"id" => _id, "item" => _item_params}) do
    item = conn.assigns.item

    case Equipment.update_item(item, conn.assigns.item_params) do
      {:ok, item} ->
        conn
        |> put_flash(:info, "Item updated successfully.")
        |> redirect(to: Routes.equipment_path(conn, :show, item))
      {:error, changeset} ->
        render(conn, "edit.html", item: item, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => _id}) do
    item = conn.assigns.item

    case Equipment.delete_item(item) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Item deleted successfully.")
        |> redirect(to: Routes.equipment_path(conn, :index))
    end
  end

  defp assign_item(conn, _opts) do
    item =  Equipment.get_item!(String.to_integer(conn.params["id"]))

    if conn.assigns.current_user.is_admin || item.user_id == conn.assigns.current_user.id do
      conn
      |> assign(:item, item)
    else
      conn
      |> put_flash(:error, "You do not have access to that")
      |> redirect(to: Routes.equipment_path(conn, :index))
      |> halt()
    end
  end

  defp assigns_item_params(conn, _opts) do
    filtered_params = cond do
      !conn.assigns.current_user.is_admin ->
        Map.take(conn.params["item"],
                 ["name", "description", "public", "script", "weapon", "consumable", ])
        |> params_with_owner(conn)

      conn.params["self_owned"] == "true" ->
        conn.params["item"]
        |> params_with_owner(conn)

      true ->
        conn.params["item"]
        |> Map.put("user_id", nil)
    end
    
    conn
    |> assign(:item_params, filtered_params)
  end

  defp params_with_owner(params, conn) do
    Map.put(params, "user_id", conn.assigns.current_user.id)
  end

  defp strip_user_id_when_invalid(conn, _opts) do
    if (conn.assigns.item.user_id == nil || conn.assigns.item.user_id == conn.assigns.current_user.id) &&
        conn.assigns.current_user.is_admin do
      assign(conn, :item_params, conn.assigns.item_params)
    else
      assign(conn, :item_params, Map.delete(conn.assigns.item_params, "user_id"))
    end
  end
end
