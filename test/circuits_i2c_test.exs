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

  test "discover/1" do
    assert [{"i2c-test-0", 0x10}, {"i2c-test-1", 0x20}] == I2C.discover([0x10, 0x20])
    assert [{"i2c-test-0", 0x10}] == I2C.discover([0x10])
    assert [] == I2C.discover([0x15])
  end

  test "discover/2" do
    ids = [0x10, 0x20]

    # Device 0x10 returns 0 and device 0x20 returns 0xff from the stub
    assert [{"i2c-test-0", 0x10}] == I2C.discover(ids, &i2c_returns(&1, &2, <<0>>))
    assert [{"i2c-test-1", 0x20}] == I2C.discover(ids, &i2c_returns(&1, &2, <<0xFF>>))
  end

  test "discover_one/2" do
    ids = [0x10, 0x20]

    assert {:ok, {"i2c-test-0", 0x10}} == I2C.discover_one(ids, &i2c_returns(&1, &2, <<0>>))
    assert {:error, :not_found} == I2C.discover_one(ids, &i2c_returns(&1, &2, <<1>>))
    assert {:error, :multiple_possible_matches} == I2C.discover_one(ids)
  end

  test "discover_one!/2" do
    ids = [0x10, 0x20]

    assert {"i2c-test-0", 0x10} == I2C.discover_one!(ids, &i2c_returns(&1, &2, <<0>>))
    assert_raise RuntimeError, fn -> I2C.discover_one!(ids, &i2c_returns(&1, &2, <<1>>)) end
    assert_raise RuntimeError, fn -> I2C.discover_one!(ids) end
  end

  defp i2c_returns(bus, address, what) do
    I2C.read(bus, address, 1) == {:ok, what}
  end
end
