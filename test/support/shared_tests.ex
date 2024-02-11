defmodule DungeonCrawl.SharedTests do
  defmacro handles_state_variables_and_values_correctly(module) do
    quote do
      test "changeset with state_variables and state_values virtual fields" do
        # state_variables and state_values will override state if they're well formed
        state = "foo: bar"
        bad_attrs = %{state_variables: ["one", "two"], state_values: ["1"]}
        good_attrs = %{state_variables: ["one", "two"], state_values: ["1", "2"]}
        # when invalid state_variables/values, keeps them in the changeset
        # lopsided
        changeset = unquote(module).changeset(%unquote(module){state: state}, bad_attrs)
        assert changeset.changes == bad_attrs
        assert changeset.errors[:state] == {"state_variables and state_values are of different lengths", []}
        # missing
        changeset = unquote(module).changeset(%unquote(module){state: state}, Map.delete(good_attrs, :state_variables))
        assert changeset.errors[:state_variables] == {"must be present and have same number of elements as state_values", []}
        changeset = unquote(module).changeset(%unquote(module){state: state}, Map.delete(good_attrs, :state_values))
        assert changeset.errors[:state_values] == {"must be present and have same number of elements as state_variables", []}
        # good attrs, state_variables and state_values virtual fields are deleted and state is added to the changeset
        changeset = unquote(module).changeset(%unquote(module){state: state}, good_attrs)
        assert changeset.changes == %{state: %{"one" => 1, "two" => 2}}
        refute changeset.errors[:state_variables]
        refute changeset.errors[:state_values]
        refute changeset.errors[:state]
      end
    end
  end

  # There are three invocations of this function, all of them are very similar in their operation,
  # hence shared tests. There are a few slight differences depending on which asset is operated on
  # which have been noted in comments.
  defmacro finds_or_creates_assets_correctly(asset_key, key, insert_asset_fn, comparable_field_fn) do
    quote do
      alias DungeonCrawl.Shipping
      alias DungeonCrawl.Shipping.DungeonImports

      setup config do
        user = insert_user()
        Map.merge(config, %{user: user})
      end

      @tag asset_key: unquote(asset_key), key: unquote(key)
      test "#{ unquote(asset_key) } - find when its owned by the user", %{export: export} do
        user = insert_user()
        asset = unquote(insert_asset_fn).(
          Map.get(export, unquote(asset_key))[unquote(key)]
          |> Map.merge(%{user_id: user.id}))
        dungeon_import = Shipping.create_import!(%{data: "{}", user_id: user.id, file_name: "x.json"})

        updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)

        # The other fields in the export are unchanged
        assert Map.drop(updated_export, [unquote(asset_key), :log]) == Map.drop(export, [unquote(asset_key), :log])
        # The assets are updated by replacing the attribute hash with the asset's
        # database record as the value associated with the temporary id key
        assert %{unquote(asset_key) => %{unquote(key) => ^asset}, log: log} = updated_export

        # it logs
        log_prefix = "#{ unquote(key) } - #{ asset.slug } - #{ unquote(asset_key) }"
        assert Enum.member?(log, "= #{ log_prefix } - attributes matched asset with id: #{ asset.id }, slug: #{ asset.slug }")
      end

      @tag asset_key: unquote(asset_key), key: unquote(key)
      test "#{ unquote(asset_key) } - find when its public", %{export: export} do
        user = insert_user()
        asset = unquote(insert_asset_fn).(
          Map.get(export, unquote(asset_key))[unquote(key)]
          |> Map.merge(%{user_id: nil, public: true}))
        dungeon_import = Shipping.create_import!(%{data: "{}", user_id: user.id, file_name: "x.json"})

        updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)

        assert Map.drop(updated_export, [unquote(asset_key), :log]) == Map.drop(export, [unquote(asset_key), :log])
        assert %{unquote(asset_key) => %{unquote(key) => ^asset}, log: log} = updated_export

        # it logs
        log_prefix = "#{ unquote(key) } - #{ asset.slug } - #{ unquote(asset_key) }"
        assert Enum.member?(log, "= #{ log_prefix } - attributes matched asset with id: #{ asset.id }, slug: #{ asset.slug }")
      end

      @tag asset_key: unquote(asset_key), key: unquote(key)
      test "#{ unquote(asset_key) } - creates when one exists but is not public nor owned by user", %{export: export} do
        user = insert_user()
        attrs = Map.get(export, unquote(asset_key))[unquote(key)]
        dungeon_import = Shipping.create_import!(%{data: "{}", user_id: user.id, file_name: "x.json"})

        updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)

        assert Map.drop(updated_export, [unquote(asset_key), :log]) == Map.drop(export, [unquote(asset_key), :log])
        assert %{unquote(asset_key) => %{unquote(key) => asset}, log: log} = updated_export
        assert Map.drop(unquote(comparable_field_fn).(asset), [:active, :public, :script, :slug, :user_id]) ==
                 Map.drop(unquote(comparable_field_fn).(attrs), [:active, :public, :script, :slug, :user_id])

        if unquote(asset_key) == :tile_templates, do: assert asset.active
        refute asset.public
        assert asset.slug =~ if unquote(asset_key) == :jk,
                                do: ~r/^#{ attrs.slug }$/,
                                else: ~r/#{ attrs.slug }_\d+/
        if unquote(asset_key) == :tile_templates do
          # equipment must have a script
          assert asset.script == ""
          refute Map.has_key?(asset, :tmp_script)
        end
        assert asset.user_id == user.id

        # it logs
        log_prefix = "#{ unquote(key) } - #{ attrs.slug } - #{ unquote(asset_key) }"
        assert Enum.member?(log, "+ #{ log_prefix } - no match found, created asset with id: #{ asset.id }, slug: #{ asset.slug }")
      end

      @tag asset_key: unquote(asset_key), key: unquote(key)
      test "#{ unquote(asset_key) } - when exists with old slug and attributes are different creates asset_import",
           %{export: export, user: user} do
