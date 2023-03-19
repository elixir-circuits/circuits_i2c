defmodule VirtualBus do
  @moduledoc """
  Circuits.I2C bus that has a virtual GPIO Expander on it
  """

  alias Circuits.I2C.Bus

  defstruct [:pid]
  @type t() :: %__MODULE__{pid: pid()}

  @spec render(t()) :: String.t()
  def render(%__MODULE__{} = bus) do
    for address <- 0..127 do
      if address == 0x20 do
        [
          "#{address}: \n",
          SimpleDeviceServer.render(bus.pid)
        ]
      else
        []
      end
    end
    |> IO.ANSI.format()
    |> IO.iodata_to_binary()
  end

  defimpl Bus do
    @impl Bus
    def read(%VirtualBus{pid: pid}, address, count, _options) do
      if address == 0x20 do
        SimpleDeviceServer.read(pid, count)
      else
        {:error, :nack}
      end
    end

    @impl Bus
    def write(%VirtualBus{pid: pid}, address, data, _options) do
      if address == 0x20 do
        SimpleDeviceServer.write(pid, data)
      else
        {:error, :nack}
      end
    end

    @impl Bus
    def write_read(
          %VirtualBus{pid: pid},
          address,
          write_data,
          read_count,
          _options
        ) do
      if address == 0x20 do
        SimpleDeviceServer.write_read(pid, write_data, read_count)
      else
        {:error, :nack}
      end
    end

    @impl Bus
    def close(%VirtualBus{}), do: :ok
  end
end
