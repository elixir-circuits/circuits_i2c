# SPDX-FileCopyrightText: 2023 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

defmodule Circuits.I2C.Nif do
  @moduledoc false

  @on_load {:load_nif, 0}
  @compile {:autoload, false}

  def load_nif() do
    :erlang.load_nif(:code.priv_dir(:circuits_i2c) ++ ~c"/i2c_nif", 0)
  end

  def open(_device, _timeout), do: :erlang.nif_error(:nif_not_loaded)
  def read(_ref, _address, _count, _retries), do: :erlang.nif_error(:nif_not_loaded)
  def write(_ref, _address, _data, _retries), do: :erlang.nif_error(:nif_not_loaded)

  def write_read(_ref, _address, _write_data, _read_count, _retries),
    do: :erlang.nif_error(:nif_not_loaded)

  def close(_ref), do: :erlang.nif_error(:nif_not_loaded)
  def info(), do: :erlang.nif_error(:nif_not_loaded)
end
