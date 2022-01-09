defmodule DungeonCrawl.TileTemplates.TileSeeder.Misc do
  alias DungeonCrawl.TileTemplates

  def beam_wall_emitter() do
    TileTemplates.update_or_create_tile_template!(
      "beam_wall_emitter",
      %{character: "╬",
        name: "Beam Wall Emitter",
        description: "Emits directional beam walls, somewhat dangerous",
        state: "direction: north, delay: 0, blocking: true, wait_cycles: 5",
        public: true,
        active: true,
        group_name: "misc",
        script: """
                :delay
                #if @delay <= 0, point_beam
                @delay -= 1
                /i
                #send delay
                #end
                :point_beam
                @wait_cycles = 30
                @beam_wait_cycles = @wait_cycles
                @beam_wait_cycles /= 2
                #if @direction == north, vertical
                #if @direction == south, vertical
                @slug = beam_wall_horizontal
                #send top
                #end
                :vertical
                @slug = beam_wall_vertical
                :top
                /i
                #put direction: @direction, shape: line, range: 25, slug: @slug, wait_cycles: @beam_wait_cycles, color: @color
                #send top
                """
    })
  end

  def beam_walls() do
    [ {"═", "north", "Horizontal"}, {"║", "west", "Vertical"} ]
    |> Enum.each(fn({char, facing, dir}) ->
      TileTemplates.update_or_create_tile_template!(
        "beam_wall_#{ String.downcase(dir) }",
        %{character: char,
          name: "Beam Wall #{ dir }",
          description: "#{ dir } beam wall",
          state: "blocking: true, facing: #{ facing }, wait_cycles: 5, damage: 5, blocking_light: false",
          public: false,
          active: true,
          script: """
                  #send shot, here
                  #push @facing, 0
                  #facing reverse
                  #push @facing, 0
                  /i
                  #die
                  """
      })
    end)
  end

  def clone_machine() do
    TileTemplates.update_or_create_tile_template!(
      "clone_machine",
      %{character: "0",
        name: "Clone Machine",
        description: "Copies from one side and pushes out the other",
        state: "facing: north, wait_cycles: 10, blocking: true",
        public: true,
        active: true,
        group_name: "misc",
        script: """
                :main
                /i
                #sequence char, ∙, ∘, o, O, 0
                #become character: @char
                #if @char != 0, main
                @clone_id = ?{@facing}@id
                #facing reverse
                #push @facing, 1
                #if not ?{@facing}@cloned, 2
                #if not ?{@facing}@blocking
                #sound alarm
                #put direction: @facing, clone: @clone_id, cloned: true
                #facing reverse
                #send main
                """
    })
  end

  def pushers do
    [ {"▲", "North"}, {"▶", "East"}, {"▼", "South"}, {"◀", "West"} ]
    |> Enum.each(fn({char, dir}) ->
         TileTemplates.update_or_create_tile_template!(
           "pusher_#{ String.downcase(dir) }",
           %{character: char,
             name: "Pusher #{ dir }",
             description: "Pushes to the #{ dir }",
             state: "blocking: true, wait_cycles: 10",
             color: "black",
             public: true,
             active: true,
             group_name: "misc",
             script: """
                     :thud
                     /i
                     #walk #{ String.downcase(dir) }
                     """
         })
      end)
  end

  def spinning_gun do
    TileTemplates.update_or_create_tile_template!(
      "spinning_gun",
      %{character: "↑",
        name: "Spinning Gun",
        description: "Spins and shoots bullets",
        state: "int: 5, freq: 5, blocking: true, facing: north",
        color: "black",
        public: true,
        active: true,
        group_name: "misc",
        script: """
                :main
                /i
                #sequence char, →, ↓, ←, ↑
                #become character: @char
                @rotations=4
                :spin
                #facing clockwise
                @rotations -= 1
                #if ?random@10 <= @int
                #if ?any_player@is_facing, shoot
                #if ?random@10 < @freq, shoot
                #if @rotations <= 0, main
                #send spin
                #end
                :shoot
                #sound shoot
                #shoot @facing
                #send spin
                """
    })
  end


  defmacro __using__(_params) do
    quote do
      def beam_wall_emitter(), do: unquote(__MODULE__).beam_wall_emitter()
      def beam_walls(), do: unquote(__MODULE__).beam_walls()
      def clone_machine(), do: unquote(__MODULE__).clone_machine()
      def pushers(), do: unquote(__MODULE__).pushers()
      def spinning_gun(), do: unquote(__MODULE__).spinning_gun()
    end
  end
end
