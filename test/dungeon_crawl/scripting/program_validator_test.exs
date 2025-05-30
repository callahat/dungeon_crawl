defmodule DungeonCrawl.Scripting.ProgramValidatorTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Scripting.Parser
  alias DungeonCrawl.Scripting.ProgramValidator

  def good_script do
    """
    #END
    :TOUCH
    #BECOME color: red, character: 9
    You touched it
    #IF @thing, MORE
    #END
    :MORE
    thing is true
    #IF @thing
    #MOVE south, true
    #GO south
    #CYCLE 3
    #GIVE ammo, 3, ?sender
    #TAKE @color+_key, 1, ?sender
    #BECOME character: @char
    #REMOVE target: north
    #REPLACE target: treasure, slug: scary_monster
    #PUSH south
    #PUSH @facing
    #PUSH @facing, @power
    #PUSH @facing, 1
    #SHIFT clockwise
    #GAMEOVER
    #GAMEOVER false
    #EQUIP gun, ?sender
    #EQUIP gun, ?sender, 2
    #UNEQUIP gun, north, MORE
    #SOUND powerdown, all
    """
  end

  def script_with_bad_command_params(slug \\ "") do
    """
    #END
    :TOUCH
    #BECOME color: #mm, character: aa
    You touched it
    #IF @thing, NOLABEL
    #BECOME slug: #{slug}
    @color = green
    #BECOME character:  , color:red
    #MOVE bananadyne, true
    #MOVE north, false
    #MOVE south
    #MOVE sooth
    #TRY banana
    #TRY north
    #GO south
    #GO hotpockets
    #FACING reverse
    #FACING inward
    #IF bio = tho, one, too many params
    #CYCLE 0
    #CYCLE false
    #ZAP TOUCH
    #ZAP THUD
    #RESTORE TOUCH
    #RESTORE THUD
    #SEND touch
    #SEND thud, all
    #SEND hi, all, 10, toomany
    #SEND touch, @facing
    #SHOOT @facing
    #SHOOT west
    #SHOOT idle
    #GIVE ammo, 3, ?sender
    #GIVE ammo, 3, idle
    #GIVE ammo, -1, ?sender
    #GIVE ammo, -1, goof
    #TAKE ammo, 3, ?sender, touch
    #TAKE ammo, -3, idle
    #TAKE ammo, 3, south, toopoor
    #TAKE ammo, one, goof, touch
    #TAKE ammo, 3, ?sender
    #IF @@bio == tho, touch
    #IF ?@@ == tho, touch
    #GIVE ammo, 3, ?sender, -3
    #GIVE ammo, 1, ?sender, 3, touch
    #GIVE ammo, 1, ?sender, 3, badtouch
    #BECOME slug: noexist
    #PUT slug: #{slug}, direction: north, color: yellow
    #PUT slug: noexist, row: 1, character: XXX
    #PUT garbage, north
    #REMOVE derp: north
    #REPLACE target: north, character: XX
    #REPLACE garbage params
    #REPLACE target: north, slug: #{slug}
    #PUSH waffle, -2
    #PUSH norf, 3
    #PUSH east, crayon
    #SHIFT neutral
    #IF ?random@10 < 2, touch
    #IF ?random@5552 < 2, touch
    #PASSAGE @background_color
    #PASSAGE
    #TRANSPORT ?sender, down
    #TRANSPORT ?sender, 2, @background_color
    #TRANSPORT ?sender, derp, @background_color
    #TRANSPORT ?sender, up, green, blue
    !TOUCH;Touch this or
    !NOLABEL;Click this
    #RANDOM var, a, b, c
    #RANDOM var
    #SEQUENCE var, a, b,c
    #SEQUENCE var
    #IF ?random@10
    #IF @badjump, 0
    #TARGET_PLAYER someone
    #TARGET_PLAYER
    @@bob ++= 9
    #RANDOM @var, a, b, c
    #RANDOM @@var, a, b, c
    #RANDOM &var, a, b, c
    #RANDOM ?sender, a, b, c
    ?south@blocking = false
    #GAMEOVER true, won, ?sender
    #GAMEOVER blah, ok, nigeria
    #GAMEOVER true, WIN
    &ALL ++= 42
    #EQUIP gun, norf, banana, nigeria
    #UNEQUIP gun, norf, nigeria
    #SOUND 123
    #SOUND bloop, yall
    #SOUND bloop, all, extra
    #SEND touch, self, 30
    ~moo,1
    """
  end

  describe "validate" do
    test "special keywords value cast is overridden" do
      {:ok, program} = Parser.parse("#BECOME character: 3")
      assert {:ok, program} == ProgramValidator.validate(program, nil)
    end

    test "program has no commands with bad parameters" do
      {:ok, program} = Parser.parse(nil)
      assert {:ok, program} == ProgramValidator.validate(program, nil)

      {:ok, program} = Parser.parse(nil)
      assert {:ok, program} == ProgramValidator.validate(program, nil)

      {:ok, program} = Parser.parse(good_script())
      assert {:ok, program} == ProgramValidator.validate(program, nil)

      user = insert_user()
      admin = insert_user(%{is_admin: true})
      tt = insert_tile_template(%{name: "Original Floor", active: true, user_id: admin.id})

      {:ok, program} = Parser.parse(script_with_bad_command_params(tt.slug))
      assert {:error,
              ["Line 3: BECOME command has errors: `color - has invalid format`",
               "Line 5: IF command references nonexistant label `NOLABEL`",
               "Line 6: BECOME command references a SLUG that you can't use `#{tt.slug}`",
               "Line 8: BECOME command params not being detected as kwargs `[\"character:\", \"color:red\"]`",
               "Line 9: MOVE command references invalid direction `bananadyne`",
               "Line 12: MOVE command references invalid direction `sooth`",
               "Line 13: TRY command references invalid direction `banana`",
               "Line 16: GO command references invalid direction `hotpockets`",
               "Line 18: FACING command references invalid direction `inward`",
               "Line 19: IF command malformed",
               "Line 20: CYCLE command has invalid param `0`",
               "Line 21: CYCLE command has invalid param `false`",
               "Line 23: ZAP command references nonexistant label `THUD`",
               "Line 25: RESTORE command references nonexistant label `THUD`",
               "Line 28: SEND command has an invalid number of parameters",
               "Line 32: SHOOT command references invalid direction `idle`",
               "Line 34: GIVE command references invalid direction `idle`",
               "Line 35: GIVE command has invalid amount `-1`",
               "Line 36: GIVE command has invalid amount `-1`",
               "Line 36: GIVE command references invalid direction `goof`",
               "Line 38: TAKE command has invalid amount `-3`",
               "Line 38: TAKE command references invalid direction `idle`",
               "Line 39: TAKE command references nonexistant label `toopoor`",
               "Line 40: TAKE command has invalid amount `one`",
               "Line 40: TAKE command references invalid direction `goof`",
               "Line 43: IF command malformed",
               "Line 44: GIVE command has invalid maximum amount `-3`",
               "Line 46: GIVE command references nonexistant label `badtouch`",
               "Line 47: BECOME command references a SLUG that does not match a template `noexist`",
               "Line 48: PUT command references a SLUG that you can't use `original_floor`",
               "Line 49: PUT command references a SLUG that does not match a template `noexist`",
               "Line 49: PUT command must have both row and col or neither: `row: 1, col: <nil>`",
               "Line 50: PUT command params not being detected as kwargs `[\"garbage\", \"north\"]`",
               "Line 51: REMOVE command has no target KWARGs: `%{\"derp\" => \"north\"}`",
               "Line 53: REPLACE command params not being detected as kwargs `[\"garbage params\"]`",
               "Line 54: REPLACE command references a SLUG that you can't use `#{tt.slug}`",
               "Line 55: PUSH command references invalid direction `waffle`",
               "Line 55: PUSH command has invalid range `-2`",
               "Line 56: PUSH command references invalid direction `norf`",
               "Line 57: PUSH command has invalid range `crayon`",
               "Line 58: SHIFT command references invalid rotation `neutral`",
               "Line 60: IF command malformed",
               "Line 62: PASSAGE command has invalid params `[\"\"]`",
               "Line 65: TRANSPORT command level kwarg is invalid: `derp`",
               "Line 66: TRANSPORT command has invalid number of params: `[[:event_sender], \"up\", \"green\", \"blue\"]`",
               "Line 68: TEXT command references nonexistant label `NOLABEL`",
               "Line 70: RANDOM command has an invalid number of parameters",
               "Line 72: SEQUENCE command has an invalid number of parameters",
               "Line 74: IF command jump distance must be positive `0`",
               "Line 75: TARGET_PLAYER command specifies invalid target `someone`",
               "Line 76: TARGET_PLAYER command specifies invalid target ``",
               "Line 77: CHANGE command ++ takes only one operand, got `= 9`",
               "Line 81: RANDOM command has an invalid variable specified [:event_sender]",
               "Line 84: GAMEOVER command has invalid 1st parameter `blah`",
               "Line 84: GAMEOVER command has invalid 3rd parameter `nigeria`",
               "Line 86: CHANGE command ++ takes only one operand, got `= 42`",
               "Line 87: EQUIP command references invalid direction `norf`",
               "Line 87: EQUIP command has invalid maximum amount `banana`",
               "Line 87: EQUIP command references nonexistant label `nigeria`",
               "Line 88: UNEQUIP command references invalid direction `norf`",
               "Line 88: UNEQUIP command references nonexistant label `nigeria`",
               "Line 89: SOUND command references invalid slug `123`",
               "Line 90: SOUND command references invalid target `yall`",
               "Line 91: SOUND command has invalid params `[\"bloop\", \"all\", \"extra\"]`",
               "Line 93: TEXT conditional is invalid"
              ],
              program} == ProgramValidator.validate(program, user)
      assert {:error,
              ["Line 3: BECOME command has errors: `color - has invalid format`",
               "Line 5: IF command references nonexistant label `NOLABEL`",
               "Line 8: BECOME command params not being detected as kwargs `[\"character:\", \"color:red\"]`",
               "Line 9: MOVE command references invalid direction `bananadyne`",
               "Line 12: MOVE command references invalid direction `sooth`",
               "Line 13: TRY command references invalid direction `banana`",
               "Line 16: GO command references invalid direction `hotpockets`",
               "Line 18: FACING command references invalid direction `inward`",
               "Line 19: IF command malformed",
               "Line 20: CYCLE command has invalid param `0`",
               "Line 21: CYCLE command has invalid param `false`",
               "Line 23: ZAP command references nonexistant label `THUD`",
               "Line 25: RESTORE command references nonexistant label `THUD`",
               "Line 28: SEND command has an invalid number of parameters",
               "Line 32: SHOOT command references invalid direction `idle`",
               "Line 34: GIVE command references invalid direction `idle`",
               "Line 35: GIVE command has invalid amount `-1`",
               "Line 36: GIVE command has invalid amount `-1`",
               "Line 36: GIVE command references invalid direction `goof`",
               "Line 38: TAKE command has invalid amount `-3`",
               "Line 38: TAKE command references invalid direction `idle`",
               "Line 39: TAKE command references nonexistant label `toopoor`",
               "Line 40: TAKE command has invalid amount `one`",
               "Line 40: TAKE command references invalid direction `goof`",
               "Line 43: IF command malformed",
               "Line 44: GIVE command has invalid maximum amount `-3`",
               "Line 46: GIVE command references nonexistant label `badtouch`",
               "Line 47: BECOME command references a SLUG that does not match a template `noexist`",
               "Line 49: PUT command references a SLUG that does not match a template `noexist`",
               "Line 49: PUT command must have both row and col or neither: `row: 1, col: <nil>`",
               "Line 50: PUT command params not being detected as kwargs `[\"garbage\", \"north\"]`",
               "Line 51: REMOVE command has no target KWARGs: `%{\"derp\" => \"north\"}`",
               "Line 53: REPLACE command params not being detected as kwargs `[\"garbage params\"]`",
               "Line 55: PUSH command references invalid direction `waffle`",
               "Line 55: PUSH command has invalid range `-2`",
               "Line 56: PUSH command references invalid direction `norf`",
               "Line 57: PUSH command has invalid range `crayon`",
               "Line 58: SHIFT command references invalid rotation `neutral`",
               "Line 60: IF command malformed",
               "Line 62: PASSAGE command has invalid params `[\"\"]`",
               "Line 65: TRANSPORT command level kwarg is invalid: `derp`",
               "Line 66: TRANSPORT command has invalid number of params: `[[:event_sender], \"up\", \"green\", \"blue\"]`",
               "Line 68: TEXT command references nonexistant label `NOLABEL`",
               "Line 70: RANDOM command has an invalid number of parameters",
               "Line 72: SEQUENCE command has an invalid number of parameters",
               "Line 74: IF command jump distance must be positive `0`",
               "Line 75: TARGET_PLAYER command specifies invalid target `someone`",
               "Line 76: TARGET_PLAYER command specifies invalid target ``",
               "Line 77: CHANGE command ++ takes only one operand, got `= 9`",
               "Line 81: RANDOM command has an invalid variable specified [:event_sender]",
               "Line 84: GAMEOVER command has invalid 1st parameter `blah`",
               "Line 84: GAMEOVER command has invalid 3rd parameter `nigeria`",
               "Line 86: CHANGE command ++ takes only one operand, got `= 42`",
               "Line 87: EQUIP command references invalid direction `norf`",
               "Line 87: EQUIP command has invalid maximum amount `banana`",
               "Line 87: EQUIP command references nonexistant label `nigeria`",
               "Line 88: UNEQUIP command references invalid direction `norf`",
               "Line 88: UNEQUIP command references nonexistant label `nigeria`",
               "Line 89: SOUND command references invalid slug `123`",
               "Line 90: SOUND command references invalid target `yall`",
               "Line 91: SOUND command has invalid params `[\"bloop\", \"all\", \"extra\"]`",
               "Line 93: TEXT conditional is invalid"
              ],
              program} == ProgramValidator.validate(program, admin)
    end
  end
end
