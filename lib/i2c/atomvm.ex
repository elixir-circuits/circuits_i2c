# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.I2C.AtomVM do
  @moduledoc """
  Circuits.I2C backend for the AtomVM 0.6 `:i2c` driver

  Bus names and driver parameters are configured explicitly, so this backend
  does not assume a particular board or pin assignment. For example:

      options = [
        buses: [
          {"i2c0", [peripheral: "i2c0", scl: 22, sda: 21, clock_speed_hz: 100_000]}
        ],
        retries: 1
      ]

      {:ok, bus} = Circuits.I2C.AtomVM.open("i2c0", options)
      {:ok, data} = Circuits.I2C.write_read(bus, 0x48, <<0>>, 2)
      :ok = Circuits.I2C.close(bus)

  Open the backend directly on AtomVM 0.6, which does not implement OTP
  application environment configuration. Transfer functions in `Circuits.I2C`
  dispatch using the returned bus struct and do not need that configuration.

  Driver parameters are passed unchanged to `:i2c.open/1`. Use parameters and
  peripherals supported by the target AtomVM device; the pin assignments above
  are only an ESP32 example. The AtomVM `:i2c` module must be included in the
  firmware.

  AtomVM 0.6 supports combined write/read transactions with a single-byte
  register address. Longer write payloads return `{:error, :not_supported}`;
  empty payloads perform a read. This backend does not split combined transfers
  into separate write and read transactions.

  Retries apply to the entire transfer and can be overridden per transfer.
  Configurable transaction timeouts and empty-write device probing are not
  supported. Invalid driver configuration may raise when opening a bus.

  Call `Circuits.I2C.close/1` explicitly to release the driver. Unlike the Linux
  NIF backend, this backend does not have a garbage-collected resource
  destructor. A driver error while closing raises.
  """
  @behaviour Circuits.I2C.Backend
  # AtomVM supplies :i2c at runtime; it is not part of the host OTP installation.
  @compile {:no_warn_undefined, :i2c}
  @dialyzer {:no_unknown, open: 2}

  alias Circuits.I2C.Backend
  alias Circuits.I2C.Bus

  defstruct [:ref, :retries]

  @doc """
  Return the bus names configured in the `:buses` option

  `:buses` is a list of `{name, driver_parameters}` tuples, where `name` is a
  string and `driver_parameters` is an AtomVM I2C driver keyword list.
  """
  @impl Backend
  @spec bus_names(keyword()) :: [String.t()]
  def bus_names(options) do
    :lists.map(
      fn {name, _parameters} when is_binary(name) -> name end,
      :proplists.get_value(:buses, options, [])
    )
  end

  @doc """
  Open a configured AtomVM I2C bus

  Options:

  * `:buses` - configured bus names and driver parameters. Defaults to `[]`.
  * `:retries` - additional attempts after a failed transfer. Defaults to `0`.
  """
  @impl Backend
  @spec open(String.t(), keyword()) :: {:ok, Bus.t()} | {:error, term()}
  def open(bus_name, options) when is_binary(bus_name) do
    retries = :proplists.get_value(:retries, options, 0)

    if not (is_integer(retries) and retries >= 0) do
      raise ArgumentError, "retries must be a non-negative integer"
    end

    buses = :proplists.get_value(:buses, options, [])

    case :lists.keyfind(bus_name, 1, buses) do
      {^bus_name, parameters} ->
        {:ok, %__MODULE__{ref: :i2c.open(parameters), retries: retries}}

      false ->
        {:error, :bus_not_found}
    end
  end

  @doc """
  Return information about this backend
  """
  @impl Backend
  @spec info() :: %{backend: __MODULE__}
  def info(), do: %{backend: __MODULE__}

  defimpl Bus do
    @compile {:no_warn_undefined, :i2c}
    @dialyzer {:no_unknown, read: 4, write: 4, write_read: 5, close: 1}

    @impl Bus
    def flags(_bus), do: []

    @impl Bus
    def read(bus, address, count, options) do
      with_retries(bus, options, fn -> :i2c.read_bytes(bus.ref, address, count) end)
    end

    @impl Bus
    def write(bus, address, data, options) do
      binary = :erlang.iolist_to_binary(data)
      with_retries(bus, options, fn -> :i2c.write_bytes(bus.ref, address, binary) end)
    end

    @impl Bus
    def write_read(bus, address, write_data, read_count, options) do
      case :erlang.iolist_to_binary(write_data) do
        <<>> ->
          read(bus, address, read_count, options)

        <<register>> ->
          with_retries(bus, options, fn ->
            :i2c.read_bytes(bus.ref, address, register, read_count)
          end)

        _other ->
          {:error, :not_supported}
      end
    end

    @impl Bus
    def close(bus) do
      case :i2c.close(bus.ref) do
        :ok -> :ok
        {:error, reason} -> raise "I2C close failed: #{inspect(reason)}"
      end
    end

    defp with_retries(bus, options, transfer) do
      retries = :proplists.get_value(:retries, options, bus.retries)

      if not (is_integer(retries) and retries >= 0) do
        raise ArgumentError, "retries must be a non-negative integer"
      end

      retry(transfer, retries)
    end

    defp retry(transfer, retries) do
      case transfer.() do
        {:error, _reason} when retries > 0 -> retry(transfer, retries - 1)
        result -> result
      end
    end
  end
end
