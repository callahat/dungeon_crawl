defmodule DungeonCrawlWeb.EffectController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Sound
  alias DungeonCrawl.Sound.Effect

  plug :authenticate_user
  plug :assign_effect when action in [:show, :edit, :update, :delete]
  plug :assigns_effect_params when action in [:create, :update]
  plug :strip_user_id_when_invalid when action in [:update]

  def index(conn, params) do
    effects = cond do
      !conn.assigns.current_user.is_admin || params["list"] == "mine" ->
        Sound.list_effects(conn.assigns.current_user)
      params["list"] == "nil" -> Sound.list_effects(:nouser)
      true -> Sound.list_effects
    end

    render(conn, "index.html", effects: effects)
  end

  def new(conn, _params) do
    changeset = Sound.change_effect(%Effect{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"effect" => _effect_params}) do
    case Sound.create_effect(conn.assigns.effect_params) do
      {:ok, _effect} ->
        conn
        |> put_flash(:info, "Effect created successfully.")
        |> redirect(to: Routes.effect_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => _id}) do
    effect = conn.assigns.effect
    render(conn, "show.html", effect: effect)
  end

  def edit(conn, %{"id" => _id}) do
    effect = conn.assigns.effect
    changeset = Sound.change_effect(effect)
    render(conn, "edit.html", effect: effect, changeset: changeset)
  end

  def update(conn, %{"id" => _id, "effect" => _effect_params}) do
    effect = conn.assigns.effect

    case Sound.update_effect(effect, conn.assigns.effect_params) do
      {:ok, effect} ->
        conn
        |> put_flash(:info, "Effect updated successfully.")
        |> redirect(to: Routes.effect_path(conn, :show, effect))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", effect: effect, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => _id}) do
    effect = conn.assigns.effect
    {:ok, _effect} = Sound.delete_effect(effect)

    conn
    |> put_flash(:info, "Effect deleted successfully.")
    |> redirect(to: Routes.effect_path(conn, :index))
  end

  defp assign_effect(conn, _opts) do
    effect =  Sound.get_effect!(conn.params["id"])

    if conn.assigns.current_user.is_admin || effect.user_id == conn.assigns.current_user.id do
      conn
      |> assign(:effect, effect)
    else
      conn
      |> put_flash(:error, "You do not have access to that")
      |> redirect(to: Routes.effect_path(conn, :index))
      |> halt()
    end
  end

  defp assigns_effect_params(conn, _opts) do
    filtered_params = cond do
      !conn.assigns.current_user.is_admin ->
        Map.take(conn.params["effect"],
          ["name", "public", "zzfx_params"])
        |> params_with_owner(conn)

      conn.params["self_owned"] == "true" ->
        conn.params["effect"]
        |> params_with_owner(conn)

      true ->
        conn.params["effect"]
        |> Map.put("user_id", nil)
    end

    conn
    |> assign(:effect_params, filtered_params)
  end

  defp params_with_owner(params, conn) do
    Map.put(params, "user_id", conn.assigns.current_user.id)
  end

  defp strip_user_id_when_invalid(conn, _opts) do
    if (conn.assigns.effect.user_id == nil || conn.assigns.effect.user_id == conn.assigns.current_user.id) &&
         conn.assigns.current_user.is_admin do
      assign(conn, :effect_params, conn.assigns.effect_params)
    else
      assign(conn, :effect_params, Map.delete(conn.assigns.effect_params, "user_id"))
    end
  end
end
