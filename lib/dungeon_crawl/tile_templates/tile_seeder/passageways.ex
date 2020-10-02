defmodule DungeonCrawl.TileTemplates.TileSeeder.Passageways do
  alias DungeonCrawl.TileTemplates

  def passage do
    TileTemplates.update_or_create_tile_template!(
      "passage",
      %{character: "≡",
        name: "Passage",
        description: "It looks like it leads somwhere.",
        state: "to_level: 1",
        color: "black",
        background_color: "gray",
        public: true,
        active: true,
        script: """
                #PASSAGE @background_color
                #END
                :TOUCH
                #TRANSPORT ?sender, @to_level, @background_color
                """
    })
  end

  def stairs_up do
    TileTemplates.update_or_create_tile_template!(
      "stairs_up",
      %{character: "▟",
        name: "Stairs Up",
        description: "A stairway leading up",
        state: "",
        color: "black",
        public: true,
        active: true,
        script: """
                #PASSAGE stairs_up
                #END
                :TOUCH
                #TRANSPORT ?sender, up, stairs_down
                """
    })
  end

  def stairs_down do
    TileTemplates.update_or_create_tile_template!(
      "stairs_down",
      %{character: "▙",
        name: "Stairs Down",
        description: "A stairway leading down.",
        state: "",
        color: "black",
        public: true,
        active: true,
        script: """
                #PASSAGE stairs_down
                #END
                :TOUCH
                #TRANSPORT ?sender, down, stairs_up
                """
    })
  end

  defmacro __using__(_params) do
    quote do
      def passage(), do: unquote(__MODULE__).passage()
      def stairs_up(), do: unquote(__MODULE__).stairs_up()
      def stairs_down(), do: unquote(__MODULE__).stairs_down()
    end
  end
end
