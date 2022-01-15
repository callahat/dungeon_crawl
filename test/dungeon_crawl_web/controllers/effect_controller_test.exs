defmodule DungeonCrawlWeb.EffectControllerTest do
  use DungeonCrawlWeb.ConnCase

  alias DungeonCrawl.Sound.Effect

  @valid_attrs %{name: "some name", public: true, zzfx_params: "[,0,130.8128,.1,.1,.34,3,1.88,,,,,,,,.1,,.5,.04]"}
  @update_attrs %{name: "some updated name", public: false, zzfx_params: "1.94,-0.4,257,.01,,.13,,.42,,,,.07,,,,,.05,.96,.02,.05"}
  @invalid_attrs %{name: nil, public: nil, zzfx_params: nil}

  describe "non registered users" do
    test "redirects non admin users", %{conn: conn} do
      conn = get conn, effect_path(conn, :index)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "registered users who are not admins" do
    setup [:normal_user]

    test "lists all entries on index", %{conn: conn} do
      effects_with_one_of_each_ownership_type(conn.assigns.current_user)
      conn = get conn, effect_path(conn, :index)
      assert html_response(conn, 200) =~ "Listing Effects"
      assert html_response(conn, 200) =~ "My Effect"
      refute html_response(conn, 200) =~ "Someone elses effect"
      refute html_response(conn, 200) =~ "Unowned effect"
    end

    test "renders form for new resources", %{conn: conn} do
      conn = get conn, effect_path(conn, :new)
      assert html_response(conn, 200) =~ "New Effect"
    end

    test "creates resource and redirects when data is valid", %{conn: conn} do
      conn = post conn, effect_path(conn, :create), effect: @valid_attrs
      assert redirected_to(conn) == effect_path(conn, :index)
      new_effect = Repo.get_by(Effect, @valid_attrs)
      assert new_effect
    end

    test "does not create resource and renders errors when data is invalid", %{conn: conn} do
      conn = post conn, effect_path(conn, :create), effect: @invalid_attrs
      assert html_response(conn, 200) =~ "New Effect"
    end

    test "shows chosen resource", %{conn: conn} do
      target_effect = insert_effect(Map.put(@valid_attrs, :user_id, conn.assigns.current_user.id))
      conn = get conn, effect_path(conn, :show, target_effect)
      assert html_response(conn, 200) =~ "Show Effect"
    end

    test "redirects if chosen resource is someone elses", %{conn: conn} do
      target_effect = insert_effect @valid_attrs
      conn = get conn, effect_path(conn, :show, target_effect)
      assert redirected_to(conn) == effect_path(conn, :index)
      assert get_flash(conn, :error) == "You do not have access to that"
    end

    test "renders page not found when id is nonexistent", %{conn: conn} do
      assert_error_sent 404, fn ->
        get conn, effect_path(conn, :show, -1)
      end
    end

    test "renders form for editing chosen resource", %{conn: conn} do
      target_effect = insert_effect(%{user_id: conn.assigns.current_user.id})
      conn = get conn, effect_path(conn, :edit, target_effect)
      assert html_response(conn, 200) =~ "Edit Effect"
    end

    test "redirects when trying to edit someone elses resource", %{conn: conn} do
      target_effect = insert_effect @valid_attrs
      conn = get conn, effect_path(conn, :edit, target_effect)
      assert redirected_to(conn) == effect_path(conn, :index)
      assert get_flash(conn, :error) == "You do not have access to that"
    end

    test "updates chosen resource and redirects when data is valid", %{conn: conn} do
      target_effect = insert_effect Map.put(@valid_attrs, :user_id, conn.assigns.current_user.id)
      conn = put conn, effect_path(conn, :update, target_effect), effect: @update_attrs
      assert redirected_to(conn) == effect_path(conn, :show, target_effect)
      assert Repo.get_by(Effect, Map.merge(@valid_attrs,@update_attrs))
    end

    test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
      target_effect = insert_effect(%{user_id: conn.assigns.current_user.id})
      conn = put conn, effect_path(conn, :update, target_effect), effect: @invalid_attrs
      assert html_response(conn, 200) =~ "Edit Effect"
    end

    test "does not update if chosen resource belongs to someone else", %{conn: conn} do
      target_effect = insert_effect @valid_attrs
      conn = put conn, effect_path(conn, :update, target_effect), effect: @update_attrs
      assert redirected_to(conn) == effect_path(conn, :index)
      assert get_flash(conn, :error) == "You do not have access to that"
    end

    test "deletes chosen resource on delete", %{conn: conn} do
      target_effect = insert_effect(%{user_id: conn.assigns.current_user.id})
      conn = delete conn, effect_path(conn, :delete, target_effect)
      assert redirected_to(conn) == effect_path(conn, :index)
      refute Repo.get(Effect, target_effect.id)
    end
  end

  describe "admin users" do
    setup [:admin_user]

    test "lists all entries on index", %{conn: conn} do
      effects_with_one_of_each_ownership_type(conn.assigns.current_user)
      conn = get conn, effect_path(conn, :index)
      assert html_response(conn, 200) =~ "Listing Effects"
      assert html_response(conn, 200) =~ "My Effect"
      assert html_response(conn, 200) =~ "Someone elses effect"
      assert html_response(conn, 200) =~ "Unowned effect"
    end

    test "lists users entries on index", %{conn: conn} do
      effects_with_one_of_each_ownership_type(conn.assigns.current_user)
      conn = get conn, effect_path(conn, :index, %{list: "mine"})
      assert html_response(conn, 200) =~ "Listing Effects"
      assert html_response(conn, 200) =~ "My Effect"
      refute html_response(conn, 200) =~ "Someone elses effect"
      refute html_response(conn, 200) =~ "Unowned effect"
    end

    test "lists unowned entries on index", %{conn: conn} do
      effects_with_one_of_each_ownership_type(conn.assigns.current_user)
      conn = get conn, effect_path(conn, :index, %{list: "nil"})
      assert html_response(conn, 200) =~ "Listing Effects"
      refute html_response(conn, 200) =~ "My Effect"
      refute html_response(conn, 200) =~ "Someone elses effect"
      assert html_response(conn, 200) =~ "Unowned effect"
    end

    test "renders form for new resources", %{conn: conn} do
      conn = get conn, effect_path(conn, :new)
      assert html_response(conn, 200) =~ "New Effect"
    end

    test "creates resource and redirects when data is valid", %{conn: conn} do
      conn = post conn, effect_path(conn, :create), effect: @valid_attrs
      assert redirected_to(conn) == effect_path(conn, :index)
      new_effect = Repo.get_by(Effect, @valid_attrs)
      assert new_effect
      assert new_effect.user_id == nil
    end

    test "creates resource and redirects when data is valid and can own", %{conn: conn} do
      conn = post conn, effect_path(conn, :create), effect: @valid_attrs, self_owned: "true"
      assert redirected_to(conn) == effect_path(conn, :index)
      new_effect = Repo.get_by(Effect, @valid_attrs)
      assert new_effect
      assert new_effect.user_id == conn.assigns.current_user.id
    end

    test "does not create resource and renders errors when data is invalid", %{conn: conn} do
      conn = post conn, effect_path(conn, :create), effect: @invalid_attrs
      assert html_response(conn, 200) =~ "New Effect"
    end

    test "shows chosen resource", %{conn: conn} do
      target_effect = insert_effect @valid_attrs
      conn = get conn, effect_path(conn, :show, target_effect)
      assert html_response(conn, 200) =~ "Show Effect"
    end

    test "renders page not found when id is nonexistent", %{conn: conn} do
      assert_error_sent 404, fn ->
        get conn, effect_path(conn, :show, -1)
      end
    end

    test "renders form for editing chosen resource", %{conn: conn} do
      target_effect = insert_effect @valid_attrs
      conn = get conn, effect_path(conn, :edit, target_effect)
      assert html_response(conn, 200) =~ "Edit Effect"
    end

    test "can edit active effect", %{conn: conn} do
      effect = insert_effect(%{active: true})
      conn = get conn, effect_path(conn, :edit, effect), effect: @update_attrs
      assert html_response(conn, 200) =~ "Edit Effect"
    end

    test "updates chosen resource and redirects when data is valid", %{conn: conn} do
      target_effect = insert_effect @valid_attrs
      conn = put conn, effect_path(conn, :update, target_effect), effect: @update_attrs, self_owned: "true"
      assert redirected_to(conn) == effect_path(conn, :show, target_effect)
      updated_effect = Repo.get_by(Effect, Map.merge(@valid_attrs, @update_attrs))
      assert updated_effect
      assert updated_effect.user_id == conn.assigns.current_user.id
    end

    test "updates chosen resource and redirects when data is valid and can assign to no one", %{conn: conn} do
      target_effect = insert_effect @valid_attrs
      conn = put conn, effect_path(conn, :update, target_effect), effect: @update_attrs, self_owned: "false"
      assert redirected_to(conn) == effect_path(conn, :show, target_effect)
      updated_effect = Repo.get_by(Effect, Map.merge(@valid_attrs,@update_attrs))
      assert updated_effect
      assert updated_effect.user_id == nil
    end

    test "updates chosen resource and redirects when data is valid and cannot assign to no one if owned by someone else", %{conn: conn} do
      other_user = insert_user()
      target_effect = insert_effect(Map.put(@valid_attrs, :user_id, other_user.id))
      conn = put conn, effect_path(conn, :update, target_effect), effect: @update_attrs, self_owned: "false"
      assert redirected_to(conn) == effect_path(conn, :show, target_effect)
      updated_effect = Repo.get_by(Effect, Map.merge(@valid_attrs, @update_attrs))
      assert updated_effect
      assert updated_effect.user_id == other_user.id
    end

    test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
      target_effect = insert_effect @valid_attrs
      conn = put conn, effect_path(conn, :update, target_effect), effect: @invalid_attrs
      assert html_response(conn, 200) =~ "Edit Effect"
    end

    test "deletes chosen resource on delete", %{conn: conn} do
      target_effect = insert_effect @valid_attrs
      conn = delete conn, effect_path(conn, :delete, target_effect)
      assert redirected_to(conn) == effect_path(conn, :index)
      refute Repo.get(Effect, target_effect.id)
    end
  end

  defp normal_user(_) do
    user = insert_user(%{username: "Threepwood", is_admin: false})
    conn = assign(build_conn(), :current_user, user)
    {:ok, conn: conn, user: user}
  end

  defp admin_user(_) do
    user = insert_user(%{username: "CSwaggins", is_admin: true})
    conn = assign(build_conn(), :current_user, user)
    {:ok, conn: conn, user: user}
  end

  defp effects_with_one_of_each_ownership_type(user) do
    insert_effect(%{name: "My Effect", user_id: user.id})
    insert_effect(%{name: "Someone elses effect", user_id: insert_user().id})
    insert_effect(%{name: "Unowned effect", user_id: nil})
  end
end
