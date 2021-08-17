defmodule DungeonCrawl.DungeonProcesses.RenderTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.Render

  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.Player.Location

  setup do
    state = %Levels{state_values: %{rows: 20, cols: 20},
                    dungeon_instance_id: 1,
                    instance_id: 2}

    tiles = [
        %Tile{id: 100, character: "#", row: 1, col: 2, z_index: 0, state: "blocking: true"},
        %Tile{id: 101, character: ".", row: 0, col: 1, z_index: 0},
        %Tile{id: 108, character: ".", row: 1, col: 1, z_index: 0},
        %Tile{id: 102, character: ".", row: 0, col: 3, z_index: 0},
        %Tile{id: 103, character: ".", row: 1, col: 3, z_index: 0},
        %Tile{id: 104, character: "O", row: 1, col: 10, z_index: 0},
        %Tile{id: 105, character: "O", row: 1, col: 4, z_index: 0}
      ]

    state = Enum.reduce(tiles, state, fn tile, state ->
              {_, state} = Levels.create_tile(state, tile)
              state
            end)

    player_tile = %Tile{id: 1, character: "@", row: 2, col: 3, z_index: 1, name: "player"}
    player_location = %Location{id: 3, tile_instance_id: player_tile.id, user_id_hash: "goodhash"}
    {_, state} = Levels.create_player_tile(state, player_tile, player_location)

    state = %{state | dirty_ids: %{},
                      rerender_coords: %{},
                      players_visible_coords: %{player_tile.id => [%{row: 1, col: 10}]}}

    channels = %{level_channel: "level:1:2",
                 level_admin_channel: "level_admin:1:2",
                 player_channel: "players:3"}

    Map.values(channels)
    |> Enum.each(fn channel -> DungeonCrawlWeb.Endpoint.subscribe(channel) end)

    Map.merge channels, %{state: state, player_tile: player_tile, player_location: player_location}
  end

  describe "rerender_tiles/1" do
    test "when full_rerender is true, it does a full rerender of the level", %{level_channel: level_channel,
                                                                               level_admin_channel: level_admin_channel,
                                                                               state: state} do
      state = %{state | full_rerender: true}
      Render.rerender_tiles(state)

      assert_receive %Phoenix.Socket.Broadcast{
              topic: ^level_channel,
              event: "full_render",
              payload: %{level_render: _}}
      assert_receive %Phoenix.Socket.Broadcast{
              topic: ^level_admin_channel,
              event: "full_render",
              payload: %{level_render: _}}
    end

    test "when foggy sends updates to the player channels", %{level_channel: level_channel,
                                                              level_admin_channel: level_admin_channel,
                                                              player_channel: player_channel,
                                                              state: state} do
      state = %{state | state_values: Map.put(state.state_values, :visibility, "fog"), rerender_coords: %{%{col: 10, row: 1} => true}}
      assert updated_state = Render.rerender_tiles(state)
      assert Map.delete(updated_state, :players_visible_coords) == Map.delete(state, :players_visible_coords)
      assert updated_state.players_visible_coords != state.players_visible_coords

      refute_receive %Phoenix.Socket.Broadcast{topic: ^level_channel}
      refute_receive %Phoenix.Socket.Broadcast{topic: ^level_admin_channel}
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "visible_tiles",
        payload: %{fog: _,
                   tiles: _}}
    end

    test "does nothing when nothing to update", %{state: state} do
      assert state == Render.rerender_tiles(state)
      refute_receive %Phoenix.Socket.Broadcast{}
    end

    test "broadcasts to the appropriate channels", %{state: state,
                                                     level_channel: level_channel,
                                                     level_admin_channel: level_admin_channel,
                                                     player_channel: player_channel} do
      state = %{ state | rerender_coords: %{%{col: 10, row: 1} => true, %{col: 10, row: 2} => true}}
      assert state == Render.rerender_tiles(state)

      assert_receive %Phoenix.Socket.Broadcast{
              topic: ^level_channel,
              event: "tile_changes",
              payload: %{tiles: _}}
      assert_receive %Phoenix.Socket.Broadcast{
              topic: ^level_admin_channel,
              event: "tile_changes",
              payload: %{tiles: _}}
      refute_receive %Phoenix.Socket.Broadcast{topic: ^player_channel}

      # When the changes exceed the threshold - dont actually use a threshold this low. The
      # threshold is meant for when it would be faster to rerender the whole thing vs send out updated tiles
      # individually.
      initial_threshold = Application.get_env(:dungeon_crawl, :full_rerender_threshold)
      Application.put_env(:dungeon_crawl, :full_rerender_threshold, 1)
      assert state == Render.rerender_tiles(state)

      assert_receive %Phoenix.Socket.Broadcast{
              topic: ^level_channel,
              event: "full_render",
              payload: %{level_render: _}}
      assert_receive %Phoenix.Socket.Broadcast{
              topic: ^level_admin_channel,
              event: "full_render",
              payload: %{level_render: _}}
      refute_receive %Phoenix.Socket.Broadcast{topic: ^player_channel}

      # cleanup
      Application.put_env(:dungeon_crawl, :full_rerender_threshold, initial_threshold)
    end
  end

  describe "rerender_tiles_for_admin/1" do
    test "does nothing when nothing to update", %{state: state} do
      assert state == Render.rerender_tiles_for_admin(state)
      refute_receive %Phoenix.Socket.Broadcast{}
    end

    test "does nothing when it is not foggy", %{state: state} do
      state = %{ state | rerender_coords: %{%{col: 10, row: 1} => true}}
      assert state == Render.rerender_tiles_for_admin(state)
      refute_receive %Phoenix.Socket.Broadcast{}
    end

    test "broadcasts to the dungeon_admin channel only", %{state: state,
                                                           level_channel: level_channel,
                                                           level_admin_channel: level_admin_channel} do
      state = %{ state | state_values: Map.put(state.state_values, :visibility, "fog"),
                         rerender_coords: %{%{col: 10, row: 1} => true, %{col: 10, row: 2} => true}}
      assert state == Render.rerender_tiles_for_admin(state)

      refute_receive %Phoenix.Socket.Broadcast{
              topic: ^level_channel,
              event: "tile_changes",
              payload: %{tiles: _}}
      assert_receive %Phoenix.Socket.Broadcast{
              topic: ^level_admin_channel,
              event: "tile_changes",
              payload: %{tiles: _}}

      # When the changes exceed the threshold - dont actually use a threshold this low. The
      # threshold is meant for when it would be faster to rerender the whole thing vs send out updated tiles
      # individually.
      initial_threshold = Application.get_env(:dungeon_crawl, :full_rerender_threshold)
      Application.put_env(:dungeon_crawl, :full_rerender_threshold, 1)
      assert state == Render.rerender_tiles_for_admin(state)

      refute_receive %Phoenix.Socket.Broadcast{
              topic: ^level_channel,
              event: "full_render",
              payload: %{level_render: _}}
      assert_receive %Phoenix.Socket.Broadcast{
              topic: ^level_admin_channel,
              event: "full_render",
              payload: %{level_render: _}}
      # cleanup
      Application.put_env(:dungeon_crawl, :full_rerender_threshold, initial_threshold)
    end
  end

  describe "full_rerender/2" do
    test "broadcasts a full rerender to the given channels", %{level_channel: level_channel,
                                                               level_admin_channel: level_admin_channel,
                                                               player_channel: player_channel,
                                                               state: state} do
      Render.full_rerender(state, [level_channel, level_admin_channel])

      assert_receive %Phoenix.Socket.Broadcast{
              topic: ^level_channel,
              event: "full_render",
              payload: %{level_render: _}}
      assert_receive %Phoenix.Socket.Broadcast{
              topic: ^level_admin_channel,
              event: "full_render",
              payload: %{level_render: _}}
      refute_receive %Phoenix.Socket.Broadcast{
              topic: ^player_channel}
    end
  end

  describe "partial_rerender/2" do
    test "broadcasts a partial rerender to the given channels", %{level_channel: level_channel,
                                                                  level_admin_channel: level_admin_channel,
                                                                  player_channel: player_channel,
                                                                  state: state} do
      # when there are no rerender_coords
      Render.partial_rerender(state, [level_channel, level_admin_channel])

      assert_receive %Phoenix.Socket.Broadcast{
              topic: ^level_channel,
              event: "tile_changes",
              payload: %{tiles: []}}
      assert_receive %Phoenix.Socket.Broadcast{
              topic: ^level_admin_channel,
              event: "tile_changes",
              payload: %{tiles: []}}
      refute_receive %Phoenix.Socket.Broadcast{
              topic: ^player_channel}

      # when there are rerender_coords
      Render.partial_rerender(%{ state | rerender_coords: %{%{col: 10, row: 1} => true}}, [level_channel, level_admin_channel])

      assert_receive %Phoenix.Socket.Broadcast{
              topic: ^level_channel,
              event: "tile_changes",
              payload: %{tiles: [%{col: 10, rendering: "<div>O</div>", row: 1}]}}
      assert_receive %Phoenix.Socket.Broadcast{
              topic: ^level_admin_channel,
              event: "tile_changes",
              payload: %{tiles: [%{col: 10, rendering: "<div>O</div>", row: 1}]}}
      refute_receive %Phoenix.Socket.Broadcast{
              topic: ^player_channel}
    end
  end

  describe "visible_tiles_for_player/3" do
    test "when its not foggy", %{state: state, player_location: player_location} do
      assert state == Render.visible_tiles_for_player(state, player_location.tile_instance_id, player_location.id)
      refute_receive %Phoenix.Socket.Broadcast{}
    end

    test "when it is foggy", %{state: state, player_location: player_location, player_channel: player_channel} do
      # no rerender_coords, so nothing to do
      state = %{state | state_values: Map.put(state.state_values, :visibility, "fog")}
      assert state == Render.visible_tiles_for_player(state, player_location.tile_instance_id, player_location.id)
      refute_receive %Phoenix.Socket.Broadcast{}

      # with rerender coords, updates the visible area
      state = %{ state | rerender_coords: %{%{col: 10, row: 1} => true}}

      assert updated_state = Render.visible_tiles_for_player(state, player_location.tile_instance_id, player_location.id)
      assert_receive %Phoenix.Socket.Broadcast{
              topic: ^player_channel,
              event: "visible_tiles",
              payload: %{fog: [%{col: 10, row: 1}],
                         tiles: [%{col: 3, rendering: "<div>@</div>", row: 2},
                                 %{col: 3, rendering: "<div>.</div>", row: 0},
                                 %{col: 2, rendering: "<div>#</div>", row: 1},
                                 %{col: 3, rendering: "<div>.</div>", row: 1},
                                 %{col: 4, rendering: "<div>O</div>", row: 1}]}}

      player_tile_id = player_location.tile_instance_id

      assert %{player_tile_id => [%{col: 3, row: 2},
                                  %{col: 3, row: 0},
                                  %{col: 2, row: 1},
                                  %{col: 3, row: 1},
                                  %{col: 4, row: 1}]} == updated_state.players_visible_coords
    end
  end

  describe "illuminated_tile_map/1" do
    test "returns a map of illuminated tiles", %{state: state, player_location: player_location} do
      state = %{ state | light_sources: %{player_location.tile_instance_id => true}}
      assert %{{0, 3} => true,
               {1, 3} => true,
               {2, 3} => true,
               {1, 4} => true,
               {1, 2} => ["south", "east"]} == Render.illuminated_tile_map(state)

      # Multiple light sources
      state = %{ state | light_sources: %{player_location.tile_instance_id => true, 101 => true}}
      assert %{{0, 3} => true,
               {1, 3} => true,
               {2, 3} => true,
               {1, 4} => true,
               {1, 2} => true,
               {0, 1} => true,
               {1, 1} => true} == Render.illuminated_tile_map(state)
    end
  end
end

