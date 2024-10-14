defmodule DungeonCrawl.TileTemplates.TileSeeder.Passageways do
  alias DungeonCrawl.TileTemplates

  def passage do
    TileTemplates.update_or_create_tile_template!(
      "passage",
      %{character: "≡",
        name: "Passage",
        description: "It looks like it leads somwhere.",
        state: %{"to_level" => 1},
        color: "black",
        background_color: "gray",
        public: true,
        active: true,
        group_name: "misc",
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
        state: %{},
        color: "black",
        public: true,
        active: true,
        group_name: "misc",
        script: """
                #PASSAGE stairs_up
                #END
                :TOUCH
                #SOUND slide_up, ?sender
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
        state: %{},
        color: "black",
        public: true,
        active: true,
        group_name: "misc",
        script: """
                #PASSAGE stairs_down
                #END
                :TOUCH
                #SOUND slide_down, ?sender
                #TRANSPORT ?sender, down, stairs_up
                """
    })
  end

  def teleporters do
    [ {"∧", "^, -, ^, ∧", "North"}, {">", "}, |, }, >", "East"}, {"V", "v , _, v, V", "South"}, {"<", "{, |, {, <", "West"} ]
    |> Enum.each(fn({char, sequence, dir}) ->
         TileTemplates.update_or_create_tile_template!(
           "teleporter_#{ String.downcase(dir) }",
           %{character: char,
             name: "Teleporter #{ dir }",
             description: "Teleports to the #{ dir }",
             state: %{"blocking" => true, "teleporter" => true, "facing" => String.downcase(dir), "wait_cycles" => 3},
             color: "black",
             public: true,
             active: true,
             animate_period: 2,
             animate_characters: sequence,
             group_name: "misc",
             script: ""
         })
      end)
  end

  def secret_door do
    TileTemplates.update_or_create_tile_template!(
      "secret_door",
      %{character: "#",
        name: "Secret Door",
        description: "A secret door that blends in with the wall",
        state: %{blocking: true},
        color: "black",
        public: true,
        active: true,
        group_name: "doors",
        script: """
        #END
        :OPEN
        A secret door slides open!
        #BECOME slug: basic_door, color: @color, background_color: @background_color
        """
      })
  end

  defmacro __using__(_params) do
    quote do
      def passage(), do: unquote(__MODULE__).passage()
      def secret_door(), do: unquote(__MODULE__).secret_door()
      def stairs_up(), do: unquote(__MODULE__).stairs_up()
      def stairs_down(), do: unquote(__MODULE__).stairs_down()
      def teleporters(), do: unquote(__MODULE__).teleporters()
    end
  end
end
