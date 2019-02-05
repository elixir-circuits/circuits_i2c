defmodule Circuits.I2C.MixProject do
  use Mix.Project

  def project do
    [
      app: :circuits_i2c,
      version: "0.4.0-dev",
      elixir: "~> 1.6",
      description: description(),
      package: package(),
      source_url: "https://github.com/elixir-circuits/circuits_i2c",
      compilers: [:elixir_make | Mix.compilers()],
      make_targets: ["all"],
      make_clean: ["clean"],
      make_env: &make_env/0,
      docs: [extras: ["README.md", "PORTING.md"], main: "readme"],
      aliases: [docs: ["docs", &copy_images/1], format: ["format", &format_c/1]],
      start_permanent: Mix.env() == :prod,
      build_embedded: true,
      deps: deps()
    ]
  end

  defp make_env() do
    base =
      Mix.Project.compile_path()
      |> Path.join("..")
      |> Path.expand()

    %{
      "MIX_ENV" => to_string(Mix.env()),
      "PREFIX" => Path.join(base, "priv"),
      "BUILD" => Path.join(base, "obj")
    }
    |> Map.merge(ei_env())
  end

  defp ei_env() do
    case System.get_env("ERL_EI_INCLUDE_DIR") do
      nil ->
        %{
          "ERL_EI_INCLUDE_DIR" => "#{:code.root_dir()}/usr/include",
          "ERL_EI_LIBDIR" => "#{:code.root_dir()}/usr/lib"
        }

      _ ->
        %{}
    end
  end

  def application, do: []

  defp description do
    "Use I2C in Elixir"
  end

  defp package do
    %{
      files: [
        "lib",
        "src/*.[ch]",
        "src/linux/i2c-dev.h",
        "mix.exs",
        "README.md",
        "PORTING.md",
        "LICENSE",
        "Makefile"
      ],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/elixir-circuits/circuits_i2c"}
    }
  end

  defp deps do
    [
      {:elixir_make, "~> 0.4", runtime: false},
      {:ex_doc, "~> 0.11", only: :dev, runtime: false},
      {:dialyxir, "1.0.0-rc.4", only: :dev, runtime: false}
    ]
  end

  # Copy the images referenced by docs, since ex_doc doesn't do this.
  defp copy_images(_) do
    File.cp_r("assets", "doc/assets")
  end

  defp format_c([]) do
    astyle =
      System.find_executable("astyle") ||
        Mix.raise("""
        Could not format C code since astyle is not available.
        """)

    System.cmd(astyle, ["-n", "src/*.c"], into: IO.stream(:stdio, :line))
  end

  defp format_c(_args), do: true
end
