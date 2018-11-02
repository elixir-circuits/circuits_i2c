defmodule Circuits.I2C do
  @moduledoc """
  `i2c` provides high level abstractions for interfacing to I2C buses on Linux
  platforms. Internally, it uses the Linux sysclass interface so that it does
  not require platform-dependent code.
  """
  alias Circuits.I2C.Nif

  # Public API

  @typedoc """
  I2C device address

  This is a "7-bit" address for the device. Some devices
  specify an "8-bit" address in their documentation. You can tell if you have
  an "8-bit" address if it's greater than 127 (0x7f) or if the documentation
  talks about different read and write addresses. If you have an 8-bit address,
  divide it by 2.
  """
  @type i2c_address :: 0..127

  @doc """
  Open an I2C device

  I2C device names depend on the platform. Each I2C device handles access to
  one I2C bus. Names are of the form "i2c-n" where the "n" is the bus number.
  The correct bus number can be found in the documentation for the device or on
  a schematic. One other option is to call `Circuits.I2C.device_names/1` to
  list them for you.

  On success, this returns a reference to the I2C bus resource.  Use the
  reference in subsequent calls to read/write I2C device
  """
  @spec open(binary) :: {:ok, reference} | {:error, term}
  def open(device) do
    Nif.open(to_charlist(device))
  end

  @doc """
  Initiate a read transaction to the device at the specified `address`

  Options:

  * :retries - number of retries before failing (defaults to no retries)
  """
  @spec read(reference, i2c_address, pos_integer, keyword) :: {:ok, binary} | {:error, term}
  def read(ref, address, count, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)

    retry(fn -> Nif.read(ref, address, count) end, retries)
  end

  @doc """
  Initiate a read transaction and raise on error
  """
  @spec read!(reference, i2c_address, pos_integer, keyword) :: binary
  def read!(ref, address, count, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)

    retry!(fn -> Nif.read(ref, address, count) end, retries)
  end

  @doc """
  Write `data` to the I2C device at `address`.

  Options:

  * :retries - number of retries before failing (defaults to no retries)
  """
  @spec write(reference, i2c_address, binary, keyword) :: :ok | {:error, term}
  def write(ref, address, data, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)
    retry(fn -> Nif.write(ref, address, data) end, retries)
  end

  @doc """
  Write `data` to the I2C device at `address` and raise on error

  Options:

  * :retries - number of retries before failing (defaults to no retries)
  """
  @spec write!(reference, i2c_address, binary, keyword) :: :ok
  def write!(ref, address, data, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)
    retry!(fn -> Nif.write(ref, address, data) end, retries)
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

  * :retries - number of retries before failing (defaults to no retries)
  """
  @spec write_read(reference, i2c_address, binary, pos_integer, keyword) ::
          {:ok, binary} | {:error, term}
  def write_read(ref, address, write_data, read_count, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)

    retry(fn -> Nif.write_read(ref, address, write_data, read_count) end, retries)
  end

  @doc """
  Write `data` to an I2C device and then immediately issue a read. Raise on errors.

  Options:

  * :retries - number of retries before failing (defaults to no retries)
  """
  @spec write_read!(reference, i2c_address, binary, pos_integer, keyword) :: binary
  def write_read!(ref, address, write_data, read_count, opts \\ []) do
    retries = Keyword.get(opts, :retries, 0)

    retry!(fn -> Nif.write_read(ref, address, write_data, read_count) end, retries)
  end

  @doc """
  close the I2C device
  """
  @spec close(reference) :: :ok
  def close(ref) do
    Nif.close(ref)
  end

  @doc """
  Return a list of available I2C bus device names.  If nothing is returned,
  it's possible that the kernel driver for that I2C bus is not enabled or the
  kernel's device tree is not configured. On Raspbian, run `raspi-config` and
  look in the advanced options.

  ```elixir
  iex> Circuits.I2C.device_names
  ["i2c-1"]
  ```
  """
  @spec device_names() :: [binary]
  def device_names() do
    Path.wildcard("/dev/i2c-*")
    |> Enum.map(fn p -> String.replace_prefix(p, "/dev/", "") end)
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
  @spec detect_devices(reference() | binary) :: [i2c_address] | {:error, term}
  def detect_devices(ref) when is_reference(ref) do
    Enum.filter(0..127, &device_present?(ref, &1))
  end

  def detect_devices(dev_name) when is_binary(dev_name) do
    case open(dev_name) do
      {:ok, ref} ->
        devices = detect_devices(ref)
        close(ref)
        devices

      error ->
        error
    end
  end

  @doc """
  Provide a helpful message when forgetting to pass a device name

  This is only intended to be called from the iex prompt and it's
  almost certainly done by accident.
  """
  @spec detect_devices() :: {:error, :no_device}
  def detect_devices() do
    IO.puts("Specify an I2C device name to scan for devices. Try one of the following:\n")
    Enum.each(device_names(), &IO.puts([" * ", &1]))
    {:error, :no_device}
  end

  @doc """
  Return info about the low level I2C interface

  This may be helpful when debugging I2C issues.
  """
  @spec info() :: map
  defdelegate info(), to: Nif

  defp device_present?(i2c, address) do
    case read(i2c, address, 1) do
      {:ok, _} -> true
      _ -> false
    end
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
