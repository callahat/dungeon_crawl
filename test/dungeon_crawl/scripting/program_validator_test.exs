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
    """
  end

  def script_with_bad_command_params do
    """
    #END
    :TOUCH
    #BECOME color: red, character: aa
    You touched it
    #IF @thing, NOLABEL
    """
  end

  describe "validate" do
    test "program has no commands with bad parameters" do
      {:ok, program} = Parser.parse(nil)
      assert {:ok, program} == ProgramValidator.validate(program)

      {:ok, program} = Parser.parse(nil)
      assert {:ok, program} == ProgramValidator.validate(program)

      {:ok, program} = Parser.parse(good_script())
      assert {:ok, program} == ProgramValidator.validate(program)

      {:ok, program} = Parser.parse(script_with_bad_command_params())
      assert {:error,
              ["Line 3: BECOME command has errors: `character - should be at most 1 character(s)`",
               "Line 5: IF command references nonexistant label `NOLABEL`"],
              program} == ProgramValidator.validate(program)
    end
  end
end