#        user = insert_user()
        asset_from_import = Map.get(export, unquote(asset_key))[unquote(key)]
        asset = unquote(insert_asset_fn).(asset_from_import
                                         |> Map.merge(%{user_id: user.id, slug: asset_from_import.slug, name: "Updated - common field"}))
        dungeon_import = Shipping.create_import!(%{data: "{}", user_id: user.id, file_name: "x.json"})

        # An asset import is created with waiting action
        updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)
        assert Map.drop(updated_export, [unquote(asset_key), :log]) == Map.drop(export, [unquote(asset_key), :log])
        assert %{unquote(asset_key) => %{unquote(key) => nil}, log: log} = updated_export
        assert asset_import = DungeonImports.get_asset_import(dungeon_import.id, unquote(asset_key), unquote(key))
        existing_slug = asset_from_import.slug
        user_id = user.id
        assert %{
                 existing_slug: ^existing_slug,
                 importing_slug: unquote(key),
                 action: :waiting,
               } = asset_import

        # it logs
        log_prefix = "#{ unquote(key) } - #{ asset_from_import.slug } - #{ unquote(asset_key) }"
        assert Enum.member?(log, "? #{ log_prefix } - asset exists by slug, creating asset import record for user action choice")
      end

      @tag asset_key: unquote(asset_key), key: unquote(key)
      test "#{ unquote(asset_key) } - when an asset import exists but is waiting does nothing",
           %{export: export} do
        user = insert_user()
        asset_from_import = Map.get(export, unquote(asset_key))[unquote(key)]
        asset = unquote(insert_asset_fn).(asset_from_import
                                          |> Map.merge(%{user_id: user.id, slug: asset_from_import.slug, name: "Old - common field"}))
        dungeon_import = Shipping.create_import!(%{data: "{}", user_id: user.id, file_name: "x.json"})

        existing_import = DungeonImports.create_asset_import!(dungeon_import.id, unquote(asset_key), unquote(key), asset.slug, asset_from_import)
        attributes_with_string_keys = existing_import.attributes
                                      |> Enum.map( fn {k, v} -> {to_string(k), v} end)
                                      |> Enum.into(%{})
        existing_import = %{ existing_import | attributes: attributes_with_string_keys }

        updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)

        # An asset import looked up and unchanged
        assert Map.drop(updated_export, [unquote(asset_key), :log]) == Map.drop(export, [unquote(asset_key), :log])
        assert %{unquote(asset_key) => %{unquote(key) => nil}, log: log} = updated_export
        assert existing_import == DungeonImports.get_asset_import(dungeon_import.id, unquote(asset_key), unquote(key))

        # it logs
        log_prefix = "#{ unquote(key) } - #{ asset_from_import.slug } - #{ unquote(asset_key) }"
        assert Enum.member?(log, "? #{ log_prefix } - waiting on user decision")
      end

      @tag asset_key: unquote(asset_key), key: unquote(key)
      test "#{ unquote(asset_key) } - when an asset import exists and should use existing",
           %{export: export} do
        user = insert_user()
        asset_from_import = Map.get(export, unquote(asset_key))[unquote(key)]
        asset = unquote(insert_asset_fn).(Map.merge(asset_from_import, %{user_id: user.id, slug: asset_from_import.slug, name: "Use existing"}))
        dungeon_import = Shipping.create_import!(%{data: "{}", user_id: user.id, file_name: "x.json"})

        existing_import = DungeonImports.create_asset_import!(dungeon_import.id, unquote(asset_key), unquote(key), asset.slug, asset_from_import)
                          |> DungeonImports.update_asset_import!(%{action: :use_existing})

        updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)

        # Other export details unchanged
        assert Map.drop(updated_export, [unquote(asset_key), :log]) == Map.drop(export, [unquote(asset_key), :log])

        # gets the record and uses it in the map
        assert %{unquote(asset_key) => %{unquote(key) => ^asset}, log: log} = updated_export
        assert asset_import = DungeonImports.get_asset_import(dungeon_import.id, unquote(asset_key), unquote(key))
        assert asset_import.action == :resolved
        assert asset_import.resolved_slug == asset.slug

        # it logs
        log_prefix = "#{ unquote(key) } - #{ asset_from_import.slug } - #{ unquote(asset_key) }"
        assert Enum.member?(log, ". #{ log_prefix } - use existing asset with id: #{ asset.id }")
      end

      @tag asset_key: unquote(asset_key), key: unquote(key)
      test "#{ unquote(asset_key) } - when an asset import exists and should update existing", %{export: export} do
        user = insert_user()
        asset_from_import = Map.get(export, unquote(asset_key))[unquote(key)]
        asset = unquote(insert_asset_fn).(asset_from_import
                                          |> Map.merge(%{user_id: user.id, slug: asset_from_import.slug, name: "Old - common field"}))
        dungeon_import = Shipping.create_import!(%{data: "{}", user_id: user.id, file_name: "x.json"})

        existing_import = DungeonImports.create_asset_import!(dungeon_import.id, unquote(asset_key), unquote(key), asset.slug, asset_from_import)
                          |> DungeonImports.update_asset_import!(%{action: :update_existing})

        updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)

        # Other export details unchanged
        assert Map.drop(updated_export, [unquote(asset_key), :log]) == Map.drop(export, [unquote(asset_key), :log])

        # updates the record and sets it in the map
        assert %{unquote(asset_key) => %{unquote(key) => updated_asset}, log: log} = updated_export
        assert asset_import = DungeonImports.get_asset_import(dungeon_import.id, unquote(asset_key), unquote(key))
        assert asset_import.action == :resolved
        assert updated_asset.id == asset.id
        assert updated_asset.name != asset.name # this was updated
        assert updated_asset.name == asset_from_import.name

        # it logs
        log_prefix = "#{ unquote(key) } - #{ asset_from_import.slug } - #{ unquote(asset_key) }"
        assert Enum.member?(log, "u #{ log_prefix } - update existing asset with id: #{ asset.id }")
      end

      @tag asset_key: unquote(asset_key), key: unquote(key)
      test "#{ unquote(asset_key) } - when an asset import exists and should create new", %{export: export} do
        user = insert_user()
        asset_from_import = Map.get(export, unquote(asset_key))[unquote(key)]
        asset = unquote(insert_asset_fn).(asset_from_import
                                          |> Map.merge(%{user_id: user.id, slug: asset_from_import.slug, name: "slightly different"}))
        dungeon_import = Shipping.create_import!(%{data: "{}", user_id: user.id, file_name: "x.json"})

        existing_import = DungeonImports.create_asset_import!(dungeon_import.id, unquote(asset_key), unquote(key), asset.slug, asset_from_import)
                          |> DungeonImports.update_asset_import!(%{action: :create_new})

        updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)

        # Other export details unchanged
        assert Map.drop(updated_export, [unquote(asset_key), :log]) == Map.drop(export, [unquote(asset_key), :log])

        # creates the record and sets it in the map
        assert %{unquote(asset_key) => %{unquote(key) => new_asset}, log: log} = updated_export
        assert asset_import = DungeonImports.get_asset_import(dungeon_import.id, unquote(asset_key), unquote(key))

        assert asset_import.action == :resolved
        assert asset_import.resolved_slug =~ ~r/#{ asset.slug }_\d+/
        assert new_asset.slug == asset_import.resolved_slug
        assert new_asset.id != asset.id
        assert new_asset.name == asset_from_import.name

        # it logs
        log_prefix = "#{ unquote(key) } - #{ asset_from_import.slug } - #{ unquote(asset_key) }"
        assert Enum.member?(log, "+ #{ log_prefix } - created asset with id: #{ new_asset.id }")
      end

      @tag asset_key: unquote(asset_key), key: unquote(key)
      test "#{ unquote(asset_key) } - when an asset import exists and is resolved", %{export: export} do
        user = insert_user()
        asset_from_import = Map.get(export, unquote(asset_key))[unquote(key)]
        asset = unquote(insert_asset_fn).(Map.merge(asset_from_import, %{user_id: user.id}))

        dungeon_import = Shipping.create_import!(%{data: "{}", user_id: user.id, file_name: "x.json"})

        existing_import = DungeonImports.create_asset_import!(dungeon_import.id, unquote(asset_key), unquote(key), asset.slug, asset_from_import)
                          |> DungeonImports.update_asset_import!(%{action: :resolved, resolved_slug: asset.slug})

        updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)

        assert Map.drop(updated_export, [unquote(asset_key), :log]) == Map.drop(export, [unquote(asset_key), :log])

        # updates the record and sets it in the map
        assert %{unquote(asset_key) => %{unquote(key) => ^asset}, log: log} = updated_export
        assert asset_import = DungeonImports.get_asset_import(dungeon_import.id, unquote(asset_key), unquote(key))
        assert asset_import.action == :resolved
        assert asset_import.resolved_slug == asset.slug

        # it logs
        log_prefix = "#{ unquote(key) } - #{ asset_from_import.slug } - #{ unquote(asset_key) }"
        assert Enum.member?(log, "= #{ log_prefix } - attributes matched asset with id: #{ asset.id }, slug: #{ asset.slug }")
      end

      @tag asset_key: unquote(asset_key), key: unquote(key)
      test "#{ unquote(asset_key) } - when an asset import exists and is resolved but asset was changed", %{export: export} do
        user = insert_user()
        asset_from_import = Map.get(export, unquote(asset_key))[unquote(key)]
        asset = unquote(insert_asset_fn).(Map.merge(asset_from_import, %{user_id: user.id, slug: asset_from_import.slug, name: "slightly different"}))

        resolved_asset = unquote(insert_asset_fn).(Map.merge(asset_from_import, %{user_id: user.id, slug: "resolved_test", name: "resolved"}))
        dungeon_import = Shipping.create_import!(%{data: "{}", user_id: user.id, file_name: "x.json"})

        existing_import = DungeonImports.create_asset_import!(dungeon_import.id, unquote(asset_key), unquote(key), asset.slug, asset_from_import)
                          |> DungeonImports.update_asset_import!(%{action: :resolved, resolved_slug: resolved_asset.slug})

        updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)

        # Other export details unchanged
        assert Map.drop(updated_export, [unquote(asset_key), :log]) == Map.drop(export, [unquote(asset_key), :log])

        # returns the asset matching the resolved slug
        assert %{unquote(asset_key) => %{unquote(key) => found_asset}, log: log} = updated_export
        assert asset_import = DungeonImports.get_asset_import(dungeon_import.id, unquote(asset_key), unquote(key))
        assert asset_import.action == :resolved
        assert found_asset == resolved_asset
        assert asset_import.resolved_slug == resolved_asset.slug

        # it logs
        log_prefix = "#{ unquote(key) } - #{ asset_from_import.slug } - #{ unquote(asset_key) }"
        assert Enum.member?(log, "r #{ log_prefix } - use resolved asset with id: #{ resolved_asset.id } " <>
          "(expected it to have matched and not gotten here)")
      end

      # sounds do not have a script
      if unquote(asset_key) != :sounds do
        @tag asset_key: unquote(asset_key), key: unquote(key)
        test "#{ unquote(asset_key) } - created when asset has a script", %{export: export} do
          user = insert_user()
          attrs = Map.merge(Map.get(export, unquote(asset_key))[unquote(key)], %{user_id: user.id, script: "test words"})
          export = %{ export | unquote(asset_key) => %{unquote(key) => attrs} }
          dungeon_import = Shipping.create_import!(%{data: "{}", user_id: user.id, file_name: "x.json"})

          updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)

          assert %{unquote(asset_key) => %{unquote(key) => asset}} = updated_export

          assert asset.script == "#end" # placeholder, will be overwritten
          assert asset.tmp_script == attrs.script
        end
      end
    end
  end
end
