defmodule DungeonCrawl.Scripting.MathsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Scripting.Maths

  doctest Maths

  describe "calc with incompatible types - whatever isn't float or int becomes a 0" do
    test "Binaries" do
      assert Maths.calc("bob", "++", 9) == 1
      assert Maths.calc("bob", "+=", 9) == 9
      assert Maths.calc(9, "-=", "bob") == 9
      assert Maths.calc("Nine", "+=", "one") == 0
    end

    test "Booleans" do
      assert Maths.calc(true, "--", 9) == -1
      assert Maths.calc(9, "*=", false) == 0
      assert Maths.calc(true, "-=", 9) == -9
      assert Maths.calc(true, "+=", false) == 0
    end

    test "floats" do
      assert Maths.calc(1.5, "++", "doenstmatter") == 2.5
      assert Maths.calc(1.5, "+=", "10") == 1.5
      assert Maths.calc(1.5, "+=", 10) == 11.5
      assert Maths.calc(4.0, "-=", 0.859) == 3.141
    end

    test "Atoms" do
      assert Maths.calc(:one, "-=", 5) == -5
      assert Maths.calc(:two, "+=", :tree) == 0
      assert Maths.calc(100, "*=", :bob) == 0
    end

    test "Cannot divide by zero" do
      assert Maths.calc(99, "/=", "zero") == 99
      assert Maths.calc(99, "/=", 0) == 99
    end
  end
end
