defmodule DungeonCrawl.SharedTests do
  defmacro handles_state_variables_and_values_correctly(module) do
    quote do
      test "changeset with state_variables and state_values virtual fields" do
        # state_variables and state_values will override state if they're well formed
        state = "foo: bar"
        bad_attrs = %{state_variables: ["one", "two"], state_values: ["1"]}
        good_attrs = %{state_variables: ["one", "two"], state_values: ["1", "2"]}
        # when invalid state_variables/values, keeps them in the changeset
        # lopsided
        changeset = unquote(module).changeset(%unquote(module){state: state}, bad_attrs)
        assert changeset.changes == bad_attrs
        assert changeset.errors[:base] == {"state_variables and state_values are of different lengths", []}
        # missing
        changeset = unquote(module).changeset(%unquote(module){state: state}, Map.delete(good_attrs, :state_variables))
        assert changeset.errors[:state_variables] == {"must be present and have same number of elements as state_values", []}
        changeset = unquote(module).changeset(%unquote(module){state: state}, Map.delete(good_attrs, :state_values))
        assert changeset.errors[:state_values] == {"must be present and have same number of elements as state_variables", []}
        # good attrs, state_variables and state_values virtual fields are deleted and state is added to the changeset
        changeset = unquote(module).changeset(%unquote(module){state: state}, good_attrs)
        assert changeset.changes == %{state: "one: 1, two: 2"}
        refute changeset.errors[:state_variables]
        refute changeset.errors[:state_values]
        refute changeset.errors[:base]
      end
    end
  end
end
