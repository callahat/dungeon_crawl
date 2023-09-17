defmodule DungeonCrawl.Shipping.DungeonImports do
  @moduledoc """
  The Dungeon Importer module. Its goal is to take an exported dungeon representation,
  generated by DungeonExports, and find or create all tile templates, sounds, and items, as
  well as the dungeon, its levels, and all the associated tiles. Temporary ID's and temporary
  slugs will be replaced with the proper found or created ones. If assets are created (since
  they did not exist or were not useable by the user running the import) they will be set
  to private and owned by the importing user.
  """

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Equipment.Item
  alias DungeonCrawl.Shipping.DungeonExports
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileTemplate
  alias DungeonCrawl.Sound

  use DungeonCrawl.Shipping.SlugMatching

  defstruct dungeon: nil,
            levels: %{},
            tiles: %{},
            items: %{},
            tile_templates: %{},
            sounds: %{}

  def run(%DungeonExports{} = export, user_id, line_identifier \\ nil) do
    export = find_or_create_assets(export, :sounds, &find_effect/2, &Sound.create_effect!/1, user_id)
             |> find_or_create_assets(:items, &find_item/2, &Equipment.create_item!/1, user_id)
             |> find_or_create_assets(:tile_templates, &find_tile_template/2, &TileTemplates.create_tile_template!/1, user_id)
             |> swap_scripts_to_tmp_scripts(:tiles)
             |> repoint_ttids_and_slugs(:tiles)
             |> repoint_ttids_and_slugs(:items)
             |> repoint_ttids_and_slugs(:tile_templates)
             |> repoint_dungeon_starting_items()
             |> set_dungeon_overrides(user_id, line_identifier)
             |> maybe_handle_previous_version()
             |> create_dungeon()
             |> create_levels()
             |> create_spawn_locations()
             |> complete_dungeon_import()

    export
  end

  # the script will never match due to the slug; so the script will need to be a "fuzzy" match
  # the fuzzy search, when candidates are found the slug in the candidate will need to be checked
  # to see if its a usable match for the given user; if not then asset(s) not match so a new one
  # will need created.
  defp find_or_create_assets(export, asset_key, find_asset, create_asset, user_id) do
    assets =
    Map.get(export, asset_key)
    |> Enum.map(fn {tmp_id, attrs} ->
         asset =
         with attrs = Map.drop(attrs, [:slug, :temp_tt_id, :temp_sound_id, :temp_item_id]),
              asset when is_nil(asset) <- find_asset.(user_id, Map.delete(attrs, :user_id)),
              attrs = Map.put(attrs, :user_id, user_id) |> Map.delete(:public),
              asset when is_nil(asset) <- find_asset.(user_id, attrs),
              attrs = Map.put(attrs, :active, true) do
           if Map.get(attrs, :script, "") != "" do
             create_asset.(Map.put(attrs, :script, "#end"))
             |> Map.put(:tmp_script, attrs.script)
           else
             create_asset.(attrs)
           end
         else
           asset ->
             asset
         end

      {tmp_id, asset}
    end)
    |> Enum.into(%{})

    %{ export | asset_key => assets }
  end

  defp find_effect(_user_id, attrs) do
    Sound.find_effect(attrs)
  end

  defp find_item(user_id, attrs) do
    Equipment.find_items(Map.delete(attrs, :script))
    |> useable_asset(attrs.script, user_id)
  end

  defp find_tile_template(user_id, attrs) do
    TileTemplates.find_tile_templates(Map.delete(attrs, :script))
    |> useable_asset(attrs.script, user_id)
  end

  defp useable_asset(assets, script, user_id) do
    Enum.filter(assets, fn asset -> script_fuzzer(asset.script) == script_fuzzer(script) end)
    |> Enum.find(fn asset -> all_slugs_useable?(asset.script, user_id) end)
  end

  defp script_fuzzer(script) do
    fuzz_script_slugs(script, @script_tt_slug)
    |> fuzz_script_slugs(@script_item_slug)
    |> fuzz_script_slugs(@script_sound_slug)
  end

  defp fuzz_script_slugs(script, slug_pattern) do
    slug_kwargs = Regex.scan(slug_pattern, script || "")

    Enum.reduce(slug_kwargs, script, fn [slug_kwarg], script ->
      [left_side, _slug] = String.split(slug_kwarg)
      String.replace(script, slug_kwarg, "#{left_side} fuzz")
    end)
  end

  defp all_slugs_useable?(script, user_id) do
    all_slugs_useable?(script, user_id, &TileTemplates.get_tile_template_by_slug/1, @script_tt_slug)
    && all_slugs_useable?(script, user_id, &Equipment.get_item/1, @script_item_slug)
    && all_slugs_useable?(script, user_id, &Sound.get_effect_by_slug/1, @script_sound_slug)
  end

  defp all_slugs_useable?(script, _user_id, slug_lookup, slug_pattern) do
    slug_kwargs = Regex.scan(slug_pattern, script)

    Enum.all?(slug_kwargs, fn [slug_kwarg] ->
      [_, slug] = String.split(slug_kwarg)

      case slug_lookup.(slug) do
        nil -> false
        _asset -> true # asset.public || asset.user_id == user_id - maybe put this back if slug authorization is added
      end
    end)
  end

  defp repoint_ttids_and_slugs(export, asset_key) do
    assets = Enum.map(Map.get(export, asset_key), fn {th, asset} ->
               {
                 th,
                 repoint_tile_template_id(asset, export)
                 |> repoint_script_slugs(export, :tile_templates, @script_tt_slug)
                 |> repoint_script_slugs(export, :items, @script_item_slug)
                 |> repoint_script_slugs(export, :sounds, @script_sound_slug)
                 |> swap_tmp_script()
               }
             end)
             |> Enum.into(%{})

    %{ export | asset_key => assets }
  end

  defp repoint_tile_template_id(%{tile_template_id: tile_template_id} = asset, export) do
    template = Map.get(export.tile_templates, tile_template_id, %{id: nil})
    Map.put(asset, :tile_template_id, template.id)
  end
  defp repoint_tile_template_id(asset, _export), do: asset

  defp repoint_script_slugs(asset, export, slug_type, slug_pattern) do
    slug_kwargs = Regex.scan(slug_pattern, Map.get(asset, :tmp_script) || "")

    Enum.reduce(slug_kwargs, asset, fn [slug_kwarg], %{tmp_script: _tmp_script} = asset ->
      [left_side, tmp_slug] = String.split(slug_kwarg)

      referenced_asset = Map.fetch!(export, slug_type) |> Map.fetch!(tmp_slug)
      Map.put(asset, :tmp_script, String.replace(Map.fetch!(asset, :tmp_script), slug_kwarg, "#{left_side} #{referenced_asset.slug}"))
    end)
  end

  defp swap_scripts_to_tmp_scripts(export, asset_key) do
    assets = Enum.map(Map.get(export, asset_key), fn {th, asset} ->
      {
        th,
        Map.put(asset, :tmp_script, asset.script)
      }
    end)
    |> Enum.into(%{})

    %{ export | asset_key => assets }
  end

  defp swap_tmp_script(%{__struct__: TileTemplate, tmp_script: tmp_script} = asset) do
    {:ok, asset} = TileTemplates.update_tile_template(asset, %{script: tmp_script})
    asset
  end

  defp swap_tmp_script(%{__struct__: Item, tmp_script: tmp_script} = asset) do
    {:ok, asset} = Equipment.update_item(asset, %{script: tmp_script})
    asset
  end

  defp swap_tmp_script(%{tmp_script: tmp_script} = asset) do
    Map.put(asset, :script, tmp_script)
  end

  defp swap_tmp_script(asset) do
    asset
  end

  defp repoint_dungeon_starting_items(%{dungeon: dungeon} = export) do
    case export.dungeon.state do
      %{starting_equipment: equipment} = dungeon_state ->
        starting_equipment =
          equipment
          |> Enum.map(fn tmp_slug ->
            export.items[tmp_slug].slug end)

        dungeon = %{ dungeon | state: %{dungeon_state | starting_equipment: starting_equipment}}
        %{ export | dungeon: dungeon }
      _ ->
        export
    end
  end

  defp set_dungeon_overrides(export, user_id, "") do
    set_dungeon_overrides(export, user_id, nil)
  end

  defp set_dungeon_overrides(%{dungeon: dungeon} = export, user_id, line_identifier) do
    dungeon = Map.merge(dungeon, %{user_id: user_id, line_identifier: line_identifier, importing: true})
              |> Map.delete(:user_name)
    %{ export | dungeon: dungeon }
  end

  defp maybe_handle_previous_version(%{dungeon: dungeon} = export) do
    prev_version = Dungeons.get_newest_dungeons_version(export.dungeon.line_identifier, export.dungeon.user_id)

    cond do
      is_nil(prev_version) ->
        %{ export | dungeon: Map.put(dungeon, :line_identifier, nil) }

      prev_version.active ->
        attrs = %{version: prev_version.version + 1, active: false, previous_version_id: prev_version.id}
        %{ export | dungeon: Map.merge(dungeon, attrs) }

      true ->
        attrs = %{version: prev_version.version, active: false, previous_version_id: prev_version.previous_version_id}
        Dungeons.hard_delete_dungeon!(prev_version)
        %{ export | dungeon: Map.merge(dungeon, attrs) }
    end
  end

  defp create_dungeon(%{dungeon: dungeon} = export) do
    {:ok, dungeon} = Dungeons.create_dungeon(dungeon)
    %{ export | dungeon: dungeon }
  end

  defp create_levels(%{levels: levels} = export) do
    Map.values(levels)
    |> create_levels(export)
  end

  defp create_levels([], export), do: export
  defp create_levels([level | levels], export) do
    {:ok, level_record} = Dungeons.create_level(Map.put(level, :dungeon_id, export.dungeon.id))
    create_tiles(level.tile_data, level_record.id, export)
    export = %{ export | levels: %{ export.levels | level.number => Map.put(level_record, :tile_data, level.tile_data) } }
    create_levels(levels, export)
  end

  defp create_tiles([], _level_id, export), do: export
  defp create_tiles([[tile_hash, row, col, z_index] | tile_hashes], level_id, export) do
    tile_attrs = export.tiles[tile_hash]

    {:ok, _tile} = Map.merge(tile_attrs, %{level_id: level_id, row: row, col: col, z_index: z_index})
                   |> Dungeons.create_tile()

    create_tiles(tile_hashes, level_id, export)
  end

  defp create_spawn_locations(export) do
    export.spawn_locations
    |> Enum.group_by(fn [num, _row, _col] -> num end)
    |> Enum.each(fn {num, coords} ->
         level_id = export.levels[num].id
         coords = Enum.reduce(coords, [], fn [_num, row, col], acc -> [{row, col} | acc] end)
         Dungeons.add_spawn_locations(level_id, coords)
       end)

    export
  end

  def complete_dungeon_import(%{dungeon: dungeon} = export) do
    {:ok, dungeon} = Dungeons.update_dungeon(dungeon, %{importing: false})
    %{ export | dungeon: dungeon }
  end
end
