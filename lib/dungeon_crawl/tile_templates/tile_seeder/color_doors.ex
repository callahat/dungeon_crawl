defmodule DungeonCrawl.TileTemplates.TileSeeder.ColorDoors do
  alias DungeonCrawl.TileTemplates

  def color_keys_and_doors() do
    ["red", "green", "blue", "gray", "purple", "orange"]
    |> Enum.map(fn color ->
      TileTemplates.update_or_create_tile_template!(
        "#{color}_key",
        %{character: "♀",
          name: "#{color} key",
          description: "a #{color} key",
          color: color,
          public: true,
          active: true,
          script: """
                  #END
                  :TOUCH
                  #IF ! ?sender@player, DONE
                  #IF ?sender@#{color}_key == 1, ALREADY_HAVE
                  #GIVE #{color}_key, 1, ?sender
                  You picked up a #{color} key
                  #DIE
                  :ALREADY_HAVE
                  You already have a #{color} key.
                  :DONE
                  """
      })

      TileTemplates.update_or_create_tile_template!(
        "#{color}_door",
        %{character: "∙",
          name: "#{color} door",
          description: "a #{color} door",
          color: "white",
          background_color: color,
          state: "blocking: true",
          public: true,
          active: true,
          script: """
                  #END
                  :TOUCH
                  #TAKE #{color}_key, 1, ?sender, NOKEY
                  You unlock the #{color} door
                  #DIE
                  :NOKEY
                  You need a #{color} key to unlock.
                  :DONE
                  """
      })
    end )
    :ok
  end

  def generic_colored_key() do
    TileTemplates.update_or_create_tile_template!(
      "colored_key",
      %{character: "♀",
        name: "Colored Key",
        description: "A key that can have a color and unlock a matching door",
        color: "white",
        background_color: "gray",
        public: true,
        active: true,
        script: """
                #END
                :TOUCH
                #IF ! ?sender@player, DONE
                #GIVE @color+_key, 1, ?sender, 1, ALREADY_HAVE
                You picked up a key
                #DIE
                :ALREADY_HAVE
                You already have that key.
                :DONE
                """
    })
  end

  def generic_colored_door() do
    TileTemplates.update_or_create_tile_template!(
      "colored_door",
      %{character: "∙",
        name: "Colored Door",
        description: "A door that can have a color and be unlocked by a matching key",
        color: "black",
        background_color: "white",
        state: "blocking: true",
        public: true,
        active: true,
        script: """
                #END
                :TOUCH
                #TAKE @background_color+_key, 1, ?sender, NOKEY
                You unlock the door
                #DIE
                :NOKEY
                You need a matching key to unlock.
                :DONE
                """
    })
  end

  defmacro __using__(_params) do
    quote do
      def color_keys_and_doors(), do: unquote(__MODULE__).color_keys_and_doors()
      def generic_colored_key(), do: unquote(__MODULE__).generic_colored_key()
      def generic_colored_door(), do: unquote(__MODULE__).generic_colored_door()
    end
  end
end
