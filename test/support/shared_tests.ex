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

      @tag asset_key: unquote(asset_key), key: unquote(key), insert_asset_fn: unquote(insert_asset_fn), user_asset: true
      test "#{ unquote(asset_key) } - find when its owned by the user",
           %{export: export, user: user, dungeon_import: dungeon_import, asset: asset} do
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

      @tag asset_key: unquote(asset_key), key: unquote(key), insert_asset_fn: unquote(insert_asset_fn), public_asset: true
      test "#{ unquote(asset_key) } - find when its public",
           %{export: export, user: user, dungeon_import: dungeon_import, asset: asset} do
        updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)

        assert Map.drop(updated_export, [unquote(asset_key), :log]) == Map.drop(export, [unquote(asset_key), :log])
        assert %{unquote(asset_key) => %{unquote(key) => ^asset}, log: log} = updated_export

        # it logs
        log_prefix = "#{ unquote(key) } - #{ asset.slug } - #{ unquote(asset_key) }"
        assert Enum.member?(log, "= #{ log_prefix } - attributes matched asset with id: #{ asset.id }, slug: #{ asset.slug }")
      end

      @tag asset_key: unquote(asset_key), key: unquote(key), no_existing_asset: true
      test "#{ unquote(asset_key) } - creates when one exists but is not public nor owned by user",
           %{export: export, user: user, dungeon_import: dungeon_import, asset_from_import: asset_from_import} do
        updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)

        assert Map.drop(updated_export, [unquote(asset_key), :log]) == Map.drop(export, [unquote(asset_key), :log])
        assert %{unquote(asset_key) => %{unquote(key) => {:createable, asset, slug}}, log: log} = updated_export
        assert Map.drop(unquote(comparable_field_fn).(asset), [:active, :public, :script, :slug, :user_id]) ==
                 Map.drop(unquote(comparable_field_fn).(asset_from_import), [:active, :public, :script, :slug, :user_id])

        if unquote(asset_key) == :tile_templates do
          refute Map.get(asset, :public)
          assert asset.active
          # equipment must have a script
          assert asset.script == ""
          refute Map.has_key?(asset, :tmp_script)
        end
        assert asset.user_id == user.id

        # it logs
        log_prefix = "#{ unquote(key) } - #{ asset_from_import.slug } - #{ unquote(asset_key) }"
        assert Enum.member?(log, "- #{ log_prefix } - no match found, flagging asset as buildable: #{ inspect Map.take(asset_from_import, [:name, :description, :character]) }")
      end

      @tag asset_key: unquote(asset_key), key: unquote(key), insert_asset_fn: unquote(insert_asset_fn), existing_asset: true
      test "#{ unquote(asset_key) } - when exists with old slug and attributes are different creates asset_import",
           %{export: export, user: user, dungeon_import: dungeon_import, asset_from_import: asset_from_import} do
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

      @tag asset_key: unquote(asset_key), key: unquote(key), insert_asset_fn: unquote(insert_asset_fn), existing_asset: true
      test "#{ unquote(asset_key) } - when an asset import exists but is waiting does nothing",
           %{export: export, user: user, dungeon_import: dungeon_import, asset_from_import: asset_from_import, asset: asset, existing_attrs: existing_attrs} do
        existing_import = DungeonImports.create_asset_import!(dungeon_import.id, unquote(asset_key), unquote(key), asset.slug, asset_from_import, existing_attrs)

        updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)

        # An asset import looked up and unchanged
        assert Map.drop(updated_export, [unquote(asset_key), :log]) == Map.drop(export, [unquote(asset_key), :log])
        assert %{unquote(asset_key) => %{unquote(key) => nil}, log: log} = updated_export
        assert existing_import == DungeonImports.get_asset_import(dungeon_import.id, unquote(asset_key), unquote(key))

        # it logs
        log_prefix = "#{ unquote(key) } - #{ asset_from_import.slug } - #{ unquote(asset_key) }"
        assert Enum.member?(log, "? #{ log_prefix } - still waiting on user decision")
      end

      @tag asset_key: unquote(asset_key), key: unquote(key), insert_asset_fn: unquote(insert_asset_fn), existing_asset: true
      test "#{ unquote(asset_key) } - when an asset import exists and should use existing",
           %{export: export, user: user, dungeon_import: dungeon_import, asset_from_import: asset_from_import, asset: asset, existing_attrs: existing_attrs} do
        existing_import = DungeonImports.create_asset_import!(dungeon_import.id, unquote(asset_key), unquote(key), asset.slug, asset_from_import, existing_attrs)
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

      @tag asset_key: unquote(asset_key), key: unquote(key), insert_asset_fn: unquote(insert_asset_fn), existing_asset: true
      test "#{ unquote(asset_key) } - when an asset import exists and should update existing",
           %{export: export, user: user, dungeon_import: dungeon_import, asset_from_import: asset_from_import, asset: asset, existing_attrs: existing_attrs} do
        existing_import = DungeonImports.create_asset_import!(dungeon_import.id, unquote(asset_key), unquote(key), asset.slug, asset_from_import, existing_attrs)
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

      @tag asset_key: unquote(asset_key), key: unquote(key), insert_asset_fn: unquote(insert_asset_fn), others_existing_asset: true
      test "#{ unquote(asset_key) } - when an asset import exists and should update existing but user cannot update it",
           %{export: export, user: user, dungeon_import: dungeon_import, asset_from_import: asset_from_import, asset: asset, existing_attrs: existing_attrs} do
        existing_import = DungeonImports.create_asset_import!(dungeon_import.id, unquote(asset_key), unquote(key), asset.slug, asset_from_import, existing_attrs)
                          |> DungeonImports.update_asset_import!(%{action: :update_existing})

        updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)

        # Other export details unchanged
        assert Map.drop(updated_export, [unquote(asset_key), :log]) == Map.drop(export, [unquote(asset_key), :log])

        # updates the record and sets it in the map
        assert %{unquote(asset_key) => %{unquote(key) => nil}, log: log} = updated_export
        assert asset_import = DungeonImports.get_asset_import(dungeon_import.id, unquote(asset_key), unquote(key))
        assert asset_import.action == :waiting

        # it logs
        log_prefix = "#{ unquote(key) } - #{ asset_from_import.slug } - #{ unquote(asset_key) }"
        assert Enum.member?(log, "x #{ log_prefix } - cannot update asset, insufficient priviledges")
      end

      @tag asset_key: unquote(asset_key), key: unquote(key), insert_asset_fn: unquote(insert_asset_fn), existing_asset: true
      test "#{ unquote(asset_key) } - when an asset import exists and should create new",
           %{export: export, user: user, dungeon_import: dungeon_import, asset_from_import: asset_from_import, asset: asset, existing_attrs: existing_attrs} do
        existing_import = DungeonImports.create_asset_import!(dungeon_import.id, unquote(asset_key), unquote(key), asset.slug, asset_from_import, existing_attrs)
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

      @tag asset_key: unquote(asset_key), key: unquote(key), insert_asset_fn: unquote(insert_asset_fn), user_asset: true
      test "#{ unquote(asset_key) } - when an asset import exists and is resolved",
           %{export: export, user: user, dungeon_import: dungeon_import, asset_from_import: asset_from_import, asset: asset, existing_attrs: existing_attrs} do
        existing_import = DungeonImports.create_asset_import!(dungeon_import.id, unquote(asset_key), unquote(key), asset.slug, asset_from_import, existing_attrs)
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
        assert Enum.member?(log, "= #{ log_prefix } - attributes matched asset with id: #{ asset.id }, slug: #{ asset.slug } which was created or updated during this import")
      end

      @tag asset_key: unquote(asset_key), key: unquote(key), insert_asset_fn: unquote(insert_asset_fn), user_asset: true
      test "#{ unquote(asset_key) } - when an asset import exists and is resolved via create or update, but action was changed",
           %{export: export, user: user, dungeon_import: dungeon_import, asset_from_import: asset_from_import, asset: asset, existing_attrs: existing_attrs} do
        existing_import = DungeonImports.create_asset_import!(dungeon_import.id, unquote(asset_key), unquote(key), asset.slug, asset_from_import, existing_attrs)
                          |> DungeonImports.update_asset_import!(%{action: :create_new, resolved_slug: asset.slug})

        updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)

        assert Map.drop(updated_export, [unquote(asset_key), :log]) == Map.drop(export, [unquote(asset_key), :log])

        # updates the record and sets it in the map
        assert %{unquote(asset_key) => %{unquote(key) => ^asset}, log: log} = updated_export
        assert asset_import = DungeonImports.get_asset_import(dungeon_import.id, unquote(asset_key), unquote(key))
        assert asset_import.action == :resolved
        assert asset_import.resolved_slug == asset.slug

        # it logs
        log_prefix = "#{ unquote(key) } - #{ asset_from_import.slug } - #{ unquote(asset_key) }"
        assert Enum.member?(log, "= #{ log_prefix } - attributes matched asset with id: #{ asset.id }, slug: #{ asset.slug } which was created or updated during this import")
      end

      @tag asset_key: unquote(asset_key), key: unquote(key), insert_asset_fn: unquote(insert_asset_fn), existing_asset: true
      test "#{ unquote(asset_key) } - when an asset import exists and is resolved via use_existing, but action was changed",
           %{export: export, user: user, dungeon_import: dungeon_import, asset_from_import: asset_from_import, asset: asset, existing_attrs: existing_attrs} do
        existing_import = DungeonImports.create_asset_import!(dungeon_import.id, unquote(asset_key), unquote(key), asset.slug, asset_from_import, existing_attrs)
                          |> DungeonImports.update_asset_import!(%{action: :create_new, resolved_slug: asset.slug})

        updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)

        assert Map.drop(updated_export, [unquote(asset_key), :log]) == Map.drop(export, [unquote(asset_key), :log])

        # updates the asset import record to resolved, logs, and does not use the action
        assert %{unquote(asset_key) => %{unquote(key) => ^asset}, log: log} = updated_export
        assert asset_import = DungeonImports.get_asset_import(dungeon_import.id, unquote(asset_key), unquote(key))
        assert asset_import.action == :resolved
        assert asset_import.resolved_slug == asset.slug

        # it logs
        log_prefix = "#{ unquote(key) } - #{ asset_from_import.slug } - #{ unquote(asset_key) }"
        assert Enum.member?(log, "r #{ log_prefix } - use resolved asset with id: #{ asset.id } " <>
                                 "(expected it to have matched and not gotten here)")
      end

      @tag asset_key: unquote(asset_key), key: unquote(key), insert_asset_fn: unquote(insert_asset_fn), existing_asset: true
      test "#{ unquote(asset_key) } - when an asset import exists and is resolved but asset was changed",
           %{export: export, user: user, dungeon_import: dungeon_import, asset_from_import: asset_from_import, asset: asset, existing_attrs: existing_attrs} do
        existing_import = DungeonImports.create_asset_import!(dungeon_import.id, unquote(asset_key), unquote(key), asset.slug, asset_from_import, existing_attrs)
                          |> DungeonImports.update_asset_import!(%{action: :resolved, resolved_slug: asset.slug})

        updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)

        # Other export details unchanged
        assert Map.drop(updated_export, [unquote(asset_key), :log]) == Map.drop(export, [unquote(asset_key), :log])

        # returns the asset matching the resolved slug
        assert %{unquote(asset_key) => %{unquote(key) => found_asset}, log: log} = updated_export
        assert asset_import = DungeonImports.get_asset_import(dungeon_import.id, unquote(asset_key), unquote(key))
        assert asset_import.action == :resolved
        assert found_asset == asset
        assert asset_import.resolved_slug == asset.slug

        # it logs
        log_prefix = "#{ unquote(key) } - #{ asset_from_import.slug } - #{ unquote(asset_key) }"
        assert Enum.member?(log, "r #{ log_prefix } - use resolved asset with id: #{ asset.id } " <>
          "(expected it to have matched and not gotten here)")
      end

      # sounds do not have a script
      if unquote(asset_key) != :sounds do
        @tag asset_key: unquote(asset_key), key: unquote(key), script_asset: true, no_existing_asset: true
        test "#{ unquote(asset_key) } - created when asset has a script",
             %{export: export, user: user, dungeon_import: dungeon_import, asset: asset, attrs: attrs} do
          export = %{ export | unquote(asset_key) => %{unquote(key) => attrs} }
          updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)
          assert %{unquote(asset_key) => %{unquote(key) => {:createable, asset, slug}}} = updated_export
          assert asset.script == "test words\n#sound tmp_sound1\n#become slug: tmp_ttid_1"
        end

        @tag asset_key: unquote(asset_key), key: unquote(key), insert_asset_fn: unquote(insert_asset_fn), existing_asset: true
        test "#{ unquote(asset_key) } - fuzzed script for asset_import",
             %{export: export, user: user, dungeon_import: dungeon_import, asset: asset, attrs: attrs} do
          export = %{ export | unquote(asset_key) => %{unquote(key) => Map.put(attrs, :script, "test words\n#sound tmp_sound_1\n#equip tmp_item_1, ?sender\n#become slug: tmp_ttid_1")} }
          updated_export = find_or_create_assets(export, dungeon_import.id, unquote(asset_key), user)
          assert %{unquote(asset_key) => %{unquote(key) => asset}} = updated_export

          assert asset_import = DungeonImports.get_asset_import(dungeon_import.id, unquote(asset_key), unquote(key))
          assert asset_import.action == :waiting
          assert asset_import.attributes.script == "test words\n#sound tmp_sound_1\n#equip tmp_item_1, ?sender\n#become slug: tmp_ttid_1"
          assert asset_import.existing_attributes.script == "test"
          assert asset_import.attributes.fuzzed_script == "test words\n#sound <FUZZ>\n#equip <FUZZ>, ?sender\n#become slug: <FUZZ>"
          assert asset_import.existing_attributes.fuzzed_script == "test"
        end
      end
    end
  end
end
