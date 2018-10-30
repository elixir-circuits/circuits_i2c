defmodule Circuits.I2C do
  @moduledoc """
  `i2c` provides high level abstractions for interfacing to I2C
  buses on Linux platforms. Internally, it uses the Linux
  sysclass interface so that it does not require platform-dependent code.
  """
  alias Circuits.I2C.Nif

  # Public API

  @type i2c_address :: 0..127

  @doc """
  Open the I2C device (Example:"i2c-1")
  Address is the default I2C device slave address
  On success, returns a reference to the I2C bus resource.
  Use the reference in subsequent calls to read/write I2C device
  """
  @spec open(binary, i2c_address) :: {:ok, reference} | {:error, term}
  def open(device, address) do
    Nif.open(to_charlist(device), address)
  end

  @doc """
  Initiate a read transaction to the device
  and specified number of bytes to read
  """
  @spec read(reference, integer) :: {:ok, binary} | {:error, term}
  def read(ref, count) do
    Nif.read(ref, count)
  end

  @doc """
  Initiate a read transaction to the device at the specified `address`
  and specified number of bytes to read
  """
  @spec read_device(reference, i2c_address, integer) :: {:ok, binary} | {:error, term}
  def read_device(ref, address, count) do
    Nif.read_device(ref, address, count)
  end

  @doc """
  Write the specified `data` to the device
  """
  @spec write(reference, binary) :: :ok | {:error, term}
  def write(ref, data) do
    Nif.write(ref, data)
  end

  @doc """
  Write the specified `data` to the device at `address`.
  """
  @spec write_device(reference, i2c_address, binary) :: :ok | {:error, term}
  def write_device(ref, address, data) do
    Nif.write_device(ref, address, data)
  end

  @doc """
  Write the specified `data` to the device
  and then read the specified number of bytes.
  """
  @spec write_read(reference, binary, integer) :: {:ok, binary} | {:error, term}
  def write_read(ref, write_data, read_count) do
    Nif.write_read(ref, write_data, read_count)
  end

  @doc """
  Write the specified `data` to the device at 'address'
  and then read the specified number of bytes.
  """
  @spec write_read_device(reference, i2c_address, binary, integer) ::
          {:ok, binary} | {:error, term}
  def write_read_device(ref, address, write_data, read_count) do
    Nif.write_read_device(ref, address, write_data, read_count)
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

  ```
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
  Scan the I2C bus for devices by performing a read at each device address
  and returning a list of device addresses that respond.

  WARNING: This is intended to be a debugging aid. Reading bytes from devices
  can advance internal state machines and might cause them to get out of sync
  with other code.

  ```
  iex> Circuits.I2C.detect_devices("i2c-1")
  [4]
  ```
  The return value is a list of device addresses that were detected on the
  specified I2C bus. If you get back `'Hh'` or other letters, then IEx
  converted the list to an Erlang string. Run `i v()` to get information about
  the return value and look at the raw string representation for addresses.

  If you already have a reference to an open device, then you may
  pass its `reference` to `detect_devices/1` instead.
  """
  @spec detect_devices(reference() | binary) :: [integer] | {:error, term}
  def detect_devices(ref) when is_reference(ref) do
    Enum.filter(0..127, &device_present?(ref, &1))
  end

  def detect_devices(dev_name) when is_binary(dev_name) do
    case open(dev_name, 0) do
      {:ok, ref} ->
        devices = detect_devices(ref)
        close(ref)
        devices

      error ->
        error
    end
  end

  defp device_present?(i2c, address) do
    case read_device(i2c, address, 1) do
      {:ok, _} -> true
      _ -> false
    end
  end
end
