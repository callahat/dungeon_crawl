defmodule DungeonCrawl.TileTemplates.TileSeeder.Terrain do
  alias DungeonCrawl.TileTemplates

  def boulder() do
    TileTemplates.find_or_create_tile_template!(
      %{character: "▪",
        name: "Boulder",
        description: "A boulder",
        state: "blocking: true, pushable: true, pullable: true",
        public: true,
        active: true
    })
  end

  defmacro __using__(_params) do
    quote do
      def boulder(), do: unquote(__MODULE__).boulder()
    end
  end
end
