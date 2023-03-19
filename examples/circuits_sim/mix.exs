defmodule CircuitsSim.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description "Simulated hardware for Elixir Circuits"
  @source_url "https://github.com/elixir-circuits/circuits_i2c/examples/circuits_sim"

  def project do
    [
      app: :circuits_sim,
      version: @version,
      elixir: "~> 1.10",
      description: @description,
      package: package(),
      source_url: @source_url,
      docs: docs(),
      start_permanent: Mix.env() == :prod,
      dialyzer: [
        flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs]
      ],
      deps: deps(),
      preferred_cli_env: %{
        docs: :docs,
        "hex.publish": :docs,
        "hex.build": :docs
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {CircuitsSim.Application, []}
    ]
  end

  defp package do
    %{
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    }
  end

  defp deps() do
    [
      {:circuits_i2c, path: "../.."},
      {:ex_doc, "~> 0.22", only: :docs, runtime: false},
      {:credo, "~> 1.6", only: :dev, runtime: false},
      {:dialyxir, "~> 1.2", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
