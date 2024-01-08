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
      @tag asset_key: unquote(asset_key), key: unquote(key)
      test "#{ unquote(asset_key) } - find when its owned by the user", %{export: export} do
        user = insert_user()
        asset = unquote(insert_asset_fn).(
          Map.get(export, unquote(asset_key))[unquote(key)]
          |> Map.merge(%{user_id: user.id}))

        updated_export = find_or_create_assets(export, unquote(asset_key), user)

        # The other fields in the export are unchanged
        assert Map.delete(updated_export, unquote(asset_key)) == Map.delete(export, unquote(asset_key))
        # The assets are updated by replacing the attribute hash with the asset's
        # database record as the value associated with the temporary id key
        assert %{unquote(asset_key) => %{unquote(key) => ^asset}} = updated_export
      end

      @tag asset_key: unquote(asset_key), key: unquote(key)
      test "#{ unquote(asset_key) } - find when its public", %{export: export} do
        user = insert_user()
        asset = unquote(insert_asset_fn).(
          Map.get(export, unquote(asset_key))[unquote(key)]
          |> Map.merge(%{user_id: nil, public: true}))

        updated_export = find_or_create_assets(export, unquote(asset_key), user)

        assert Map.delete(updated_export, unquote(asset_key)) == Map.delete(export, unquote(asset_key))
        assert %{unquote(asset_key) => %{unquote(key) => ^asset}} = updated_export
      end

      @tag asset_key: unquote(asset_key), key: unquote(key)
      test "#{ unquote(asset_key) } - creates when one exists but is not public nor owned by user", %{export: export} do
        user = insert_user()
        attrs = Map.get(export, unquote(asset_key))[unquote(key)]

        updated_export = find_or_create_assets(export, unquote(asset_key), user)

        assert Map.delete(updated_export, unquote(asset_key)) == Map.delete(export, unquote(asset_key))
        assert %{unquote(asset_key) => %{unquote(key) => asset}} = updated_export
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
      end

      # sounds do not have a script
      if unquote(asset_key) != :sounds do
        @tag asset_key: unquote(asset_key), key: unquote(key)
        test "#{ unquote(asset_key) } - created when asset has a script", %{export: export} do
          user = insert_user()
          attrs = Map.merge(Map.get(export, unquote(asset_key))[unquote(key)], %{user_id: user.id, script: "test words"})
          export = %{ export | unquote(asset_key) => %{unquote(key) => attrs} }

          updated_export = find_or_create_assets(export, unquote(asset_key), user)

          assert %{unquote(asset_key) => %{unquote(key) => asset}} = updated_export

          assert asset.script == "#end" # placeholder, will be overwritten
          assert asset.tmp_script == attrs.script
        end
      end
    end
  end
end
