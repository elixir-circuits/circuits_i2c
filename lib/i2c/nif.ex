defmodule I2C.Nif do
  @on_load {:load_nif, 0}
  @compile {:autoload, false}

  def load_nif() do
    nif_exec = '#{:code.priv_dir(:i2c)}/i2c_nif'
    :erlang.load_nif(nif_exec, 0)
  end


  def hello() do
    :erlang.nif_error(:nif_not_loaded)
  end
end
