defmodule DungeonCrawl.TileTemplates.TileSeeder.BasicTiles do
  alias DungeonCrawl.Repo
  alias DungeonCrawl.TileTemplates

  @doc """
  Seeds the DB with the basic tiles (floor, wall, rock, open/closed doors, and statue),
  returning a map of the tile's character (as the character code and also as the string)
  as the key, and the existing or created tile template record as the value.
  """
  def basic_tiles() do
    floor = create_with_defaults!(%{character: ".", name: "Floor", description: "Just a dusty floor", state: "blocking: false"})
    wall  = create_with_defaults!(%{character: "#", name: "Wall",  description: "A Rough wall", state: "blocking: true"})
    rock  = rock_tile()
    statue= create_with_defaults!(%{character: "@", name: "Statue",  description: "It looks oddly familiar", state: "blocking: true"})

    open_door    = create_with_defaults!(%{character: "'", name: "Open Door", description: "An open door", state: "blocking: false, open: true"})
    closed_door  = create_with_defaults!(%{character: "+", name: "Closed Door", description: "A closed door", state: "blocking: true, open: false"})

    open_door   = Repo.update! TileTemplates.change_tile_template(open_door, %{script: "#END\n:CLOSE\n#BECOME slug: #{closed_door.slug}"})
    closed_door = Repo.update! TileTemplates.change_tile_template(closed_door, %{script: "#END\n:OPEN\n#BECOME slug: #{open_door.slug}"})

    solo_door() # placeholder for now

    %{?.  => floor, ?#  => wall, ?\s => rock, ?'  => open_door, ?+  => closed_door, ?@  => statue,
      "." => floor, "#" => wall, " " => rock, "'" => open_door, "+" => closed_door, "@" => statue}
  end

  @doc """
  Seeds the DB with the basic player character tile, returning that record.
  """
  def rock_tile() do
    create_with_defaults!(%{character: " ", name: "Rock",  description: "Impassible stone", state: "blocking: true"})
  end

  @doc """
  Seeds the DB with a door that can open and close.
  """
  def solo_door(character \\ "+", state \\ "blocking: true, open: false") do
    create_with_defaults!(%{
      character: character,
      color: "black",
      background_color: "lightgray",
      name: "Basic Door",
      description: "A basic door, it opens and closes",
      state: state,
      script: """
              #END
              :CLOSE
              #IF not @open, CANT_CLOSE
              #BECOME character: +
              @open = false
              @blocking = true
              #END
              :OPEN
              #IF @open, CANT_OPEN
              #BECOME character: '
              @open = true
              @blocking = false
              #END
              :CANT_OPEN
              Cannot open that
              #END
              :CANT_CLOSE
              Cannot close that
              #END
              """
      })
  end

  @doc """
  Seeds the DB with the basic bullet tile, returning that record.
  """
  def bullet_tile() do
    TileTemplates.find_or_create_tile_template!(
      %{character: "◦",
        name: "Bullet",
        description: "Its a bullet.",
        state: "blocking: false, wait_cycles: 1, not_pushing: true, not_squishing: true, damage: 5",
        script: """
                #WALK @facing
                :THUD
                #SEND shot, @facing
                #DIE
                :TOUCH
                #SEND shot, ?sender
                #DIE
                """
      })
  end

  @doc """
  Seeds the DB with the basic player character tile, returning that record.
  """
  def player_character_tile() do
    TileTemplates.find_or_create_tile_template!(
      %{character: "@",
        name: "Player",
        description: "Its a player.",
        state: "blocking: true, pushable: true, health: 100, gems: 0, cash: 0, ammo: 6, bullet_damage: 10, player: true"}
    )
  end

  # ☠
  def create_with_defaults!(params) do
    TileTemplates.find_or_create_tile_template! Map.merge(params, %{active: true, public: true})
  end

  defmacro __using__(_params) do
    quote do
      def basic_tiles(), do: unquote(__MODULE__).basic_tiles()
      def rock_tile(), do: unquote(__MODULE__).rock_tile()
      def solo_door(), do: unquote(__MODULE__).solo_door()
      def bullet_tile(), do: unquote(__MODULE__).bullet_tile()
      def player_character_tile(), do: unquote(__MODULE__).player_character_tile()

      defp create_with_defaults!(params), do: unquote(__MODULE__).create_with_defaults!(params)
    end
  end
end