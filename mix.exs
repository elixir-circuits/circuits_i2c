defmodule Circuits.I2C.MixProject do
  use Mix.Project

  @version "2.0.5"
  @description "Use I2C in Elixir"
  @source_url "https://github.com/elixir-circuits/circuits_i2c"

  def project do
    [
      app: :circuits_i2c,
      version: @version,
      elixir: "~> 1.13",
      description: @description,
      package: package(),
      source_url: @source_url,
      compilers: [:elixir_make | Mix.compilers()],
      elixirc_paths: elixirc_paths(Mix.env()),
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

  defp elixirc_paths(env) when env in [:test, :dev], do: ["lib", "examples"]
  defp elixirc_paths(_env), do: ["lib"]

  def application do
    # IMPORTANT: This provides a default at runtime and at compile-time when
    # circuits_i2c is pulled in as a dependency.
    [env: [default_backend: default_backend()]]
  end

  defp package do
    %{
      files: [
        "lib",
        "c_src/*.[ch]",
        "c_src/linux/*.h",
        "c_src/compat/linux/*.h",
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
      {:credo_binary_patterns, "~> 0.2.2", only: :dev, runtime: false},
      {:dialyxir, "~> 1.2", only: :dev, runtime: false},
      {:elixir_make, "~> 0.6", runtime: false}
    ]
  end

  defp docs do
    [
      assets: %{"assets" => "assets"},
      extras: ["README.md", "PORTING.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp default_backend(), do: default_backend(Mix.env(), Mix.target())
  defp default_backend(:test, _target), do: {Circuits.I2C.I2CDev, test: true}

  defp default_backend(_env, :host) do
    case :os.type() do
      {:unix, :linux} -> Circuits.I2C.I2CDev
      _ -> {Circuits.I2C.I2CDev, test: true}
    end
  end

  # MIX_TARGET set to something besides host
  defp default_backend(env, _not_host) do
    # If CROSSCOMPILE is set, then the Makefile will use the crosscompiler and
    # assume a Linux/Nerves build If not, then the NIF will be build for the
    # host, so use the default host backend
    case System.fetch_env("CROSSCOMPILE") do
      {:ok, _} -> Circuits.I2C.I2CDev
      :error -> default_backend(env, :host)
    end
  end

  defp set_make_env(_args) do
    # Since user configuration hasn't been loaded into the application
    # environment when `project/1` is called, load it here for building
    # the NIF.
    backend = Application.get_env(:circuits_i2c, :default_backend, default_backend())

    System.put_env("CIRCUITS_I2C_I2CDEV", i2c_dev_compile_mode(backend))
  end

  defp i2c_dev_compile_mode({Circuits.I2C.I2CDev, options}) do
    if Keyword.get(options, :test) do
      "test"
    else
      "normal"
    end
  end

  defp i2c_dev_compile_mode(Circuits.I2C.I2CDev) do
    "normal"
  end

  defp i2c_dev_compile_mode(_other) do
    "disabled"
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
