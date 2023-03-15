defmodule Circuits.I2C.I2CDev do
  @moduledoc """
  Circuits.I2C backend for the Linux i2c-dev interface

  This backend works on Nerves, embedded Linux, and desktop Linux.
  """

  alias Circuits.I2C.Backend
  alias Circuits.I2C.Nif

  defstruct [:ref, :retries]

  @doc """
  Return the I2C bus names on this system
  """
  case System.get_env("CIRCUITS_BACKEND") do
    "i2c_dev_test" ->
      @spec bus_names() :: [<<_::80>>, ...]
      def bus_names(), do: ["i2c-test-0", "i2c-test-1", "i2c-flaky"]

    "i2c_dev" ->
      @spec bus_names() :: [binary()]
      def bus_names() do
        Path.wildcard("/dev/i2c-*")
        |> Enum.map(fn p -> String.replace_prefix(p, "/dev/", "") end)
      end
  end

  @doc """
  Open an I2C bus

  Bus names are typically of the form `"i2c-n"` and available buses may be
  found by calling `Circuits.I2C.I2CDev.bus_names/0`.

  Options:

  * `:retries` - Specify a nonnegative integer for how many times to retry
    a failed I2C operation.
  """
  @spec open(String.t(), keyword()) :: {:ok, Backend.t()} | {:error, term()}
  def open(bus_name, options \\ []) do
    retries = Keyword.get(options, :retries, 0)

    with {:ok, ref} <- Nif.open(bus_name) do
      {:ok, %__MODULE__{ref: ref, retries: retries}}
    end
  end

  @doc """
  Return information about this backend
  """
  @spec info() :: map()
  defdelegate info(), to: Nif

  defimpl Backend do
    @impl Backend
    def read(%Circuits.I2C.I2CDev{ref: ref, retries: retries}, address, count, options) do
      retries = Keyword.get(options, :retries, retries)

      Nif.read(ref, address, count, retries)
    end

    @impl Backend
    def write(%Circuits.I2C.I2CDev{ref: ref, retries: retries}, address, data, options) do
      retries = Keyword.get(options, :retries, retries)

      Nif.write(ref, address, data, retries)
    end

    @impl Backend
    def write_read(
          %Circuits.I2C.I2CDev{ref: ref, retries: retries},
          address,
          write_data,
          read_count,
          options
        ) do
      retries = Keyword.get(options, :retries, retries)

      Nif.write_read(ref, address, write_data, read_count, retries)
    end

    @impl Backend
    def close(%Circuits.I2C.I2CDev{ref: ref}) do
      Nif.close(ref)
    end
  end
end
