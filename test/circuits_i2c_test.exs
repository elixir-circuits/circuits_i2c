defmodule Circuits.I2CTest do
  use ExUnit.Case

  alias Circuits.I2C

  test "bus_names returns a list" do
    names = I2C.bus_names()

    assert is_list(names)
    assert "i2c-test-0" in names
    assert "i2c-test-1" in names
  end

  test "can open buses" do
    {:ok, i2c} = I2C.open("i2c-test-0")
    assert is_reference(i2c)
    I2C.close(i2c)

    {:ok, i2c} = I2C.open("i2c-test-1")
    assert is_reference(i2c)
    I2C.close(i2c)
  end

  test "error when opening unknown bus" do
    assert {:error, :bus_not_found} == I2C.open("bad-i2c-bus")
  end

  test "detects stub devices" do
    # See hal_stub.c for fake devices
    assert [0x10] == I2C.detect_devices("i2c-test-0")
    assert [0x20] == I2C.detect_devices("i2c-test-1")
    assert {:error, :bus_not_found} == I2C.detect_devices("bad-i2c-bus")
  end

  test "device_present?" do
    {:ok, i2c} = I2C.open("i2c-test-0")
    assert I2C.device_present?(i2c, 0x10)
    refute I2C.device_present?(i2c, 0x11)
    I2C.close(i2c)
  end
end
