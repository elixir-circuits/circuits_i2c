defmodule Circuits.I2C.MixProject do
  use Mix.Project

  @app :circuits_i2c
  @version "2.1.0"
  @description "Use I2C in Elixir"
  @source_url "https://github.com/elixir-circuits/#{@app}"

  def project do
    base = [
      app: @app,
      version: @version,
      elixir: "~> 1.13",
      description: @description,
      package: package(),
      source_url: @source_url,
      docs: docs(),
      start_permanent: Mix.env() == :prod,
      dialyzer: [
        flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs]
      ],
      deps: deps()
    ]

    if build_i2c_dev?() do
      additions = [
        compilers: [:elixir_make | Mix.compilers()],
        elixirc_paths: ["lib", "i2c_dev/lib"],
        make_targets: ["all"],
        make_clean: ["clean"],
        aliases: [compile: [&set_make_env/1, "compile"], format: [&format_c/1, "format"]]
      ]

      Keyword.merge(base, additions)
    else
      base
    end
  end

  def cli do
    [preferred_envs: %{docs: :docs, "hex.publish": :docs, "hex.build": :docs}]
  end

  def application do
    # IMPORTANT: This provides defaults at runtime and at compile-time when
    # circuits_i2c is pulled in as a dependency.
    [env: [default_backend: default_backend(), build_i2c_dev: false]]
  end

  defp package do
    %{
      files: [
        "CHANGELOG.md",
        "i2c_dev/c_src/*.[ch]",
        "i2c_dev/c_src/linux/*.h",
        "i2c_dev/c_src/compat/linux/*.h",
        "i2c_dev/lib",
        "lib",
        "LICENSES",
        "Makefile",
        "mix.exs",
        "NOTICE",
        "PORTING.md",
        "README.md",
        "REUSE.toml"
      ],
      licenses: ["Apache-2.0"],
      links: %{
        "Changelog" => "https://hexdocs.pm/#{@app}/changelog.html",
        "GitHub" => @source_url,
        "REUSE Compliance" => "https://api.reuse.software/info/github.com/elixir-circuits/#{@app}"
      }
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

  defp build_i2c_dev?() do
    include_i2c_dev = Application.get_env(:circuits_i2c, :include_i2c_dev)

    if include_i2c_dev != nil do
      # If the user set :include_i2c_dev, then use it
      include_i2c_dev
    else
      # Otherwise, infer whether to build it based on the default_backend
      # setting. If default_backend references it, then build it. If it
      # references something else, then don't build. Default is to build.
      default_backend = Application.get_env(:circuits_i2c, :default_backend)

      default_backend == nil or default_backend == Circuits.I2C.I2CDev or
        (is_tuple(default_backend) and elem(default_backend, 0) == Circuits.I2C.I2CDev)
    end
  end

  defp default_backend(), do: default_backend(Mix.env(), Mix.target(), build_i2c_dev?())
  defp default_backend(:test, _target, true), do: {Circuits.I2C.I2CDev, test: true}

  defp default_backend(_env, :host, true) do
    case :os.type() do
      {:unix, :linux} -> Circuits.I2C.I2CDev
      _ -> {Circuits.I2C.I2CDev, test: true}
    end
  end

  defp default_backend(_env, _target, false), do: Circuits.I2C.NilBackend

  # MIX_TARGET set to something besides host
  defp default_backend(env, _not_host, true) do
    # If CROSSCOMPILE is set, then the Makefile will use the crosscompiler and
    # assume a Linux/Nerves build If not, then the NIF will be build for the
    # host, so use the default host backend
    case System.fetch_env("CROSSCOMPILE") do
      {:ok, _} -> Circuits.I2C.I2CDev
      :error -> default_backend(env, :host, true)
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

  defp i2c_dev_compile_mode(_other) do
    "normal"
  end

  defp format_c([]) do
    case System.find_executable("astyle") do
      nil ->
        Mix.Shell.IO.info("Install astyle to format C code.")

      astyle ->
        System.cmd(astyle, ["-n", "i2c_dev/c_src/*.c"], into: IO.stream(:stdio, :line))
    end
  end

  defp format_c(_args), do: true
end
