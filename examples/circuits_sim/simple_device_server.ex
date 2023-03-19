defmodule SimpleDeviceServer do
  @moduledoc false

  use GenServer

  defstruct [:register, :device]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args)
  end

  @spec read(GenServer.server(), non_neg_integer()) :: {:ok, binary()} | {:error, any()}
  def read(server, count) do
    GenServer.call(server, {:read, count})
  end

  @spec write(GenServer.server(), iodata()) :: :ok | {:error, any()}
  def write(server, data) do
    GenServer.call(server, {:write, data})
  end

  @spec write_read(GenServer.server(), iodata(), non_neg_integer()) ::
          {:ok, binary()} | {:error, any()}
  def write_read(server, data, read_count) do
    GenServer.call(server, {:write_read, data, read_count})
  end

  @spec render(GenServer.server()) :: IO.ANSI.ansidata()
  def render(server) do
    GenServer.call(server, :render)
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
    new_state = state |> do_write(data)
    {:reply, :ok, new_state}
  end

  def handle_call({:write_read, data, read_count}, _from, state) do
    {result, new_state} = state |> do_write(data) |> do_read(read_count)

    {:reply, {:ok, result}, new_state}
  end

  def handle_call(:render, _from, state) do
    {:reply, SimpleDevice.render(state.device), state}
  end

  defp do_read(state, count, acc \\ [])

  defp do_read(state, 0, acc) do
    result = acc |> Enum.reverse() |> :binary.list_to_bin()
    {result, state}
  end

  defp do_read(state, count, acc) do
    reg = state.register

    {v, device} = SimpleDevice.read_register(state.device, reg)
    new_state = %{state | device: device, register: inc8(reg)}

    do_read(new_state, count - 1, [v | acc])
  end

  defp do_write(state, <<>>), do: state
  defp do_write(state, <<reg>>), do: %{state | register: reg}

  defp do_write(state, <<reg, value>>) do
    device = SimpleDevice.write_register(state.device, reg, value)
    %{state | device: device, register: inc8(reg)}
  end

  defp do_write(state, <<reg, value, values::binary>>) do
    device = SimpleDevice.write_register(state.device, reg, value)
    register = inc8(reg)

    new_state = %{state | device: device, register: register}

    do_write(new_state, <<register, values::binary>>)
  end

  defp inc8(255), do: 0
  defp inc8(x), do: x + 1
end
