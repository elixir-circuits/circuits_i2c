defmodule VirtualBackend do
  @moduledoc """
  Circuits.I2C backend that has a virtual GPIO Expander on it
  """
  @behaviour Circuits.I2C.Backend

  alias Circuits.I2C.Backend

  @doc """
  Return the I2C bus names on this system

  No supported options
  """
  @impl Backend
  def bus_names(_options \\ []), do: ["i2c-0"]

  @doc """
  Open an I2C bus
  """
  @impl Backend
  def open(bus_name, options \\ [])

  def open("i2c-0", _options) do
    {:ok, pid} = SimpleDeviceServer.start_link(device: GPIOExpander.new())

    {:ok, %VirtualBus{pid: pid}}
  end

  def open(other, _options) do
    {:error, "Unknown controller #{other}"}
  end

  @doc """
  Return information about this backend
  """
  @impl Backend
  def info() do
    %{backend: __MODULE__}
  end
end