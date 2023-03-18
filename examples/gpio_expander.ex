defmodule GPIOExpander do
  @moduledoc """
  Circuits.I2C backend that has a virtual GPIO Expander on it
  """

  alias Circuits.I2C.Backend

  defstruct [:pid]

  @doc """
  Return the I2C bus names on this system

  No supported options
  """

  @spec bus_names(keyword()) :: [<<_::80>>, ...]
  def bus_names(_options \\ []), do: ["i2c-0"]

  @doc """
  Open an I2C bus

  Bus names are typically of the form `"i2c-n"` and available buses may be
  found by calling `Circuits.I2C.I2CDev.bus_names/0`.

  No supported options.
  """
  @spec open(String.t(), keyword()) :: {:ok, Backend.t()} | {:error, term()}
  def open(bus_name, options \\ [])

  def open("i2c-0", _options) do
    {:ok, pid} = GPIOExpander.Server.start_link([])

    {:ok, %__MODULE__{pid: pid}}
  end

  def open(other, _options) do
    {:error, "Unknown controller #{other}"}
  end

  def render(%__MODULE__{} = bus) do
    for address <- 0..127 do
      if(address == 0x20) do
        [
          "#{address}: \n",
          GPIOExpander.Server.render(bus.pid)
        ]
      else
        []
      end
    end
    |> IO.iodata_to_binary()
  end

  @doc """
  Return information about this backend
  """
  @spec info() :: map()
  def info() do
    %{backend: __MODULE__}
  end

  defmodule Server do
    use GenServer

    defstruct [:register, :gpios]

    def start_link(init_args) do
      GenServer.start_link(__MODULE__, init_args)
    end

    def read(server, count) do
      GenServer.call(server, {:read, count})
    end

    def write(server, data) do
      GenServer.call(server, {:write, data})
    end

    def write_read(server, data, read_count) do
      GenServer.call(server, {:write_read, data, read_count})
    end

    def render(server) do
      GenServer.call(server, :render)
    end

    def init(_init_args) do
      {:ok, %__MODULE__{register: 0, gpios: 0}}
    end

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
      {pin, io, values} =
        for i <- 0..7 do
          mask = Bitwise.bsl(1, i)

          v = if Bitwise.band(state.gpios, mask) == 0, do: "0", else: "1"
          {to_string(i), "O", v}
        end
        |> unzip3()

      {:reply, ["     Pin: ", pin, "\n     I/O: ", io, "\n   Value: ", values, "\n"], state}
    end

    defp unzip3(list, acc \\ {[], [], []})

    defp unzip3([], {a, b, c}) do
      {Enum.reverse(a), Enum.reverse(b), Enum.reverse(c)}
    end

    defp unzip3([{x, y, z} | rest], {a, b, c}) do
      unzip3(rest, {[x | a], [y | b], [z | c]})
    end

    defp do_read(state, count, acc \\ [])

    defp do_read(state, 0, acc) do
      result = acc |> Enum.reverse() |> :binary.list_to_bin()
      {result, state}
    end

    defp do_read(state, count, acc) do
      {v, new_state} = read_reg(state, state.register)
      do_read(new_state, count - 1, [v | acc])
    end

    defp do_write(state, <<>>), do: state
    defp do_write(state, <<reg>>), do: %{state | register: reg}
    defp do_write(state, <<reg, value>>), do: write_reg(state, reg, value)

    defp do_write(state, <<reg, value, values::binary>>) do
      state
      |> write_reg(reg, value)
      |> do_write(<<inc8(reg), values::binary>>)
    end

    defp write_reg(state, 1, value), do: %{state | gpios: value, register: inc8(1)}
    defp write_reg(state, other, _value), do: %{state | register: inc8(other)}

    defp read_reg(state, 1), do: {state.gpios, %{state | register: inc8(1)}}
    defp read_reg(state, other), do: {0, %{state | register: inc8(other)}}

    defp inc8(255), do: 0
    defp inc8(x), do: x + 1
  end

  defimpl Backend do
    @impl Backend
    def read(%GPIOExpander{pid: pid}, address, count, _options) do
      if address == 0x20 do
        Server.read(pid, count)
      else
        {:error, :nack}
      end
    end

    @impl Backend
    def write(%GPIOExpander{pid: pid}, address, data, _options) do
      if address == 0x20 do
        Server.write(pid, data)
      else
        {:error, :nack}
      end
    end

    @impl Backend
    def write_read(
          %GPIOExpander{pid: pid},
          address,
          write_data,
          read_count,
          _options
        ) do
      if address == 0x20 do
        Server.write_read(pid, write_data, read_count)
      else
        {:error, :nack}
      end
    end

    @impl Backend
    def close(%GPIOExpander{}), do: :ok
  end
end
