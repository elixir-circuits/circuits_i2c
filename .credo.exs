# .credo.exs
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "examples/"],
        excluded: ["lib/i2c/i2c_nif.ex"]
      },
      strict: true,
      checks: [
        {CredoBinaryPatterns.Check.Consistency.Pattern},
        {Credo.Check.Refactor.MapInto, false},
        {Credo.Check.Warning.LazyLogging, false},
        {Credo.Check.Readability.LargeNumbers, only_greater_than: 86400},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, parens: true},
        {Credo.Check.Readability.Specs, tags: []},
        {Credo.Check.Readability.StrictModuleLayout, tags: []}
      ]
    }
  ]
}
