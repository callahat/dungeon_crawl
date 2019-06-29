defmodule DungeonCrawl.DungeonInstances.MapTile do
  use Ecto.Schema
  import Ecto.Changeset


  schema "map_tile_instances" do
    field :row, :integer
    field :col, :integer
    field :z_index, :integer, default: 0

    belongs_to :dungeon, DungeonCrawl.DungeonInstances.Map, foreign_key: :map_instance_id
    belongs_to :tile_template, DungeonCrawl.TileTemplates.TileTemplate
    has_many :player_locations, DungeonCrawl.Player.Location, foreign_key: :map_tile_instance_id, on_delete: :delete_all
  end

  @doc false
  def changeset(map_tile_instance, attrs) do
    map_tile_instance
    |> cast(attrs, [:row, :col, :map_instance_id, :tile_template_id, :z_index])
    |> validate_required([:row, :col, :map_instance_id, :tile_template_id, :z_index])
  end
end
