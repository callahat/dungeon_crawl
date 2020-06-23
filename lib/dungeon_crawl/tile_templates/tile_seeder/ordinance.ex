defmodule DungeonCrawl.TileTemplates.TileSeeder.Ordinance do
  alias DungeonCrawl.TileTemplates

  def smoke do
    TileTemplates.find_or_create_tile_template!(
      %{character: "▒",
        name: "Smoke",
        description: "Fine particles of various dust and gas",
        state: "blocking: false, duration: 20, smoke: true",
        color: "gray",
        public: true,
        active: true,
        script: """
                @counter = 0
                :wait
                @counter += 1
                #IF @counter >= @duration, fading
                #SEND wait
                ?i
                :fading
                @counter = 0
                #ZAP wait
                #BECOME character: ░
                :wait
                @counter += 1
                #IF @counter >= @duration, fading
                #SEND wait
                ?i
                :done
                #DIE
                """
    })
  end

  defmacro __using__(_params) do
    quote do
      def smoke(), do: unquote(__MODULE__).smoke()
    end
  end
end
