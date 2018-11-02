defmodule CircuitsI2cTest do
  use ExUnit.Case

  test "info returns a map" do
    info = Circuits.I2C.info()

    assert is_map(info)
    assert Map.has_key?(info, :name)
  end
end
