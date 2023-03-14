defmodule Circuits.I2C.Nif do
  @on_load {:load_nif, 0}
  @compile {:autoload, false}

  @moduledoc false

  def load_nif() do
    nif_binary = Application.app_dir(:circuits_i2c, "priv/i2c_nif")
    :erlang.load_nif(to_charlist(nif_binary), 0)
  end

  def open(_device), do: :erlang.nif_error(:nif_not_loaded)
  def read(_ref, _address, _count, _retries), do: :erlang.nif_error(:nif_not_loaded)
  def write(_ref, _address, _data, _retries), do: :erlang.nif_error(:nif_not_loaded)

  def write_read(_ref, _address, _write_data, _read_count, _retries),
    do: :erlang.nif_error(:nif_not_loaded)

  def close(_ref), do: :erlang.nif_error(:nif_not_loaded)
  def info(), do: :erlang.nif_error(:nif_not_loaded)
end
