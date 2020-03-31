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
    #MOVE south, true
    #GO south
    #CYCLE 3
    """
  end

  def script_with_bad_command_params(ttid \\ 0, ttid2 \\ 1) do
    """
    #END
    :TOUCH
    #BECOME color: red, character: aa
    You touched it
    #IF @thing, NOLABEL
    #BECOME TTID:#{ttid}
    #BECOME TTID:#{ttid2}
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
    #IF bio = tho
    #CYCLE 0
    #CYCLE false
    #ZAP TOUCH
    #ZAP THUD
    #RESTORE TOUCH
    #RESTORE THUD
    #SEND touch
    #SEND thud, all
    #SEND hi, all, toomany
    #SEND touch, @facing
    #SHOOT @facing
    #SHOOT west
    #SHOOT idle
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
      tt = insert_tile_template()
      tt2 = insert_tile_template(%{user_id: user.id, active: true})

      {:ok, program} = Parser.parse(script_with_bad_command_params(tt.id, tt2.id))
      assert {:error,
              ["Line 3: BECOME command has errors: `character - should be at most 1 character(s)`",
               "Line 5: IF command references nonexistant label `NOLABEL`",
               "Line 6: BECOME command references a TTID that you can't use `#{tt.id}`",
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
              ],
              program} == ProgramValidator.validate(program, user)
      assert {:error,
              ["Line 3: BECOME command has errors: `character - should be at most 1 character(s)`",
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
              ],
              program} == ProgramValidator.validate(program, admin)
    end
  end
end
