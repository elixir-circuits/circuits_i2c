defmodule CircuitsSim.Bus do
  @moduledoc """
  Circuits.I2C bus that has a virtual GPIO Expander on it
  """

  alias Circuits.I2C.Bus
  alias CircuitsSim.SimpleI2CServer

  defstruct [:pid]
  @type t() :: %__MODULE__{pid: pid()}

  @spec render(t()) :: String.t()
  def render(%__MODULE__{} = bus) do
    for address <- 0..127 do
      if address == 0x20 do
        [
          "#{address}: \n",
          SimpleI2CServer.render(bus.pid)
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
    def read(%CircuitsSim.Bus{pid: pid}, address, count, _options) do
      if address == 0x20 do
        SimpleI2CServer.read(pid, count)
      else
        {:error, :nack}
      end
    end

    @impl Bus
    def write(%CircuitsSim.Bus{pid: pid}, address, data, _options) do
      if address == 0x20 do
        SimpleI2CServer.write(pid, data)
      else
        {:error, :nack}
      end
    end

    @impl Bus
    def write_read(
          %CircuitsSim.Bus{pid: pid},
          address,
          write_data,
          read_count,
          _options
        ) do
      if address == 0x20 do
        SimpleI2CServer.write_read(pid, write_data, read_count)
      else
        {:error, :nack}
      end
    end

    @impl Bus
    def close(%CircuitsSim.Bus{}), do: :ok
  end
end
