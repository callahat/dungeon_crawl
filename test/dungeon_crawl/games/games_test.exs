defmodule DungeonCrawl.GamesTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Games
  alias DungeonCrawl.Player
  alias DungeonCrawl.Player.Location

  import DungeonCrawlWeb.TestHelpers

  describe "saved_games" do
    alias DungeonCrawl.Games.Save

    import DungeonCrawl.GamesFixtures

    @invalid_attrs %{col: nil, row: nil, state: nil, user_id_hash: nil}

    test "list_saved_games/0 returns all saved_games" do
      save = save_fixture()
      assert Games.list_saved_games() == [save]
    end

    test "list_saved_games/1 returns all saved_games for given user id hash and dungeon id" do
      save1 = save_fixture(%{user_id_hash: "one"})
      save_fixture(%{user_id_hash: "one"})
      save_fixture()
      dungeon_id = Repo.preload(save1, :dungeon_instance).dungeon_instance.dungeon_id
      assert Games.list_saved_games(%{user_id_hash: "one", dungeon_id: dungeon_id}) == [save1]
      assert Games.list_saved_games(%{user_id_hash: "derp", dungeon_id: dungeon_id}) == []
    end

    test "list_saved_games/1 returns all saved_games for given dungeon id" do
      save1 = save_fixture(%{user_id_hash: "one"})
      save_fixture(%{user_id_hash: "one"})
      dungeon_id = Repo.preload(save1, :dungeon_instance).dungeon_instance.dungeon_id
      assert Games.list_saved_games(%{dungeon_id: dungeon_id}) == [save1]
    end

    test "list_saved_games/1 returns all saved_games for given user id hash" do
      save1 = save_fixture(%{user_id_hash: "one"})
      save2 = save_fixture(%{user_id_hash: "one"})
      save3 = save_fixture()
      assert Games.list_saved_games(%{user_id_hash: "one"}) == [save1, save2]
      assert Games.list_saved_games(%{user_id_hash: save3.user_id_hash}) == [save3]
      assert Games.list_saved_games(%{user_id_hash: "derp"}) == []
    end

    test "has_saved_games?/1" do
      save = save_fixture(%{user_id_hash: "one"})
             |> Repo.preload(:dungeon_instance)
      assert Games.has_saved_games?(save.level_instance)
      assert Games.has_saved_games?(save.dungeon_instance)
      assert Games.has_saved_games?(save.dungeon_instance.id)
      refute Games.has_saved_games?(save.dungeon_instance.id + 1)
    end

    test "get_save/1 returns the save with given id" do
      save = save_fixture()
      assert Games.get_save(save.id) == save
    end

    test "get_save/2 returns the save with the given id and user_id_hash" do
      save = save_fixture()
      assert Games.get_save(save.id, save.user_id_hash) == save
      refute Games.get_save(save.id, "someone else")
    end

    test "create_save/1 with valid data creates a save" do
      level_instance = insert_autogenerated_level_instance()
      location = insert_player_location(%{level_instance_id: level_instance.id})

      valid_attrs = %{col: 42, row: 42, state: "valid: state", user_id_hash: "some user_id_hash",
        level_instance_id: level_instance.id, location_id: location.id}

      assert {:ok, %Save{} = save} = Games.create_save(valid_attrs)
      assert save.col == 42
      assert save.row == 42
      assert save.state == "valid: state"
      assert save.user_id_hash == "some user_id_hash"
    end

    test "create_save/2 with valid data creates a save" do
      level_instance = insert_autogenerated_level_instance()
      location = insert_player_location(%{level_instance_id: level_instance.id})

      tile = Repo.preload(location, :tile).tile

      assert {:ok, %Save{} = save} = Games.create_save(tile, location)
      assert save.col == tile.col
      assert save.row == tile.row
      assert save.state == tile.state
      assert save.user_id_hash == location.user_id_hash
    end

    test "create_save/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Games.create_save(@invalid_attrs)
    end

    test "update_save/2 with valid data updates the save" do
      save = save_fixture()
      update_attrs = %{col: 43, row: 43, state: "some updated state", user_id_hash: "some updated user_id_hash"}

      assert {:ok, %Save{} = save} = Games.update_save(save, update_attrs)
      assert save.col == 43
      assert save.row == 43
      assert save.state == "some updated state"
      assert save.user_id_hash == "some updated user_id_hash"
    end

    test "update_save/2 with invalid data returns error changeset" do
      save = save_fixture()
      assert {:error, %Ecto.Changeset{}} = Games.update_save(save, @invalid_attrs)
      assert save == Games.get_save(save.id)
    end

    test "load_save/2 invalid save id returns error" do
      user = insert_user()
      assert {:error, "Save not found"} = Games.load_save(1, user.user_id_hash)
    end

    test "load_save/2 nonexistant user" do
      save = save_fixture(%{user_id_hash: "junk"})
      assert {:error, "Player not found"} = Games.load_save(save.id, "junk")
    end

    test "load_save/2 invalid user" do
      user = insert_user()
      save = save_fixture(%{user_id_hash: "junk"})
      assert {:error, "Save does not belong to player"} = Games.load_save(save.id, user.user_id_hash)
    end

    test "load_save/2 creates the player location and tile instance" do
      user = insert_user()
      save = save_fixture(%{user_id_hash: user.user_id_hash})

      refute Player.get_location(user.user_id_hash)

      assert {:ok, %Location{}} = Games.load_save(save.id, user.user_id_hash)
      assert location = Player.get_location(user.user_id_hash)
      assert %{background_color: "whitesmoke",
               character: "@",
               col: 42,
               color: "black",
               name: "Some User",
               row: 42,
               script: "",
               state: "player: true",
               z_index: 100
             } = DungeonCrawl.Repo.preload(location, :tile).tile

      # won't load a game when already crawling
      assert {:error, "Player already in a game"} = Games.load_save(save.id, user.user_id_hash)
    end

    test "delete_save/1 deletes the save" do
      save = save_fixture()
      assert {:ok, %Save{}} = Games.delete_save(save)
      refute Games.get_save(save.id)
    end

    test "change_save/1 returns a save changeset" do
      save = save_fixture()
      assert %Ecto.Changeset{} = Games.change_save(save)
    end
  end
end
