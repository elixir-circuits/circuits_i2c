defmodule Circuits.I2C.MPSSE do
  @moduledoc """
  Circuits.I2C backend for USB devices that use the FTDI MPSSE protocol

  Devices that speak MPSSE:

  * [Adafruit FT232H Breakout](https://www.adafruit.com/product/2264)

  Example use:

  ```elixir
  iex> {:ok, i2c} = Circuits.I2C.MPSSE.open("anything", [])
  {:ok, %Circuits.I2C.MPSSE{mpsse: #Reference<0.3204948360.1742602257.8675>}}
  iex> Circuits.I2C.detect_devices(i2c)
  'P'
  # This is also [0x50]. 0x50 is the address of an I2C EEPROM. Read the beginning.
  iex> Circuits.I2C.write_read(i2c, 0x50, <<0>>, 16)
  {:ok, <<34, 51, 68, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255>>}
  iex> Circuits.I2C.close(i2c)
  :ok
  ```
  """
  @behaviour Circuits.I2C.Backend

  alias Circuits.I2C.Backend
  alias Circuits.I2C.Bus

  defstruct [:mpsse]

  @doc """
  Return the I2C bus names on this system

  No supported options
  """
  @impl Backend
  def bus_names(_options) do
    # TODO
    ["i2c-1"]
  end

  @doc """
  Open an I2C bus
  """
  @impl Backend
  def open(_bus_name, _options) do
    with {:ok, mpsse} <- MPSSE.find_and_open(:i2c) do
      {:ok, %__MODULE__{mpsse: mpsse}}
    end
  end

  @doc """
  Return information about this backend
  """
  @impl Backend
  def info() do
    %{backend: __MODULE__}
  end

  defimpl Bus do
    @impl Bus
    def flags(%Circuits.I2C.MPSSE{}) do
      [:supports_empty_write]
    end

    @impl Bus
    def read(%Circuits.I2C.MPSSE{mpsse: mpsse}, address, count, _options) do
      address_rd = Bitwise.bsl(address, 1) + 1

      with :ok <- MPSSE.start(mpsse),
           :ok <- MPSSE.write(mpsse, <<address_rd>>),
           :ack <- MPSSE.get_ack(mpsse),
           {:ok, result} <- MPSSE.read(mpsse, count) do
        MPSSE.stop(mpsse)
        {:ok, result}
      end
    end

    @impl Bus
    def write(%Circuits.I2C.MPSSE{mpsse: mpsse}, address, data, _options) do
      address_wr = Bitwise.bsl(address, 1)

      with :ok <- MPSSE.start(mpsse),
           :ok <- MPSSE.write(mpsse, [address_wr, data]),
           :ack <- MPSSE.get_ack(mpsse) do
        MPSSE.stop(mpsse)
        :ok
      end
    end

    @impl Bus
    def write_read(
          %Circuits.I2C.MPSSE{mpsse: mpsse},
          address,
          write_data,
          read_count,
          _options
        ) do
      address_wr = Bitwise.bsl(address, 1)
      address_rd = address_wr + 1

      with :ok <- MPSSE.start(mpsse),
           :ok <- MPSSE.write(mpsse, [address_wr, write_data]),
           :ack <- MPSSE.get_ack(mpsse),
           :ok <- MPSSE.start(mpsse),
           :ok <- MPSSE.write(mpsse, <<address_rd>>),
           :ack <- MPSSE.get_ack(mpsse),
           {:ok, result} <- MPSSE.read(mpsse, read_count) do
        MPSSE.stop(mpsse)
        {:ok, result}
      end
    end

    @impl Bus
    def close(%Circuits.I2C.MPSSE{mpsse: mpsse}) do
      MPSSE.close(mpsse)
      :ok
    end
  end
end
