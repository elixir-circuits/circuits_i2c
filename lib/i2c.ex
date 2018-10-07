defmodule ElixirCircuits.I2C do
  @moduledoc """
  `i2c` provides high level abstractions for interfacing to I2C
  buses on Linux platforms. Internally, it uses the Linux
  sysclass interface so that it does not require platform-dependent code.
  """
  alias ElixirCircuits.I2C.Nif, as: Nif

  # Public API

  @type i2c_address :: 0..127

  @doc """
  Open the I2C device (Example:"i2c-1")
  On success, returns an integer file descriptor.
  Use file descriptor (fd) in subsequent calls to read/write I2C nodes
  """
  @spec open(binary) :: {:ok, integer} | {:error, term}
  def open(device) do
    Nif.open(to_charlist(device))
  end

  @doc """
  Initiate a read transaction to the device at the specified `address`
  and specified number of bytes to read
  """
  @spec read(integer, i2c_address, integer) :: {:ok, binary} | {:error, term}
  def read(fd, address, count) do
    Nif.read(fd, address, count)
  end

  @doc """
  Write the specified `data` to the device at `address`.
  """
  @spec write(integer, i2c_address, binary) :: :ok | {:error, term}
  def write(fd, address, data) do
    Nif.write(fd, address, data)
  end

  @doc """
  Write the specified `data` to the device at 'address' 
  and then read the specified number of bytes. 
  """
  @spec write_read(integer, i2c_address, binary, integer) :: {:ok, binary} | {:error, term}
  def write_read(fd, address, write_data, read_count) do
    Nif.write_read(fd, address, write_data, read_count)
  end

  @doc """
  Return a list of available I2C bus device names.  If nothing is returned,
  it's possible that the kernel driver for that I2C bus is not enabled or the
  kernel's device tree is not configured. On Raspbian, run `raspi-config` and
  look in the advanced options.

  ```
  iex> ElxirCircuits.I2C.device_names
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
  with other code. Also the I2C device file is (re)opened, 
  which generates a new file descriptor, which will invalidate an existing 'fd'.

  ```
  iex> ElxirCircuits.I2C.detect_devices("i2c-1")
  [4]
  ```
  The return value is a list of device addresses that were detected on the
  specified I2C bus. If you get back `'Hh'` or other letters, then IEx
  converted the list to an Erlang string. Run `i v()` to get information about
  the return value and look at the raw string representation for addresses.
  """
  @spec detect_devices(binary) :: [integer] | {:error, term}
  def detect_devices(devname) do
    case open(devname) do
      {:ok, fd} ->
        Enum.reject(0..127, &(read(fd, &1, 1) == {:error, :read_failed}))

      error ->
        error
    end
  end
end
