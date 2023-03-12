defmodule Circuits.I2C do
  @moduledoc """
  `Circuits.I2C` lets you communicate with hardware devices using the I2C
  protocol.
  """
  alias Circuits.I2C.Nif

  # Public API

  @typedoc """
  I2C device address

  This is a "7-bit" address for the device. Some devices specify an "8-bit"
  address in their documentation. You can tell if you have an "8-bit" address
  if it's greater than 127 (0x7f) or if the documentation talks about different
  read and write addresses. If you have an 8-bit address, divide it by 2.
  """
  @type address() :: 0..127

  @typedoc """
  I2C bus

  Call `open/1` to obtain an I2C bus reference and then pass it to the read
  and write functions for interacting with devices.
  """
  @type bus() :: reference()

  @typedoc """
  Function to report back whether a device is present

  See `discover/2` for how a custom function can improve device detection when
  the type of device being looked for is known.
  """
  @type present?() :: (bus(), address() -> boolean())

  @type opt() :: {:retries, non_neg_integer()}

  @doc """
  Open an I2C bus

  I2C bus names depend on the platform. Names are of the form "i2c-n" where the
  "n" is the bus number.  The correct bus number can be found in the
  documentation for the device or on a schematic. Another option is to call
  `Circuits.I2C.bus_names/0` to list them for you.

  I2c buses may be opened more than once. There is no need to share an I2C bus
  reference between modules.

  On success, this returns a reference to the I2C bus.  Use the reference in
  subsequent calls to read and write I2C devices
  """
  @spec open(binary() | charlist()) :: {:ok, bus()} | {:error, term()}
  def open(bus_name) do
    Nif.open(to_string(bus_name))
  end

  @doc """
  Initiate a read transaction to the I2C device at the specified `address`

  Options:

  * `:retries` - number of retries before failing (defaults to no retries)
  """
  @spec read(bus(), address(), pos_integer(), [opt()]) :: {:ok, binary()} | {:error, term()}
  def read(i2c_bus, address, bytes_to_read, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)

    retry(fn -> Nif.read(i2c_bus, address, bytes_to_read) end, retries)
  end

  @doc """
  Initiate a read transaction and raise on error
  """
  @spec read!(bus(), address(), pos_integer(), [opt()]) :: binary()
  def read!(i2c_bus, address, bytes_to_read, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)

    retry!(fn -> Nif.read(i2c_bus, address, bytes_to_read) end, retries)
  end

  @doc """
  Write `data` to the I2C device at `address`.

  Options:

  * `:retries` - number of retries before failing (defaults to no retries)
  """
  @spec write(bus(), address(), iodata(), [opt()]) :: :ok | {:error, term()}
  def write(i2c_bus, address, data, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)
    data_as_binary = IO.iodata_to_binary(data)

    retry(fn -> Nif.write(i2c_bus, address, data_as_binary) end, retries)
  end

  @doc """
  Write `data` to the I2C device at `address` and raise on error

  Options:

  * `:retries` - number of retries before failing (defaults to no retries)
  """
  @spec write!(bus(), address(), iodata(), [opt()]) :: :ok
  def write!(i2c_bus, address, data, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)
    data_as_binary = IO.iodata_to_binary(data)

    retry!(fn -> Nif.write(i2c_bus, address, data_as_binary) end, retries)
  end

  @doc """
  Write `data` to an I2C device and then immediately issue a read.

  This function is useful for devices that want you to write the "register"
  location to them first and then issue a read to get its contents. Many
  devices operate this way and this function will issue the commands
  back-to-back on the I2C bus. Some I2C devices actually require that the read
  immediately follows the write. If the target supports this, the I2C
  transaction will be issued that way. On the Raspberry Pi, this can be enabled
  globally with `File.write!("/sys/module/i2c_bcm2708/parameters/combined", "1")`

  Options:

  * `:retries` - number of retries before failing (defaults to no retries)
  """
  @spec write_read(bus(), address(), iodata(), pos_integer(), [opt()]) ::
          {:ok, binary()} | {:error, term()}
  def write_read(i2c_bus, address, write_data, bytes_to_read, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)
    data_as_binary = IO.iodata_to_binary(write_data)

    retry(fn -> Nif.write_read(i2c_bus, address, data_as_binary, bytes_to_read) end, retries)
  end

  @doc """
  Write `data` to an I2C device and then immediately issue a read. Raise on errors.

  Options:

  * `:retries` - number of retries before failing (defaults to no retries)
  """
  @spec write_read!(bus(), address(), iodata(), pos_integer(), [opt()]) :: binary()
  def write_read!(i2c_bus, address, write_data, bytes_to_read, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)
    data_as_binary = IO.iodata_to_binary(write_data)

    retry!(fn -> Nif.write_read(i2c_bus, address, data_as_binary, bytes_to_read) end, retries)
  end

  @doc """
  close the I2C bus
  """
  @spec close(bus()) :: :ok
  def close(i2c_bus) do
    Nif.close(i2c_bus)
  end

  @doc """
  Return a list of available I2C bus names.  If nothing is returned, it's
  possible that the kernel driver for that I2C bus is not enabled or the
  kernel's device tree is not configured. On Raspbian, run `raspi-config` and
  look in the advanced options.

  ```elixir
  iex> Circuits.I2C.bus_names()
  ["i2c-1"]
  ```
  """
  if Mix.env() != :test do
    @spec bus_names() :: [binary()]
    def bus_names() do
      Path.wildcard("/dev/i2c-*")
      |> Enum.map(fn p -> String.replace_prefix(p, "/dev/", "") end)
    end
  else
    # Return a hardcoded set of I2C bus names for test purposes
    def bus_names() do
      ["i2c-test-0", "i2c-test-1"]
    end
  end

  @doc """
  Scan the I2C bus for devices by performing a read at each device address and
  returning a list of device addresses that respond.

  WARNING: This is intended to be a debugging aid. Reading bytes from devices
  can advance internal state machines and might cause them to get out of sync
  with other code.

  ```elixir
  iex> Circuits.I2C.detect_devices("i2c-1")
  [4]
  ```

  The return value is a list of device addresses that were detected on the
  specified I2C bus. If you get back `'Hh'` or other letters, then IEx
  converted the list to an Erlang string. Run `i v()` to get information about
  the return value and look at the raw string representation for addresses.

  If you already have a reference to an open device, then you may pass its
  `reference` to `detect_devices/1` instead.
  """
  @spec detect_devices(bus() | binary()) :: [address()] | {:error, term()}
  def detect_devices(i2c_bus) when is_reference(i2c_bus) do
    Enum.filter(0x03..0x77, &device_present?(i2c_bus, &1))
  end

  def detect_devices(bus_name) when is_binary(bus_name) do
    case open(bus_name) do
      {:ok, i2c_bus} ->
        devices = detect_devices(i2c_bus)
        close(i2c_bus)
        devices

      error ->
        error
    end
  end

  @doc """
  Convenience method to scan all I2C buses for devices

  This is only intended to be called from the IEx prompt. Programs should
  use `detect_devices/1`.
  """
  @spec detect_devices() :: :"do not show this result in output"
  def detect_devices() do
    buses = bus_names()

    total_devices = Enum.reduce(buses, 0, &detect_and_print/2)

    IO.puts("#{total_devices} devices detected on #{length(buses)} I2C buses")

    :"do not show this result in output"
  end

  @doc """
  Scan all I2C buses for one or more devices

  This function takes a list of possible addresses and an optional detection
  function. It only scans addresses in the possible addresses list to avoid
  disturbing unrelated I2C devices.

  If a detection function is not passed in, a default one that performs a
  simple read and checks whether it succeeds is used. If the desired device has
  an ID register or other means of identification, the optional function should
  try to query that. If passing a custom function, be sure to return `false`
  rather than raise if there are errors.

  A list of bus name and address tuples is returned. The list may be empty.

  See also `discover_one/2`.
  """
  @spec discover([address()], present?()) :: [{binary(), address()}]
  def discover(possible_addresses, present? \\ &device_present?/2) do
    Enum.flat_map(bus_names(), &discover(&1, possible_addresses, present?))
  end

  @spec discover(binary(), [address()], present?()) :: [{binary(), address()}]
  defp discover(bus_name, possible_addresses, present?) when is_binary(bus_name) do
    case open(bus_name) do
      {:ok, i2c_bus} ->
        result =
          possible_addresses
          |> Enum.filter(fn address -> present?.(i2c_bus, address) end)
          |> Enum.map(&{bus_name, &1})

        close(i2c_bus)
        result

      {:error, reason} ->
        raise "I2C discovery error: Opening #{bus_name} failed with #{reason}"
    end
  end

  @doc """
  Scans all I2C buses for one specific device

  This function and `discover_one!/2` are convenience functions for the use
  case of helping a user find a specific device. They both call `discover/2` with
  a list of possible I2C addresses and an optional function for checking whether
  the device is present.

  This function returns an `:ok` or `:error` tuple depending on whether one and
  only one device was found. See `discover_one!/2` for the raising version.
  """
  @spec discover_one([address()], present?()) ::
          {:ok, {binary(), address()}} | {:error, :not_found | :multiple_possible_matches}
  def discover_one(possible_addresses, present? \\ &device_present?/2) do
    case discover(possible_addresses, present?) do
      [actual_device] -> {:ok, actual_device}
      [] -> {:error, :not_found}
      _ -> {:error, :multiple_possible_matches}
    end
  end

  @doc """
  Same as `discover_one/2` but raises on error
  """
  @spec discover_one!([address()], present?()) :: {binary(), address()}
  def discover_one!(possible_addresses, present? \\ &device_present?/2) do
    case discover_one(possible_addresses, present?) do
      {:ok, actual_device} -> actual_device
      {:error, reason} -> raise "I2C discovery error: #{inspect(reason)}"
    end
  end

  defp detect_and_print(bus_name, count) do
    IO.puts("Devices on I2C bus \"#{bus_name}\":")

    devices = detect_devices(bus_name)

    Enum.each(devices, &IO.puts(" * #{&1}  (0x#{Integer.to_string(&1, 16)})"))

    IO.puts("")

    count + length(devices)
  end

  @doc """
  Return whether a device is present

  This function performs a simplistic check for an I2C device on the specified
  bus and address. It's not perfect, but works enough to be useful. Be warned
  that it does perform an I2C read on the specified address and this may cause
  some devices to actually do something.
  """
  @spec device_present?(bus(), address()) :: boolean()
  def device_present?(i2c, address) do
    case read(i2c, address, 1) do
      {:ok, _} -> true
      _ -> false
    end
  end

  @doc """
  Return info about the low level I2C interface

  This may be helpful when debugging I2C issues.
  """
  @spec info() :: map()
  defdelegate info(), to: Nif

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
