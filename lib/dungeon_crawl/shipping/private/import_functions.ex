defmodule DungeonCrawl.Shipping.Private.ImportFunctions do
  @moduledoc """
  This module contains publicly callable functions used when importing
  a dungeon. These are not meant to be called directly, but have been
  moved to their own module as public functions to help with debugging
  and isolating each step so more discrete tests can be added.
  """

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Equipment.Item
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileTemplate
  alias DungeonCrawl.Shipping.DungeonImports
  alias DungeonCrawl.Sound

  use DungeonCrawl.Shipping.SlugMatching

  # the script will never match due to the slug; so the script will need to be a "fuzzy" match
  # the fuzzy search, when candidates are found the slug in the candidate will need to be checked
  # to see if its a usable match for the given user; if not then asset(s) not match so a new one
  # will need created.
  def find_or_create_assets(export, import_id, asset_key, user) do
    assets =
      Map.get(export, asset_key)
      |> Enum.map(fn {tmp_slug, attrs} ->
        asset = find_or_create_asset(import_id, asset_key, attrs, tmp_slug, user)

        {tmp_slug, asset}
      end)
      |> Enum.into(%{})

    %{ export | asset_key => assets }
  end

  # This will have a aside affect of creating an asset_import record potentially
  defp find_or_create_asset(import_id, asset_key, attrs, tmp_slug, user) do
    with slug = attrs[:slug],
         attrs = Map.drop(attrs, [:slug, :temp_tt_id, :temp_sound_id, :temp_item_id]),
         asset when is_nil(asset) <- find_asset(asset_key, Map.delete(attrs, :user_id), user),
         attrs = Map.put(attrs, :user_id, user.id) |> Map.delete(:public),
         asset when is_nil(asset) <- find_asset(asset_key, attrs, user),
         attrs = Map.put(attrs, :active, true) do
      # at this point, the match on attributes failed
      # this if/else will change
      # 1. if there is no entry in the asset_import table, create one,
      #    a. check if there is an existing asset with the original slug
      # 2. if there is an entry with action that is not matched, skip
      # 3. if a create or update action, do so, mark as resolved and updated resolved slug
      # 4. if it is resolved, then return the asset
      # some of this could probably be done in the with statement
      asset_import = DungeonImports.get_asset_import(import_id, asset_key, tmp_slug)

      if asset_import do
        case asset_import.action do
          :waiting ->
            nil
          :create_new ->
            asset = create_asset(asset_key, attrs)
            DungeonImports.update_asset_import!(asset_import, %{action: :resolved, resolved_slug: asset.slug})
            asset
          :use_existing ->
            DungeonImports.update_asset_import!(asset_import, %{action: :resolved, resolved_slug: slug})
            find_asset(asset_key, slug, user)
          :update_existing ->
            # todo: make sure user can only do this if owner of asset or admin, probably just need a spec
            existing_by_slug = find_asset(asset_key, slug, user)
            attributes = Enum.map(asset_import.attributes, fn {k, v} -> {String.to_existing_atom(k), v} end)
                         |> Enum.into(%{})
            asset = existing_by_slug &&
              update_asset(asset_key, existing_by_slug, attributes)
            DungeonImports.update_asset_import!(asset_import, %{action: :resolved, resolved_slug: slug})
            asset
          :resolved ->
            # this will likely not happen unless the asset is changed after resolution
            find_asset(asset_key, asset_import.resolved_slug, user)
        end
      else
        existing_by_slug = find_asset(asset_key, slug, user)
        if existing_by_slug do
          DungeonImports.create_asset_import!(import_id, asset_key, tmp_slug, slug, attrs)
          nil

        else
          create_asset(asset_key, attrs)
        end
      end
    else
      asset ->
        asset
    end
  end

  # find by slug
  def find_asset(:sounds, slug, user) when is_binary(slug) do
    Sound.get_effect(slug, user)
  end

  def find_asset(:items, slug, user) when is_binary(slug) do
    Equipment.get_item(slug, user)
  end

  def find_asset(:tile_templates, slug, user) when is_binary(slug) do
    TileTemplates.get_tile_template(slug, user)
  end

  # find by attributes
  def find_asset(:sounds, attrs, _user) do
    Sound.find_effect(attrs)
  end

  def find_asset(:items, attrs, user) do
    Equipment.find_items(Map.delete(attrs, :script))
    |> useable_asset(attrs.script, user.id)
  end

  def find_asset(:tile_templates, attrs, user) do
    TileTemplates.find_tile_templates(Map.drop(attrs, [:state, :script]))
    |> Enum.filter(fn tt -> tt.state == attrs.state end)
    |> useable_asset(attrs.script, user.id)
  end

  defp useable_asset(assets, script, user_id) do
    Enum.filter(assets, fn asset -> script_fuzzer(asset.script) == script_fuzzer(script) end)
    |> Enum.find(fn asset -> all_slugs_useable?(asset.script, user_id) end)
  end

  def script_fuzzer(script) do
    fuzz_script_slugs(script, @script_tt_slug)
    |> fuzz_script_slugs(@script_item_slug)
    |> fuzz_script_slugs(@script_sound_slug)
  end

  defp fuzz_script_slugs(script, slug_pattern) do
    slug_kwargs = Regex.scan(slug_pattern, script || "")

    Enum.reduce(slug_kwargs, script, fn [slug_kwarg], script ->
      [left_side, _slug] = String.split(slug_kwarg)
      String.replace(script, slug_kwarg, "#{left_side} <FUZZ>")
    end)
  end

  def all_slugs_useable?(script, user_id) do
    all_slugs_useable?(script, user_id, &TileTemplates.get_tile_template/1, @script_tt_slug)
    && all_slugs_useable?(script, user_id, &Equipment.get_item/1, @script_item_slug)
    && all_slugs_useable?(script, user_id, &Sound.get_effect_by_slug/1, @script_sound_slug)
  end

  defp all_slugs_useable?(nil, _user_id, _slug_lookup, _slug_pattern), do: true
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

  def create_asset(:sounds, attrs) do
    _create_and_maybe_inject_tmp_script(attrs, &Sound.create_effect!/1)
  end

  def create_asset(:items, attrs) do
    _create_and_maybe_inject_tmp_script(attrs, &Equipment.create_item!/1)
  end

  def create_asset(:tile_templates, attrs) do
    _create_and_maybe_inject_tmp_script(attrs, &TileTemplates.create_tile_template!/1)
  end

  # todo: add or use the ! func for these
  def update_asset(:sounds, sound, attrs) do
    _update_and_maybe_inject_tmp_script(sound, attrs, &Sound.update_effect/2)
  end

  def update_asset(:items, item, attrs) do
    _update_and_maybe_inject_tmp_script(item, attrs, &Equipment.update_item/2)
  end

  def update_asset(:tile_templates, tt, attrs) do
    _update_and_maybe_inject_tmp_script(tt, attrs, &TileTemplates.update_tile_template/2)
  end

  defp _update_and_maybe_inject_tmp_script(asset, attrs, update_fn) do
    attrs = Map.drop(attrs, [:user_id])

    if Map.get(attrs, :script, "") != "" do
      {:ok, asset} = update_fn.(asset, Map.put(attrs, :script, "#end"))
      Map.put(asset, :tmp_script, attrs.script)
    else
      {:ok, asset} = update_fn.(asset, attrs)
      asset
    end
  end

  defp _create_and_maybe_inject_tmp_script(attrs, create_fn) do
    if Map.get(attrs, :script, "") != "" do
      create_fn.(Map.put(attrs, :script, "#end"))
      |> Map.put(:tmp_script, attrs.script)
    else
      create_fn.(attrs)
    end
  end

  def swap_scripts_to_tmp_scripts(%{status: "running"} = export, asset_key) do
    assets = Enum.map(Map.get(export, asset_key), fn {th, asset} ->
      {
        th,
        Map.put(asset, :tmp_script, asset.script)
      }
    end)
             |> Enum.into(%{})

    %{ export | asset_key => assets }
  end
  def swap_scripts_to_tmp_scripts(export, _asset_key), do: export

  def repoint_ttids_and_slugs(%{status: "running"} = export, asset_key) do
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
  def repoint_ttids_and_slugs(export, _asset_key), do: export

  def repoint_tile_template_id(%{tile_template_id: tile_template_id} = asset, export) do
    template = Map.get(export.tile_templates, tile_template_id, %{id: nil})
    Map.put(asset, :tile_template_id, template.id)
  end
  def repoint_tile_template_id(asset, _export), do: asset

  defp repoint_script_slugs(asset, export, slug_type, slug_pattern) do
    slug_kwargs = Regex.scan(slug_pattern, Map.get(asset, :tmp_script) || "")

    Enum.reduce(slug_kwargs, asset, fn [slug_kwarg], %{tmp_script: _tmp_script} = asset ->
      [left_side, tmp_slug] = String.split(slug_kwarg)

      referenced_asset = Map.fetch!(export, slug_type) |> Map.fetch!(tmp_slug)
      Map.put(asset, :tmp_script, String.replace(Map.fetch!(asset, :tmp_script), slug_kwarg, "#{left_side} #{referenced_asset.slug}"))
    end)
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

  def repoint_dungeon_starting_items(%{status: "running", dungeon: dungeon} = export) do
    case export.dungeon.state do
      %{"starting_equipment" => equipment} = dungeon_state ->
        starting_equipment =
          equipment
          |> Enum.map(fn tmp_slug ->
            export.items[tmp_slug].slug end)

        dungeon = %{ dungeon | state: %{dungeon_state | "starting_equipment" => starting_equipment}}
        %{ export | dungeon: dungeon }
      _ ->
        export
    end
  end
  def repoint_dungeon_starting_items(export), do: export

  def set_dungeon_overrides(%{status: "running"} = export, user_id, "") do
    set_dungeon_overrides(export, user_id, nil)
  end
  def set_dungeon_overrides(%{status: "running", dungeon: dungeon} = export, user_id, line_identifier) do
    dungeon = Map.merge(dungeon, %{user_id: user_id, line_identifier: line_identifier, importing: true})
              |> Map.delete(:user_name)
    %{ export | dungeon: dungeon }
  end
  def set_dungeon_overrides(export, _user_id, _line_identifier), do: export

  def maybe_handle_previous_version(%{status: "running", dungeon: dungeon} = export) do
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
  def maybe_handle_previous_version(export), do: export

  def create_dungeon(%{status: "running", dungeon: dungeon} = export) do
    {:ok, dungeon} = Dungeons.create_dungeon(dungeon)
    %{ export | dungeon: dungeon }
  end
  def create_dungeon(export), do: export

  def create_levels(%{status: "running", levels: levels} = export) do
    Map.values(levels)
    |> create_levels(export)
  end
  def create_levels(export), do: export

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

  def create_spawn_locations(%{status: "running"} = export) do
    export.spawn_locations
    |> Enum.group_by(fn [num, _row, _col] -> num end)
    |> Enum.each(fn {num, coords} ->
      level_id = export.levels[num].id
      coords = Enum.reduce(coords, [], fn [_num, row, col], acc -> [{row, col} | acc] end)
      Dungeons.add_spawn_locations(level_id, coords)
    end)

    export
  end
  def create_spawn_locations(export), do: export

  def complete_dungeon_import(%{status: "running", dungeon: dungeon} = export) do
    {:ok, dungeon} = Dungeons.update_dungeon(dungeon, %{importing: false})
    %{ export | dungeon: dungeon, status: "done" }
  end
  def complete_dungeon_import(export), do: export
end