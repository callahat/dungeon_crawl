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
  alias DungeonCrawl.Sound

  use DungeonCrawl.Shipping.SlugMatching

  @asset_functions %{
    sounds: %{
      find: &__MODULE__.find_effect/2,
      create: &Sound.create_effect!/1,
      find_by_slug: &Sound.get_effect/2
    },
    items: %{
      find: &__MODULE__.find_item/2,
      create: &Equipment.create_item!/1,
      find_by_slug: &Equipment.get_item/2
    },
    tile_templates: %{
      find: &__MODULE__.find_tile_template/2,
      create: &TileTemplates.create_tile_template!/1,
      find_by_slug: &TileTemplates.get_tile_template/2
    }
  }

  # the script will never match due to the slug; so the script will need to be a "fuzzy" match
  # the fuzzy search, when candidates are found the slug in the candidate will need to be checked
  # to see if its a usable match for the given user; if not then asset(s) not match so a new one
  # will need created.
  def find_or_create_assets(export, asset_key, user) do
    assets =
      Map.get(export, asset_key)
      |> Enum.map(fn {tmp_id, attrs} ->
        asset = find_or_create_asset(export, asset_key, attrs, user)

        {tmp_id, asset}
      end)
      |> Enum.into(%{})

    %{ export | asset_key => assets }
  end

  # todo: how to get the dungeon_import_id in here, not currently in the export struct
  # This will have a aside affect of creating an asset_import record potentially
  defp find_or_create_asset(export, asset_key, attrs, user) do
    with slug = attrs[:slug],
         attrs = Map.drop(attrs, [:slug, :temp_tt_id, :temp_sound_id, :temp_item_id]),
         asset when is_nil(asset) <- @asset_functions[asset_key].find.(user.id, Map.delete(attrs, :user_id)),
         attrs = Map.put(attrs, :user_id, user.id) |> Map.delete(:public),
         asset when is_nil(asset) <- @asset_functions[asset_key].find.(user.id, attrs),
         attrs = Map.put(attrs, :active, true) do
      existing_by_slug = @asset_functions[asset_key].find_by_slug.(slug, user)

      # at this point, the match on attributes failed
      # this if/else will change
      # 1. if there is no entry in the asset_import table, create one,
      #    a. check if there is an existing asset with the original slug
      # 2. if there is an entry with action that is not matched, skip
      # 3. if a create or update action, do so, mark as resolved and updated resolved slug
      # 4. if it is resolved, then return the asset
      # some of this could probably be done in the with statement
      if Map.get(attrs, :script, "") != "" do
        @asset_functions[asset_key].create.(Map.put(attrs, :script, "#end"))
        |> Map.put(:tmp_script, attrs.script)
      else
        @asset_functions[asset_key].create.(attrs)
      end
    else
      asset ->
        asset
    end
  end

  def find_effect(_user_id, attrs) do
    Sound.find_effect(attrs)
  end

  def find_item(user_id, attrs) do
    Equipment.find_items(Map.delete(attrs, :script))
    |> useable_asset(attrs.script, user_id)
  end

  def find_tile_template(user_id, attrs) do
    TileTemplates.find_tile_templates(Map.drop(attrs, [:state, :script]))
    |> Enum.filter(fn tt -> tt.state == attrs.state end)
    |> useable_asset(attrs.script, user_id)
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

  def resolve_ambiguous_slugs(export) do
    # todo: if there are any unresolved ambiguous slugs, this will serve as the breaker,
    # update the export status to :waiting, and update the
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
    %{ export | dungeon: dungeon }
  end
  def complete_dungeon_import(export), do: export
end