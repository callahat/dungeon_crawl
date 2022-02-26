defmodule DungeonCrawl.SoundTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Sound

  describe "effects" do
    alias DungeonCrawl.Sound.Effect

    @valid_attrs %{name: "Some Name", public: true, zzfx_params: "[,0,130.8128,.1,.1,.34,3,1.88,,,,,,,,.1,,.5,.04]"}
    @update_attrs %{name: "some updated name", public: false, zzfx_params: "1.94,-0.4,257,.01,,.13,,.42,,,,.07,,,,,.05,.96,.02,.05"}
    @invalid_attrs %{name: "Derp", public: false, zzfx_params: ""}
    @other_zzfx_params "[3,,485,.02,.2,.2,4,.11,-3,.1,,,.05,1.1,,.4,,.57,.5]"

    def effect_fixture(attrs \\ %{}) do
      {:ok, effect} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Sound.create_effect()

      effect
    end

    test "list_effects/0 returns all effects" do
      effect = effect_fixture()
      assert Sound.list_effects() == [effect]
    end

    test "list_effects/1 returns the effects owned by a user" do
      user = insert_user()
      different_user = insert_user()
      effect = effect_fixture(%{user_id: user.id})
      effect_fixture(%{user_id: different_user.id})
      assert Sound.list_effects(user) == [effect]
    end

    test "list_effects/1 returns the effects owned by no users" do
      effect = effect_fixture(%{user_id: nil})
      assert Sound.list_effects(:nouser) == [effect]
    end

    test "list_useable_effects/1 returns effects a user can use" do
      user = insert_user()
      different_user = insert_user()
      effect = effect_fixture(%{user_id: user.id})
      public_effect = effect_fixture(%{user_id: different_user.id, public: true})
      effect_fixture(%{user_id: different_user.id, public: false})
      assert Sound.list_useable_effects(user) == [effect, public_effect]
    end

    test "get_effect/1" do
      effect = effect_fixture()
      assert Sound.get_effect(effect.id) == effect
      assert Sound.get_effect("#{effect.id}") == effect
      refute Sound.get_effect(effect.id + 1)
    end

    test "get_effect!/1" do
      effect = effect_fixture()
      assert Sound.get_effect!(effect.id) == effect
      assert Sound.get_effect!("#{effect.id}") == effect
    end

    test "get_effect_by_slug/1" do
      effect = effect_fixture()
      assert Sound.get_effect_by_slug(effect.slug) == effect
      refute Sound.get_effect_by_slug("fakeslug")
    end

    test "get_effect_by_slug!/1" do
      effect = effect_fixture()
      assert Sound.get_effect_by_slug!(effect.slug) == effect
    end

    # tests around setting the slug may be redundant since this is tested in sluggable
    test "create_effect/1 with valid data and no user creates a effect and sets slug" do
      assert {:ok, %Effect{} = effect} = Sound.create_effect(@valid_attrs)
      assert effect.name == "Some Name"
      assert effect.public == true
      assert effect.zzfx_params == @valid_attrs.zzfx_params
      assert effect.slug == "some_name"
      assert is_nil(effect.user_id)
    end

    test "create_effect/1 with valid data and admin creates a effect and sets slug" do
      user = insert_user(%{is_admin: true})
      # creates the slug
      params = Map.put(@valid_attrs, :user_id, user.id)
      assert {:ok, %Effect{} = effect} = Sound.create_effect(params)
      assert effect.slug == "some_name"

      # when the slug already exists, the id is appended to the slug
      params = Map.put(@valid_attrs, :user_id, user.id)
      assert {:ok, %Effect{} = effect} = Sound.create_effect(params)
      assert effect.slug == "some_name_#{effect.id}"

      # slug cannot be explicitly set
      params = Map.merge(@valid_attrs, %{user_id: user.id, slug: "goober"})
      assert {:ok, %Effect{} = effect} = Sound.create_effect(params)
      refute effect.slug == "goober"
      assert effect.slug == "some_name_#{effect.id}"
    end

    test "create_effect/1 with valid data and normal user creates a effect and sets slug" do
      user = insert_user(%{is_admin: false})
      # creates the slug with id appended
      assert {:ok, %Effect{} = effect} = Sound.create_effect(Map.put(@valid_attrs, :user_id, user.id))
      assert effect.slug == "some_name_#{effect.id}"
    end

    test "create_effect/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sound.create_effect(@invalid_attrs)
    end

    test "update_effect/2 with valid data updates the effect" do
      effect = effect_fixture()
      assert {:ok, %Effect{} = effect} = Sound.update_effect(effect, @update_attrs)
      assert effect.name == "some updated name"
      assert effect.public == false
      assert effect.zzfx_params == @update_attrs.zzfx_params
    end

    test "update_effect/2 with does not update the slug" do
      effect = effect_fixture()
      assert {:ok, %Effect{} = updated_effect} = Sound.update_effect(effect, @update_attrs)
      assert updated_effect.name == "some updated name"
      assert updated_effect.public == false
      assert updated_effect.slug == effect.slug
    end

    test "update_effect/2 with invalid data returns error changeset" do
      effect = effect_fixture()
      assert {:error, %Ecto.Changeset{}} = Sound.update_effect(effect, @invalid_attrs)
      assert effect == Sound.get_effect!(effect.id)
    end

    test "find_effect/1" do
      {:ok, %Effect{} = existing_effect} = Sound.create_effect(@valid_attrs)

      assert existing_effect == Sound.find_effect(@valid_attrs)
      refute Sound.find_effect(%{name: "effect that does not exist"})
    end

    test "find_or_create_effect/1 finds existing effect" do
      {:ok, %Effect{} = existing_effect} = Sound.create_effect(@valid_attrs)

      assert {:ok, existing_effect} == Sound.find_or_create_effect(@valid_attrs)
    end

    test "find_or_create_effect!/1 finds existing effect" do
      {:ok, %Effect{} = existing_effect} = Sound.create_effect(@valid_attrs)

      assert existing_effect == Sound.find_or_create_effect!(@valid_attrs)
    end

    test "find_or_create_effect/1 creates effect when matching one not found" do
      {:ok, %Effect{} = existing_effect} = Sound.create_effect(@valid_attrs)
      assert {:ok, %Effect{} = effect} = Sound.find_or_create_effect(%{@valid_attrs | zzfx_params: @other_zzfx_params})

      refute existing_effect == effect
      assert effect.zzfx_params == @other_zzfx_params
      assert effect.name == "Some Name"
      assert effect.slug == "some_name_#{effect.id}"
    end

    test "find_or_create_effect/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sound.find_or_create_effect(@invalid_attrs)
    end

    test "update_or_create_effect/2" do
      {:ok, existing_effect} = Sound.create_effect(@valid_attrs)
      updated_attrs = Map.put(@valid_attrs, :zzfx_params, @other_zzfx_params)
      # finds existing template by slug and updates it
      assert {:ok, effect} = Sound.update_or_create_effect("some_name", updated_attrs)
      assert effect.id == existing_effect.id
      assert effect.zzfx_params == @other_zzfx_params

      # does not find the slug, but finds a matching tile for the other attrs
      assert {:ok, effect} = Sound.update_or_create_effect("thing2", updated_attrs)
      assert effect.id == existing_effect.id
      assert effect.slug == "some_name"

      # creates the unfound tile
      assert {:ok, effect} = Sound.update_or_create_effect("not", Map.merge(updated_attrs, %{name: "Big Z"}))
      assert effect.id != existing_effect.id
      assert effect.slug == "big_z"
    end

    test "update_or_create_effect!/2" do
      {:ok, existing_effect} = Sound.create_effect(@valid_attrs)
      updated_attrs = Map.put(@valid_attrs, :zzfx_params, @other_zzfx_params)
      # finds existing template by slug and updates it
      assert effect = Sound.update_or_create_effect!("some_name", updated_attrs)
      assert effect.id == existing_effect.id
      assert effect.zzfx_params == @other_zzfx_params

      # does not find the slug, but finds a matching tile for the other attrs
      assert effect = Sound.update_or_create_effect!("thing2", updated_attrs)
      assert effect.id == existing_effect.id
      assert effect.slug == "some_name"

      # creates the unfound tile
      assert effect = Sound.update_or_create_effect!("not", Map.merge(updated_attrs, %{name: "Big Z"}))
      assert effect.id != existing_effect.id
      assert effect.slug == "big_z"
    end

    test "delete_effect/1 deletes the effect" do
      effect = effect_fixture()
      assert {:ok, %Effect{}} = Sound.delete_effect(effect)
      assert_raise Ecto.NoResultsError, fn -> Sound.get_effect!(effect.id) end
    end

    test "change_effect/1 returns a effect changeset" do
      effect = effect_fixture()
      assert %Ecto.Changeset{} = Sound.change_effect(effect)
    end

    test  "copy_fields/1" do
      effect = effect_fixture()
      assert %{name: "Some Name",
               public: true,
               slug: "some_name",
               user_id: nil,
               zzfx_params: "[,0,130.8128,.1,.1,.34,3,1.88,,,,,,,,.1,,.5,.04]"} == Sound.copy_fields(effect)
    end
  end
end
