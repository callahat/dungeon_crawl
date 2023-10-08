defmodule DungeonCrawl.DungeonProcesses.SoundTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.Sound

  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.Player.Location

  # very similar stubbed dungeon as render
  setup do
    state = %Levels{state_values: %{"rows" => 20, "cols" => 20},
                    dungeon_instance_id: 1,
                    number: 2}

    # 01234567890
    #0 . .O      _
    #1 .#.      O_
    #2 . @       _

    tiles = [
        %Tile{id: 100, character: "#", row: 1, col: 2, z_index: 0, state: %{"blocking" => true}},
        %Tile{id: 109, character: ".", row: 2, col: 1, z_index: 0},
        %Tile{id: 101, character: ".", row: 0, col: 1, z_index: 0, state: %{"light_range" => 1}},
        %Tile{id: 110, character: ".", row: 0, col: 1, z_index: 1, state: %{"light_range" => 2}},
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

    channels = %{level_admin_channel: "level_admin:1:2:",
                 player_channel: "players:3"}

    Map.values(channels)
    |> Enum.each(fn channel -> DungeonCrawlWeb.Endpoint.subscribe(channel) end)

    Map.merge channels, %{state: state, player_tile: player_tile, player_location: player_location}
  end

  describe "broadcast_sound_effects/1" do
    test "when target is bad", %{state: state} do
      state = %{ state | sound_effects: [%{row: 0, col: 0, zzfx_params: "stub", target: "derp"}]}

      updated_state = Sound.broadcast_sound_effects(state)
      assert updated_state.sound_effects == []

      refute_receive %Phoenix.Socket.Broadcast{}
    end

    test "when the sound effect reaches all", %{level_admin_channel: level_admin_channel,
                                                state: state,
                                                player_channel: player_channel } do

      state = %{ state | sound_effects: [%{row: 0, col: 0, zzfx_params: "stub", target: "all"}]}

      updated_state = Sound.broadcast_sound_effects(state)
      assert updated_state.sound_effects == []

      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^level_admin_channel,
        event: "sound_effects",
        payload: %{sound_effects: [%{zzfx_params: "stub", volume_modifier: 1}]}}
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "sound_effects",
        payload: %{sound_effects: [%{zzfx_params: "stub", volume_modifier: 1}]}}
    end

    test "when the sound effect reaches nearby", %{level_admin_channel: level_admin_channel,
                                                   state: state,
                                                   player_channel: player_channel } do

      state = %{ state | sound_effects: [%{row: 0, col: 3, zzfx_params: "stub", target: "nearby"}]}
      expected_modifier = (16.0 - 2.0)/15.0

      updated_state = Sound.broadcast_sound_effects(state)
      assert updated_state.sound_effects == []

      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^level_admin_channel,
        event: "sound_effects",
        payload: %{sound_effects: [%{zzfx_params: "stub", volume_modifier: 1}]}}
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "sound_effects",
        payload: %{sound_effects: [%{zzfx_params: "stub", volume_modifier: ^expected_modifier}]}}
    end

    test "when the sound effect is for one specific player", %{level_admin_channel: level_admin_channel,
                                                              state: state,
                                                              player_channel: player_channel,
                                                              player_tile: player_tile} do
      state = %{ state | sound_effects: [%{row: 0, col: 3, zzfx_params: "stub", target: player_tile.id}]}

      updated_state = Sound.broadcast_sound_effects(state)
      assert updated_state.sound_effects == []

      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^level_admin_channel,
        event: "sound_effects",
        payload: %{sound_effects: [%{zzfx_params: "stub", volume_modifier: 1}]}}
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "sound_effects",
        payload: %{sound_effects: [%{zzfx_params: "stub", volume_modifier: 1}]}}
    end

    test "multiple sound effects", %{level_admin_channel: level_admin_channel,
                                     state: state,
                                     player_channel: player_channel,
                                     player_tile: player_tile } do

      state = %{ state | sound_effects: [
                           %{row: 0, col: 3, zzfx_params: "stub1", target: "nearby"},
                           %{row: 1, col: 3, zzfx_params: "stub2", target: "nearby"},
                           %{row: 1, col: 10, zzfx_params: "stub3", target: "all"},
                           %{row: 0, col: 1, zzfx_params: "stub4", target: player_tile.id},
                           %{row: 2, col: 1, zzfx_params: "stub5", target: "nearby"},
      ]}
      expected_modifier1 = (16.0 - 2.0)/15.0
      expected_modifier2 = (16.0 - 1.0)/15.0

      updated_state = Sound.broadcast_sound_effects(state)
      assert updated_state.sound_effects == []

      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^level_admin_channel,
        event: "sound_effects",
        payload: %{sound_effects: [
                     %{zzfx_params: "stub5", volume_modifier: 1},
                     %{zzfx_params: "stub4", volume_modifier: 1},
                     %{zzfx_params: "stub3", volume_modifier: 1},
                     %{zzfx_params: "stub2", volume_modifier: 1},
                     %{zzfx_params: "stub1", volume_modifier: 1},
        ]}}
      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^player_channel,
        event: "sound_effects",
        payload: %{sound_effects: [
        %{zzfx_params: "stub4", volume_modifier: 1},
                     %{zzfx_params: "stub3", volume_modifier: 1},
                     %{zzfx_params: "stub2", volume_modifier: ^expected_modifier2},
                     %{zzfx_params: "stub1", volume_modifier: ^expected_modifier1},
        ]}}
    end
  end
end
