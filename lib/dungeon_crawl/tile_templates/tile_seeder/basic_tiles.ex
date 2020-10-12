defmodule DungeonCrawl.TileTemplates.TileSeeder.BasicTiles do
  alias DungeonCrawl.Repo
  alias DungeonCrawl.TileTemplates

  @doc """
  Seeds the DB with the basic tiles (floor, wall, rock, open/closed doors, and statue),
  returning a map of the tile's character (as the character code and also as the string)
  as the key, and the existing or created tile template record as the value.
  """
  def basic_tiles() do
    floor = create_with_defaults!("floor", %{character: ".", name: "Floor", description: "Just a dusty floor", state: "blocking: false"})
    wall  = create_with_defaults!("wall", %{character: "#", name: "Wall",  description: "A Rough wall", state: "blocking: true"})
    rock  = rock_tile()
    statue= create_with_defaults!("statue", %{character: "@", name: "Statue",  description: "It looks oddly familiar", state: "blocking: true"})

    open_door    = create_with_defaults!("open_door", %{character: "'", name: "Open Door", description: "An open door", state: "blocking: false, open: true", script: ""})
    closed_door  = create_with_defaults!("closed_door", %{character: "+", name: "Closed Door", description: "A closed door", state: "blocking: true, open: false", script: ""})

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
    create_with_defaults!("rock", %{character: " ", name: "Rock",  description: "Impassible stone", state: "blocking: true"})
  end

  @doc """
  Seeds the DB with a door that can open and close.
  """
  def solo_door(character \\ "+", state \\ "blocking: true, open: false") do
    create_with_defaults!(
      "basic_door",
      %{
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
    TileTemplates.update_or_create_tile_template!(
      "bullet",
      %{character: "◦",
        name: "Bullet",
        description: "Its a bullet.",
        state: "blocking: false, wait_cycles: 1, not_pushing: true, not_squishing: true, damage: 5",
        script: """
                :MAIN
                #WALK @facing
                :THUD
                @ricochet = ?sender@ricochet
                #IF @ricochet == clockwise, CHANGE_FACING
                #IF @ricochet == counterclockwise, CHANGE_FACING
                #IF @ricochet == reverse, CHANGE_FACING
                #IF @ricochet, RANDOM_FACING
                #SEND shot, ?sender
                #DIE
                :TOUCH
                #SEND shot, ?sender
                #DIE
                :RANDOM_FACING
                #RANDOM ricochet, clockwise, counterclockwise, reverse
                :CHANGE_FACING
                #FACING @ricochet
                #IF true, MAIN
                """
      })
  end

  @doc """
  Seeds the DB with the basic player character tile, returning that record.
  """
  def player_character_tile() do
    TileTemplates.update_or_create_tile_template!(
      "player",
      %{character: "@",
        name: "Player",
        description: "Its a player.",
        state: "blocking: true, soft: true, pushable: true, health: 100, gems: 0, cash: 0, ammo: 6, bullet_damage: 10, player: true"}
    )
  end

  # ☠
  def create_with_defaults!(slug, params) do
    TileTemplates.update_or_create_tile_template! slug, Map.merge(params, %{active: true, public: true})
  end

  defmacro __using__(_params) do
    quote do
      def basic_tiles(), do: unquote(__MODULE__).basic_tiles()
      def rock_tile(), do: unquote(__MODULE__).rock_tile()
      def solo_door(), do: unquote(__MODULE__).solo_door()
      def bullet_tile(), do: unquote(__MODULE__).bullet_tile()
      def player_character_tile(), do: unquote(__MODULE__).player_character_tile()

      defp create_with_defaults!(slug, params), do: unquote(__MODULE__).create_with_defaults!(slug, params)
    end
  end
end
