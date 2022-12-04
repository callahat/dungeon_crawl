defmodule DungeonCrawlWeb.Admin.SettingController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Admin

  def edit(conn, _) do
    setting = Admin.get_setting()
    changeset = Admin.change_setting(setting)
    render(conn, "edit.html", setting: setting, changeset: changeset)
  end

  def update(conn, %{"setting" => setting_params}) do
    case Admin.update_setting(setting_params) do
      {:ok, _setting} ->
        conn
        |> put_flash(:info, "Setting updated successfully.")
        |> redirect(to: Routes.admin_setting_path(conn, :edit))

      {:error, %Ecto.Changeset{} = changeset} ->
        setting = Admin.get_setting()
        render(conn, "edit.html", setting: setting, changeset: changeset)
    end
  end
end
