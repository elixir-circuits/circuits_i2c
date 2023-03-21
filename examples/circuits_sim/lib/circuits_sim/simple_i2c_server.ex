defmodule CircuitsSim.SimpleI2CServer do
  @moduledoc false

  use GenServer

  alias Circuits.I2C
  alias CircuitsSim.DeviceRegistry
  alias CircuitsSim.SimpleI2C

  defstruct [:register, :device]

  @doc """
  Helper for creating child_specs for simple I2C implementations
  """
  @spec child_spec_helper(SimpleI2C.t(), keyword()) :: map()
  def child_spec_helper(device, args) do
    bus_name = Keyword.fetch!(args, :bus_name)
    address = Keyword.fetch!(args, :address)

    combined_args =
      Keyword.merge(
        [device: device, name: DeviceRegistry.via_name(bus_name, address)],
        args
      )

    %{
      id: __MODULE__,
      start: {CircuitsSim.SimpleI2CServer, :start_link, [combined_args]}
    }
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(init_args) do
    bus_name = Keyword.fetch!(init_args, :bus_name)
    address = Keyword.fetch!(init_args, :address)

    GenServer.start_link(__MODULE__, init_args, name: DeviceRegistry.via_name(bus_name, address))
  end

  @spec read(String.t(), I2C.address(), non_neg_integer()) ::
          {:ok, binary()} | {:error, any()}
  def read(bus_name, address, count) do
    GenServer.call(DeviceRegistry.via_name(bus_name, address), {:read, count})
  catch
    :exit, {:noproc, _} -> {:error, :nak}
  end

  @spec write(String.t(), I2C.address(), iodata()) :: :ok | {:error, any()}
  def write(bus_name, address, data) do
    GenServer.call(DeviceRegistry.via_name(bus_name, address), {:write, data})
  catch
    :exit, {:noproc, _} -> {:error, :nak}
  end

  @spec write_read(String.t(), I2C.address(), iodata(), non_neg_integer()) ::
          {:ok, binary()} | {:error, any()}
  def write_read(bus_name, address, data, read_count) do
    GenServer.call(DeviceRegistry.via_name(bus_name, address), {:write_read, data, read_count})
  catch
    :exit, {:noproc, _} -> {:error, :nak}
  end

  @spec render(String.t(), I2C.address()) :: IO.ANSI.ansidata()
  def render(bus_name, address) do
    GenServer.call(DeviceRegistry.via_name(bus_name, address), :render)
  catch
    :exit, {:noproc, _} -> []
  end

  @impl GenServer
  def init(init_args) do
    device = Keyword.fetch!(init_args, :device)
    {:ok, %__MODULE__{register: 0, device: device}}
  end

  @impl GenServer
  def handle_call({:read, count}, _from, state) do
    {result, new_state} = state |> do_read(count)
    {:reply, {:ok, result}, new_state}
  end

  def handle_call({:write, data}, _from, state) do
    new_state = state |> do_write(IO.iodata_to_binary(data))
    {:reply, :ok, new_state}
  end

  def handle_call({:write_read, data, read_count}, _from, state) do
    {result, new_state} = state |> do_write(IO.iodata_to_binary(data)) |> do_read(read_count)

    {:reply, {:ok, result}, new_state}
  end

  def handle_call(:render, _from, state) do
    {:reply, SimpleI2C.render(state.device), state}
  end

  defp do_read(state, count, acc \\ [])

  defp do_read(state, 0, acc) do
    result = acc |> Enum.reverse() |> :binary.list_to_bin()
    {result, state}
  end

  defp do_read(state, count, acc) do
    reg = state.register

    {v, device} = SimpleI2C.read_register(state.device, reg)
    new_state = %{state | device: device, register: inc8(reg)}

    do_read(new_state, count - 1, [v | acc])
  end

  defp do_write(state, <<>>), do: state
  defp do_write(state, <<reg>>), do: %{state | register: reg}

  defp do_write(state, <<reg, value>>) do
    device = SimpleI2C.write_register(state.device, reg, value)
    %{state | device: device, register: inc8(reg)}
  end

  defp do_write(state, <<reg, value, values::binary>>) do
    device = SimpleI2C.write_register(state.device, reg, value)
    register = inc8(reg)

    new_state = %{state | device: device, register: register}

    do_write(new_state, <<register, values::binary>>)
  end

  defp inc8(255), do: 0
  defp inc8(x), do: x + 1
end
