# SPDX-FileCopyrightText: 2023 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.I2C.I2CDev do
  @moduledoc """
  Circuits.I2C backend for the Linux i2c-dev interface

  This backend works on Nerves, embedded Linux, and desktop Linux.
  """
  @behaviour Circuits.I2C.Backend

  alias Circuits.I2C.Backend
  alias Circuits.I2C.Bus
  alias Circuits.I2C.Nif

  defstruct [:ref, :retries, :flags]

  @doc """
  Return the I2C bus names on this system

  No supported options
  """
  case System.get_env("CIRCUITS_I2C_I2CDEV") do
    "test" ->
      @impl Backend
      def bus_names(_options), do: ["i2c-test-0", "i2c-test-1", "i2c-flaky"]

    "normal" ->
      @impl Backend
      def bus_names(_options) do
        Path.wildcard("/dev/i2c-*")
        |> Enum.map(fn p -> String.replace_prefix(p, "/dev/", "") end)
      end

    _ ->
      @impl Backend
      def bus_names(_options) do
        []
      end
  end

  @doc """
  Open an I2C bus

  Bus names are typically of the form `"i2c-n"` and available buses may be
  found by calling `Circuits.I2C.bus_names/0`.

  Options:

  * `:retries` - the number of times to retry a transaction. I.e. 2 retries means
    the transaction is attempted at most 3 times. Defaults to 0 retries.
  * `:timeout` - the time in milliseconds to wait for a transaction to complete.
    Any value <0 means to use the device driver default which is probably 1000 ms.
  """
  @impl Backend
  def open(bus_name, options) do
    retries = Keyword.get(options, :retries, 0)

    if not (is_integer(retries) and retries >= 0) do
      raise ArgumentError, "retries must be a non-negative integer"
    end

    timeout = Keyword.get(options, :timeout, -1)

    if not is_integer(timeout) do
      raise ArgumentError, "timeout must be an integer"
    end

    with {:ok, ref, flags} <- Nif.open(bus_name, timeout) do
      {:ok, %__MODULE__{ref: ref, flags: flags, retries: retries}}
    end
  end

  @doc """
  Return information about this backend
  """
  @impl Backend
  def info() do
    Nif.info()
    |> Map.put(:backend, __MODULE__)
  end

  defimpl Bus do
    @impl Bus
    def flags(%Circuits.I2C.I2CDev{flags: flags}) do
      flags
    end

    @impl Bus
    def read(%Circuits.I2C.I2CDev{ref: ref, retries: retries}, address, count, options) do
      retries = Keyword.get(options, :retries, retries)

      Nif.read(ref, address, count, retries)
    end

    @impl Bus
    def write(%Circuits.I2C.I2CDev{ref: ref, retries: retries}, address, data, options) do
      retries = Keyword.get(options, :retries, retries)

      Nif.write(ref, address, data, retries)
    end

    @impl Bus
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

    @impl Bus
    def close(%Circuits.I2C.I2CDev{ref: ref}) do
      Nif.close(ref)
    end
  end
end
