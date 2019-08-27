defmodule DungeonCrawl.Repo.Migrations.AddScriptColumns do
  use Ecto.Migration
  alias Ecto.Adapters.SQL
  alias DungeonCrawl.Repo

  def up do
    alter table(:dungeon_map_tiles) do
      add :script, :string
    end
    alter table(:map_tile_instances) do
      add :script, :string
    end
    alter table(:tile_templates) do
      add :script, :string
    end

    flush()

    # Currently doors reference each other. After scripting is introduced, they won't have to
    # but for backward compatability we'll replace the responder with a script that will replace 
    # the backing tile template and related state/script/character/etc
    # Since move is a system event and based off the state, nothing to do script-wise.

    for action <- ["open", "close"] do
      {:ok, %{rows: rows}} = SQL.query Repo, "SELECT id, responders FROM tile_templates WHERE responders LIKE '%#{action}: {:ok%replace%'"

      for [id, responder] <- rows do
        %{"id" => replacement_ttid} = Regex.named_captures ~r/replace:\s\[(?<id>\d+?)\]/, responder

        execute "UPDATE tile_templates " <>
                " SET script = ':#{String.upcase(action)}\n#BECOME TTID:#{replacement_ttid}' " <>
                "WHERE id = #{id}"
      end
    end

    ["dungeon_map_tiles", "map_tile_instances"]
    |> Enum.each(fn(table) ->
         execute "UPDATE #{table} " <>
                 "  SET script = tt.script " <>
                 "FROM tile_templates tt " <>
                 "WHERE tile_template_id = tt.id"
       end)

    alter table(:tile_templates) do
      remove :responders
    end
  end

  def down do
    _restore_responders()

    alter table(:dungeon_map_tiles) do
      remove :script
    end
    alter table(:map_tile_instances) do
      remove :script
    end
    alter table(:tile_templates) do
      remove :script
    end
  end

  defp _restore_responders do
    alter table(:tile_templates) do
      add :responders, :string
    end

    flush()

    for action <- ["open", "close"] do
      {:ok, %{rows: rows}} = SQL.query Repo, "SELECT id, state, script FROM tile_templates WHERE script LIKE '%:#{String.upcase(action)}\n#BECOME TTID%'"

      for [id, state, script] <- rows do
        %{"id" => replacement_ttid} = Regex.named_captures ~r/:#{String.upcase(action)}\n#BECOME TTID:(?<id>\d+?)/, script

        maybe_move = if state =~ ~r/blocking: false/, do: "move: {:ok}, ", else: ""

        execute "UPDATE tile_templates " <>
                " SET responders = '{#{maybe_move}#{action}: {:ok, replace: [#{replacement_ttid}]}}' " <>
                "WHERE id = #{id}"
      end
    end
  end
end
