defmodule DungeonCrawl.Shipping.DockWorkerTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Shipping.DockWorker

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Shipping
  alias DungeonCrawl.Shipping.{DungeonExports, Json}
  alias DungeonCrawl.Equipment.Seeder, as: EquipmentSeeder
  alias DungeonCrawl.Sound.Seeder, as: SoundSeeder

  setup do
    EquipmentSeeder.gun
    SoundSeeder.click
    SoundSeeder.shoot

#    dock_worker = start_supervised!(DockWorker)
    {:ok, dock_worker} = GenServer.start_link(DockWorker, %{})

    user = insert_user()

    %{dock_worker: dock_worker, user: user}
  end

  test "export/1", %{user: user} do
    dungeon = insert_dungeon()
    dungeon_export = Shipping.create_export!(%{dungeon_id: dungeon.id, user_id: user.id})

    assert %Task{ref: ref} = DockWorker.export(dungeon_export)
    assert_receive {^ref, :ok}

    assert %{dungeon_id: dungeon.id,
             status: :completed,
             data: DungeonExports.run(dungeon.id) |> Json.encode!(),
             user_id: user.id,
             file_name: "Autogenerated_v_1.json"}
           == Map.take(Shipping.get_export!(dungeon_export.id), [:dungeon_id, :status, :data, :user_id, :file_name])
  end

  test "import/1", %{user: user} do
    dungeon = insert_dungeon(%{user_id: user.id})
    dungeon_import = Shipping.create_import!(%{
      data: DungeonExports.run(dungeon.id) |> Json.encode!(),
      user_id: user.id,
      file_name: "import.json",
      line_identifier: dungeon.line_identifier
    })

    assert %Task{ref: ref} = DockWorker.import(dungeon_import)
    assert_receive {^ref, :ok}

    # the original + the imported
    assert 2 == Enum.count(Dungeons.list_dungeons())

    imported_dungeon = Dungeons.list_dungeons() |> Enum.at(1)

    assert %{dungeon_id: imported_dungeon.id,
             status: :completed,
             user_id: user.id,
             file_name: "import.json",
             line_identifier: dungeon.line_identifier}
           == Map.take(Shipping.get_import!(dungeon_import.id),
                       [:dungeon_id, :status, :user_id, :file_name, :line_identifier])
    assert user.id == imported_dungeon.user_id
    assert imported_dungeon.previous_version_id == dungeon.id
  end

  @tag capture_log: true
  test "import/1 but with corrupted json in the record", %{user: user} do
    dungeon_import = Shipping.create_import!(%{
      data: "{\"dungeon\":{\"autogenerated\":false,\"default_map_height\":25",
      user_id: user.id,
      file_name: "imppport.json"
    })

    log = ExUnit.CaptureLog.capture_log(fn ->
      assert %Task{ref: ref} = DockWorker.import(dungeon_import)
      assert_receive {^ref, :ok}
    end)

    assert 0 == Enum.count(Dungeons.list_dungeons())

    assert log =~ "poolboy transaction caught error: :exit, {{%Jason.DecodeError"
  end
end