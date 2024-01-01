defmodule DungeonCrawlWeb.ExportFixture do
  # Basically the result of Jason.decode
  def export do
    %DungeonCrawl.Shipping.DungeonExports{
      dungeon: %{
        autogenerated: false,
        default_map_height: 20,
        default_map_width: 20,
        description: "testing",
        line_identifier: 1,
        name: "Exporter",
        state: %{"starting_equipment" => ["tmp_item_id_0", "tmp_item_id_2"], "test" => true},
        title_number: 2,
        user_name: "Some User"
      },
      items: %{
        "tmp_item_id_0" => %{
          consumable: false,
          description: "It shoots bullets",
          name: "Gun",
          public: true,
          script: "#take ammo, 1, ?self, error\n#shoot @facing\n#sound tmp_sound_id_4\n#end\n:error\nOut of ammo!\n#sound tmp_sound_id_2\n",
          slug: "gun",
          temp_item_id: "tmp_item_id_0",
          user_id: nil,
          weapon: true
        },
        "tmp_item_id_1" => %{
          consumable: true,
          description: "A small chunk of the planets crust, easily tossed.",
          name: "Stone",
          public: true,
          script: "#put direction: here, slug: tmp_tt_id_7, facing: @facing, thrown: true\n",
          slug: "stone",
          temp_item_id: "tmp_item_id_1",
          user_id: nil,
          weapon: true
        },
        "tmp_item_id_2" => %{
          consumable: false,
          description: "It shoots exploding fireballs, may break if a gem cannot be consumed",
          name: "Fireball Wand",
          public: true,
          script: "#put direction: here, slug: tmp_tt_id_5, facing: @facing, owner: ?self\n#take gems, 1, ?self, it_might_break\n#end\n:it_might_break\n#if ?random@10 != 10, 1\n#end\nThe wand broke!\n#if ?random@4 != 4, 2\n#put slug: tmp_tt_id_6, shape: circle, range: 3, damage: 10, owner: ?self\n#sound tmp_sound_id_1\n#die\n",
          slug: "fireball_wand",
          temp_item_id: "tmp_item_id_2",
          user_id: nil,
          weapon: true
        }
      },
      levels: %{
        1 => %{
          entrance: nil,
          height: 20,
          name: "Stubbed",
          number: 1,
          number_east: nil,
          number_north: nil,
          number_south: nil,
          number_west: nil,
          state: %{},
          tile_data: [],
          width: 20
        },
        2 => %{
          entrance: true,
          height: 20,
          name: "one",
          number: 2,
          number_east: nil,
          number_north: 3,
          number_south: nil,
          number_west: nil,
          state: %{},
          tile_data: [
            ["lL2wYqn3w87XJdNEL9ILgkTlxzc=", 0, 1, 0],
            ["B/4FiuxvsdZqQUvsinnOSALs730=", 0, 2, 0],
            ["lL2wYqn3w87XJdNEL9ILgkTlxzc=", 0, 3, 0],
            ["lL2wYqn3w87XJdNEL9ILgkTlxzc=", 1, 1, 0],
            ["tkkzlR+LnYgle2hGYATT2KcG4PM=", 1, 2, 0],
            ["lL2wYqn3w87XJdNEL9ILgkTlxzc=", 1, 3, 0],
            ["NOjz7ST8416i6lrYmRYEPpjjdU0=", 2, 1, 0],
            ["NOjz7ST8416i6lrYmRYEPpjjdU0=", 2, 2, 0],
            ["NOjz7ST8416i6lrYmRYEPpjjdU0=", 2, 3, 0]
          ],
          width: 20
        },
        3 => %{
          entrance: nil,
          height: 20,
          name: "Stubbed",
          number: 3,
          number_east: nil,
          number_north: nil,
          number_south: nil,
          number_west: nil,
          state: %{"visibility" => "fog"},
          tile_data: [
            ["lL2wYqn3w87XJdNEL9ILgkTlxzc=", 0, 1, 0],
            ["lL2wYqn3w87XJdNEL9ILgkTlxzc=", 0, 2, 0],
            ["XMuFul9Dl0e4Twpbu09Irw4BY2A=", 1, 1, 0],
            ["cfgMQZYjq1QUzRMqduZVm3Y2m9g=", 1, 2, 1]
          ],
          width: 20
        }
      },
      sounds: %{
        "tmp_sound_id_0" => %{
          name: "Alarm",
          public: true,
          slug: "alarm",
          temp_sound_id: "tmp_sound_id_0",
          user_id: nil,
          zzfx_params: "[,0,130.8128,.1,.1,.34,3,1.88,,,,,,,,.1,,.5,.04]"
        },
        "tmp_sound_id_1" => %{
          name: "Bomb",
          public: true,
          slug: "bomb",
          temp_sound_id: "tmp_sound_id_1",
          user_id: nil,
          zzfx_params: "[3,,485,.02,.2,.2,4,.11,-3,.1,,,.05,1.1,,.4,,.57,.5]"
        },
        "tmp_sound_id_2" => %{
          name: "Click",
          public: true,
          slug: "click",
          temp_sound_id: "tmp_sound_id_2",
          user_id: nil,
          zzfx_params: "[,0,521.25,,.02,.03,2,0,,.1,700,.01,,,1,.1]"
        },
        "tmp_sound_id_3" => %{
          name: "Door",
          public: true,
          slug: "door",
          temp_sound_id: "tmp_sound_id_3",
          user_id: nil,
          zzfx_params: "[2.13,0,423,.01,.01,.05,4,2.51,,,,,,1.5,,.3,.12,.71,.01]"
        },
        "tmp_sound_id_4" => %{
          name: "Shoot",
          public: true,
          slug: "shoot",
          temp_sound_id: "tmp_sound_id_4",
          user_id: nil,
          zzfx_params: "[1.5,,100,,.05,.04,4,1.44,3,,,,,,,.1,,.3,.05]"
        },
        "tmp_sound_id_5" => %{
          name: "Pickup Blip",
          public: true,
          slug: "pickup_blip",
          temp_sound_id: "tmp_sound_id_5",
          user_id: nil,
          zzfx_params: "[3.9,,83,,.01,.02,2,.46,-1.5,34.8,5,.18,,-0.1,-364,-0.1,.09,1.1,.01,.03]"
        }
      },
      spawn_locations: [[2, 0, 1], [2, 0, 3], [3, 1, 1]],
      tile_templates: %{
        "tmp_tt_id_0" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: ".",
          color: nil,
          description: "Just a dusty floor",
          group_name: "terrain",
          name: "Floor",
          public: true,
          script: "",
          slug: "floor",
          state: %{"blocking" => false},
          temp_tt_id: "tmp_tt_id_0",
          unlisted: false,
          user_id: nil
        },
        "tmp_tt_id_1" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: "#",
          color: nil,
          description: "A Rough wall",
          group_name: "terrain",
          name: "Wall",
          public: true,
          script: "",
          slug: "wall",
          state: %{"blocking" => true},
          temp_tt_id: "tmp_tt_id_1",
          unlisted: false,
          user_id: nil
        },
        "tmp_tt_id_2" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: " ",
          color: nil,
          description: "Impassible stone",
          group_name: "terrain",
          name: "Rock",
          public: true,
          script: "",
          slug: "rock",
          state: %{"blocking" => true},
          temp_tt_id: "tmp_tt_id_2",
          unlisted: false,
          user_id: nil
        },
        "tmp_tt_id_3" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: "'",
          color: nil,
          description: "An open door",
          group_name: "doors",
          name: "Open Door",
          public: true,
          script: "#END\n:CLOSE\n#SOUND tmp_sound_id_3\n#BECOME slug: tmp_tt_id_4",
          slug: "open_door",
          state: %{"blocking" => false, "open" => true},
          temp_tt_id: "tmp_tt_id_3",
          unlisted: false,
          user_id: nil
        },
        "tmp_tt_id_4" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: "+",
          color: nil,
          description: "A closed door",
          group_name: "doors",
          name: "Closed Door",
          public: true,
          script: "#END\n:OPEN\n#SOUND tmp_sound_id_3\n#BECOME slug: tmp_tt_id_3",
          slug: "closed_door",
          state: %{"blocking" => true, "open" => false},
          temp_tt_id: "tmp_tt_id_4",
          unlisted: false,
          user_id: nil
        },
        "tmp_tt_id_5" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: "◦",
          color: "orange",
          description: "Its a bullet.",
          group_name: "custom",
          name: "Fireball",
          public: true,
          script: ":MAIN\n#WALK @facing\n:THUD\n#SOUND tmp_sound_id_1\n#PUT slug: tmp_tt_id_6, shape: circle, range: 2, damage: 10, owner: @owner\n#DIE\n",
          slug: "fireball",
          state: %{"blocking" => false, "wait_cycles" => 2, "not_pushing" => true, "not_squishing" => true, "flying" => true, "light_source" => true, "light_range" => 2},
          temp_tt_id: "tmp_tt_id_5",
          unlisted: true,
          user_id: nil
        },
        "tmp_tt_id_6" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: "▒",
          color: "crimson",
          description: "Caught up in the explosion",
          group_name: "misc",
          name: "Explosion",
          public: true,
          script: "#SEND bombed, here\n:TOP\n#RANDOM c, red, orange, yellow\n#BECOME color: @c\n?i\n@count -= 1\n#IF @count > 0, top\n#DIE\n",
          slug: "explosion",
          state: %{"count" => 3, "damage" => 10, "light_source" => true, "light_range" => 1},
          temp_tt_id: "tmp_tt_id_6",
          unlisted: true,
          user_id: nil
        },
        "tmp_tt_id_7" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: "*",
          color: "gray",
          description: "A small stone fits nicely in the palm of your hand",
          group_name: "items",
          name: "Stone",
          public: true,
          script: "#if @thrown, thrown\n:main\n#end\n:touch\n#if ! ?sender@player, main\nPicked up a stone\n#equip tmp_item_id_1, ?sender\n#sound tmp_sound_id_5, ?sender\n#die\n:thrown\n#zap touch\n@flying = true\n#walk @facing\n:thud\n:touch\n@flying=false\n#restore thrown\n#restore touch\n#send shot, ?sender\n#send main\n",
          slug: "stone",
          state: %{"blocking" => false, "soft" => true, "pushable" => true, "blocking_light" => false, "damage" => 5, "not_pushing" => true, "wait_cycles" => 2},
          temp_tt_id: "tmp_tt_id_7",
          unlisted: false,
          user_id: nil
        }
      },
      tiles: %{
        "cfgMQZYjq1QUzRMqduZVm3Y2m9g=" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: "x",
          color: nil,
          name: "",
          script: "#end\n:touch\n#sound tmp_sound_id_0\n#equip tmp_item_id_1, ?sender\n#become slug: tmp_tt_id_1\n#unequip tmp_item_id_0, ?sender\n/i\n#sound tmp_sound_id_0",
          state: %{"blocking" => true},
          tile_template_id: nil
        },
        "B/4FiuxvsdZqQUvsinnOSALs730=" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: " ",
          color: nil,
          name: "Rock",
          script: "",
          state: %{"blocking" => true},
          tile_template_id: "tmp_tt_id_2"
        },
        "XMuFul9Dl0e4Twpbu09Irw4BY2A=" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: ".",
          color: nil,
          name: "Floor 2",
          script: "",
          state: %{"light_source" => true},
          tile_template_id: "tmp_tt_id_0"
        },
        "lL2wYqn3w87XJdNEL9ILgkTlxzc=" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: ".",
          color: nil,
          name: "Floor",
          script: "",
          state: %{"blocking" => false},
          tile_template_id: "tmp_tt_id_0"
        },
        "tkkzlR+LnYgle2hGYATT2KcG4PM=" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: "+",
          color: nil,
          name: "Closed Door",
          script: "#END\n:OPEN\n#SOUND tmp_sound_id_3\n#BECOME slug: tmp_tt_id_3",
          state: %{"blocking" => true, "open" => false},
          tile_template_id: "tmp_tt_id_4"
        },
        "NOjz7ST8416i6lrYmRYEPpjjdU0=" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: "#",
          color: nil,
          name: "Wall",
          script: "",
          state: %{"blocking" => true},
          tile_template_id: "tmp_tt_id_1"
        }
      },
      status: "running"
    }
  end

  def minimal_export do
    %DungeonCrawl.Shipping.DungeonExports{
      dungeon: %{
        autogenerated: false,
        default_map_height: 20,
        default_map_width: 20,
        description: "minimal dungeon",
        line_identifier: 235,
        name: "Minimal",
        state: %{},
        title_number: nil,
        user_name: "Doc"
      },
      levels: %{
        1 => %{
          entrance: false,
          height: 20,
          name: nil,
          number: 1,
          number_east: nil,
          number_north: nil,
          number_south: nil,
          number_west: nil,
          state: %{},
          tile_data: [
            ["thing_hash", 0, 0, 0],
            ["rock_hash", 0, 1, 0]
          ],
          width: 20
        }
      },
      tiles: %{
        "rock_hash" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: " ",
          color: nil,
          name: "Rock",
          script: "",
          state: %{"blocking" => true},
          tile_template_id: "tmp_tt_id_0"
        },
        "thing_hash" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: "!",
          color: nil,
          name: "Thing",
          script: "#end\n:touch\n#sound tmp_sound_id_0\n#equip tmp_item_id_1, ?sender\n#become slug: tmp_tt_id_0",
          state: %{"blocking" => true},
          tile_template_id: nil
        }
      },
      items: %{
        "tmp_item_id_0" => %{
          consumable: false,
          description: "It shoots bullets",
          name: "Gun",
          public: true,
          script: "#take ammo, 1, ?self, error\n#shoot @facing\n#sound tmp_sound_id_2\n#end\n:error\nOut of ammo!\n#sound tmp_sound_id_0\n",
          slug: "gun",
          temp_item_id: "tmp_item_id_0",
          user_id: 1,
          weapon: true
        },
        "tmp_item_id_1" => %{
          consumable: true,
          description: "A small chunk of the planets crust, easily tossed.",
          name: "Stone",
          public: true,
          script: "#put direction: here, slug: tmp_tt_id_1, facing: @facing, thrown: true\n",
          slug: "stone",
          temp_item_id: "tmp_item_id_1",
          user_id: 1,
          weapon: true
        }
      },
      tile_templates: %{
        "tmp_tt_id_0" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: " ",
          color: nil,
          description: "Impassible stone",
          group_name: "terrain",
          name: "Rock",
          public: true,
          script: "",
          slug: "rock",
          state: %{"blocking" => true},
          temp_tt_id: "tmp_tt_id_0",
          unlisted: false,
          user_id: nil
        },
        "tmp_tt_id_1" => %{
          animate_background_colors: nil,
          animate_characters: nil,
          animate_colors: nil,
          animate_period: nil,
          animate_random: nil,
          background_color: nil,
          character: "*",
          color: "gray",
          description: "A small stone fits nicely in the palm of your hand",
          group_name: "items",
          name: "Stone",
          public: true,
          script: "#if @thrown, thrown\n:main\n#end\n:touch\n#if ! ?sender@player, main\nPicked up a stone\n#equip tmp_item_id_1, ?sender\n#sound tmp_sound_id_1, ?sender\n#die\n:thrown\n#zap touch\n@flying = true\n#walk @facing\n:thud\n:touch\n@flying=false\n#restore thrown\n#restore touch\n#send shot, ?sender\n#send main\n",
          slug: "stone",
          state: %{
            "blocking" => false,
            "blocking_light" => false,
            "damage" => 5,
            "not_pushing" => true,
            "pushable" => true,
            "soft" => true,
            "wait_cycles" => 2
          },
          temp_tt_id: "tmp_tt_id_1",
          unlisted: false,
          user_id: nil
        }
      },
      sounds: %{
        "tmp_sound_id_0" => %{
          name: "Click",
          public: true,
          slug: "click",
          temp_sound_id: "tmp_sound_id_0",
          user_id: nil,
          zzfx_params: "[,0,521.25,,.02,.03,2,0,,.1,700,.01,,,1,.1]"
        },
        "tmp_sound_id_1" => %{
          name: "Pickup Blip",
          public: true,
          slug: "pickup_blip",
          temp_sound_id: "tmp_sound_id_1",
          user_id: nil,
          zzfx_params: "[3.9,,83,,.01,.02,2,.46,-1.5,34.8,5,.18,,-0.1,-364,-0.1,.09,1.1,.01,.03]"
        },
        "tmp_sound_id_2" => %{
          name: "Shoot",
          public: true,
          slug: "shoot",
          temp_sound_id: "tmp_sound_id_2",
          user_id: nil,
          zzfx_params: "[1.5,,100,,.05,.04,4,1.44,3,,,,,,,.1,,.3,.05]"
        }
      },
      spawn_locations: [],
      status: "running"
    }

  end
end
