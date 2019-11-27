defmodule DungeonCrawl.Scripting.ProgramValidatorTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Scripting.Parser
  alias DungeonCrawl.Scripting.ProgramValidator

  def good_script do
    """
    #END
    :TOUCH
    #BECOME color: red
    You touched it
    #IF @thing, MORE
    #END
    :MORE
    thing is true
    #MOVE south, true
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
    #MOVE banana, true
    #MOVE north, false
    #MOVE south
    #MOVE hotpockets
    """
  end

  describe "validate" do
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
               "Line 9: MOVE command references invalid direction `banana`",
               "Line 12: MOVE command references invalid direction `hotpockets`"],
              program} == ProgramValidator.validate(program, user)
      assert {:error,
              ["Line 3: BECOME command has errors: `character - should be at most 1 character(s)`",
               "Line 5: IF command references nonexistant label `NOLABEL`",
               "Line 8: BECOME command params not being detected as kwargs `[\"character:\", \"color:red\"]`",
               "Line 9: MOVE command references invalid direction `banana`",
               "Line 12: MOVE command references invalid direction `hotpockets`"],
              program} == ProgramValidator.validate(program, admin)
    end
  end
end
