defmodule CircuitsI2cTest do
  use ExUnit.Case

  alias Circuits.I2C

  test "info returns a map" do
    info = I2C.info()

    assert is_map(info)
    assert Map.has_key?(info, :name)
  end

  test "bus_names returns a list" do
    names = I2C.bus_names()

    assert is_list(names)
  end

  test "error when opening unknown bus" do
    assert {:error, :bus_not_found} == I2C.open("bogus")
  end
end
