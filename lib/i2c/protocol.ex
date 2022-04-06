defprotocol Circuits.I2C.Protocol do
  @spec open(binary() | charlist() | Circuits.I2C.Protocol.t()) ::
          {:ok, Circuits.I2C.bus()} | {:error, term()}
  def open(bus)

  @spec read(Circuits.I2C.bus(), Circuits.I2C.address(), pos_integer(), [Circuits.I2C.opt()]) ::
          {:ok, binary()} | {:error, term()}
  def read(bus, address, bytes_to_read, opts \\ [])

  @spec read!(Circuits.I2C.bus(), Circuits.I2C.address(), pos_integer(), [Circuits.I2C.opt()]) ::
          binary()
  def read!(bus, address, bytes_to_read, opts \\ [])

  @spec write(Circuits.I2C.bus(), Circuits.I2C.address(), iodata(), [Circuits.I2C.opt()]) ::
          :ok | {:error, term()}
  def write(bus, address, data, opts \\ [])

  @spec write!(Circuits.I2C.bus(), Circuits.I2C.address(), iodata(), [Circuits.I2C.opt()]) :: :ok
  def write!(bus, address, data, opts \\ [])

  @spec write_read(Circuits.I2C.bus(), Circuits.I2C.address(), iodata(), pos_integer(), [
          Circuits.I2C.opt()
        ]) :: {:ok, binary()} | {:error, term()}
  def write_read(bus, address, write_data, bytes_to_read, opts \\ [])

  @spec write_read!(Circuits.I2C.bus(), Circuits.I2C.address(), iodata(), pos_integer(), [
          Circuits.I2C.opt()
        ]) :: binary()
  def write_read!(bus, address, write_data, bytes_to_read, opts \\ [])

  @spec close(Circuits.I2C.bus()) :: :ok
  def close(bus)
end

defimpl Circuits.I2C.Protocol, for: Circuits.I2C.Bus do
  alias Circuits.I2C.Nif

  def open(bus) do
    case Nif.open(bus.name) do
      {:ok, ref} -> {:ok, %{bus | ref: ref}}
      err -> err
    end
  end

  def read(bus, address, bytes_to_read, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)

    retry(fn -> Nif.read(bus.ref, address, bytes_to_read) end, retries)
  end

  def read!(bus, address, bytes_to_read, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)

    retry!(fn -> Nif.read(bus.ref, address, bytes_to_read) end, retries)
  end

  def write(bus, address, data, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)
    data_as_binary = IO.iodata_to_binary(data)

    retry(fn -> Nif.write(bus.ref, address, data_as_binary) end, retries)
  end

  def write!(bus, address, data, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)
    data_as_binary = IO.iodata_to_binary(data)

    retry!(fn -> Nif.write(bus.ref, address, data_as_binary) end, retries)
  end

  def write_read(bus, address, write_data, bytes_to_read, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)
    data_as_binary = IO.iodata_to_binary(write_data)

    retry(fn -> Nif.write_read(bus.ref, address, data_as_binary, bytes_to_read) end, retries)
  end

  def write_read!(bus, address, write_data, bytes_to_read, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)
    data_as_binary = IO.iodata_to_binary(write_data)

    retry!(fn -> Nif.write_read(bus.ref, address, data_as_binary, bytes_to_read) end, retries)
  end

  def close(bus) do
    Nif.close(bus.ref)
  end

  defp retry!(fun, times) do
    case retry(fun, times) do
      {:error, reason} ->
        raise "I2C failure: " <> to_string(reason)

      :ok ->
        :ok

      {:ok, result} ->
        result
    end
  end

  defp retry(fun, 0), do: fun.()

  defp retry(fun, times) when times > 0 do
    case fun.() do
      {:error, _reason} -> retry(fun, times - 1)
      result -> result
    end
  end
end
