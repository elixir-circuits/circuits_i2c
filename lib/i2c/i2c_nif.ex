defmodule Circuits.I2C.Nif do
  @on_load {:load_nif, 0}
  @compile {:autoload, false}

  @doc """
  Elixir interface to I2C Natively Implemented Funtions (NIFs)
  """

  def load_nif() do
    nif_binary = Application.app_dir(:circuits_i2c, "priv/i2c_nif")
    :erlang.load_nif(to_charlist(nif_binary), 0)
  end

  def open(_device, _address) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def read(_ref, _count) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def read_device(_ref, _address, _count) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def write(_ref, _data) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def write_device(_ref, _address, _data) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def write_read(_ref, _write_data, _read_count) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def write_read_device(_ref, _address, _write_data, _read_count) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def close(_ref) do
    :erlang.nif_error(:nif_not_loaded)
  end
end
