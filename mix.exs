defmodule Circuits.I2C.MixProject do
  use Mix.Project

  @version "1.2.1"
  @description "Use I2C in Elixir"
  @source_url "https://github.com/elixir-circuits/circuits_i2c"

  def project do
    [
      app: :circuits_i2c,
      version: @version,
      elixir: "~> 1.10",
      description: @description,
      package: package(),
      source_url: @source_url,
      compilers: [:elixir_make | Mix.compilers()],
      make_targets: ["all"],
      make_clean: ["clean"],
      docs: docs(),
      aliases: [compile: [&set_make_env/1, "compile"], format: [&format_c/1, "format"]],
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
    # IMPORTANT: This provides a default at runtime and at compile-time when
    # circuits_i2c is pulled in as a dependency. It is not available at compile-time
    # when using circuits_i2c directly nor in Makefiles. See the CIRCUITS_BACKEND
    # OS environment variable.
    [env: [backend: default_backend()]]
  end

  defp package do
    %{
      files: [
        "lib",
        "c_src/*.[ch]",
        "c_src/linux/i2c-dev.h",
        "mix.exs",
        "README.md",
        "PORTING.md",
        "LICENSE",
        "CHANGELOG.md",
        "Makefile"
      ],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    }
  end

  defp deps() do
    [
      {:ex_doc, "~> 0.22", only: :docs, runtime: false},
      {:credo, "~> 1.6", only: :dev, runtime: false},
      {:dialyxir, "~> 1.2", only: :dev, runtime: false},
      {:elixir_make, "~> 0.6", runtime: false}
    ]
  end

  defp docs do
    [
      assets: "assets",
      extras: ["README.md", "PORTING.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp default_backend(), do: default_backend(Mix.env(), Mix.target())
  defp default_backend(:test, _target), do: :i2c_dev_test

  defp default_backend(_env, :host) do
    case :os.type() do
      {:unix, :i2c_dev} -> :i2c_dev
      _ -> :i2c_dev_test
    end
  end

  # Assume Nerves for a default
  defp default_backend(_env, _not_host), do: :i2c_dev

  defp set_make_env(_args) do
    # Since user configuration hasn't been loaded into the application
    # environment when `project/1` is called, load it here for building
    # the NIF.
    backend = Application.get_env(:circuits_i2c, :backend, default_backend())

    System.put_env("CIRCUITS_BACKEND", to_string(backend))
  end

  defp format_c([]) do
    case System.find_executable("astyle") do
      nil ->
        Mix.Shell.IO.info("Install astyle to format C code.")

      astyle ->
        System.cmd(astyle, ["-n", "c_src/*.c"], into: IO.stream(:stdio, :line))
    end
  end

  defp format_c(_args), do: true
end
