defmodule Circuits.I2CDevTest do
  use ExUnit.Case

  alias Circuits.I2C.Backend
  alias Circuits.I2C.I2CDev

  describe "info/0" do
    test "info identifies as a i2c_dev_test and not a real i2c driver" do
      info = I2CDev.info()

      assert is_map(info)
      assert info.name == :i2c_dev_test
    end
  end

  describe "open/1" do
    test "i2c-test-0 and i2c-test-1 work" do
      {:ok, i2c} = I2CDev.open("i2c-test-0")
      Backend.close(i2c)

      {:ok, i2c} = I2CDev.open("i2c-test-1")
      Backend.close(i2c)

      assert {:error, _} = I2CDev.open("i2c-2")
    end

    test "retry option" do
      # No retries fails with the flaky I2C bus
      {:ok, i2c} = I2CDev.open("i2c-flaky")
      assert {:error, _reason} = Backend.read(i2c, 0x30, 5, [])
      Backend.close(i2c)

      # One retry works
      {:ok, i2c} = I2CDev.open("i2c-flaky", retries: 1)
      assert {:ok, <<0x30, 0x31, 0x32, 0x33, 0x34>>} == Backend.read(i2c, 0x30, 5, [])
      Backend.close(i2c)
    end
  end

  describe "read/4" do
    test "reading 0x10 works for i2c-test-0" do
      {:ok, i2c} = I2CDev.open("i2c-test-0")

      assert {:ok, <<0x10, 0x11, 0x12, 0x13, 0x14>>} == Backend.read(i2c, 0x10, 5, [])
      assert {:error, _} = Backend.read(i2c, 0x11, 5, [])
      assert {:error, _} = Backend.read(i2c, 0x20, 5, [])

      :ok = Backend.close(i2c)
    end

    test "reading 0x20 works for i2c-test-1" do
      {:ok, i2c} = I2CDev.open("i2c-test-1")

      assert {:ok, <<0x20, 0x21, 0x22, 0x23, 0x24>>} == Backend.read(i2c, 0x20, 5, [])
      assert {:error, _} = Backend.read(i2c, 0x10, 5, [])
      assert {:error, _} = Backend.read(i2c, 0x21, 5, [])

      :ok = Backend.close(i2c)
    end

    test "reading 0x30 works for i2c-flaky with retry" do
      {:ok, i2c} = I2CDev.open("i2c-flaky")

      # No retries fails with the flaky I2C bus
      assert {:error, _reason} = Backend.read(i2c, 0x30, 5, [])

      # One retry works
      assert {:ok, <<0x30, 0x31, 0x32, 0x33, 0x34>>} == Backend.read(i2c, 0x30, 5, retries: 1)
      Backend.close(i2c)
    end
  end

  describe "write/4" do
    test "writing 0x10 works for i2c-test-0" do
      {:ok, i2c} = I2CDev.open("i2c-test-0")

      assert :ok == Backend.write(i2c, 0x10, <<1, 2, 3, 4>>, [])
      assert {:error, _} = Backend.write(i2c, 0x11, <<1, 2, 3, 4>>, [])
      assert {:error, _} = Backend.write(i2c, 0x20, <<1, 2, 3, 4>>, [])

      :ok = Backend.close(i2c)
    end

    test "writing 0x20 works for i2c-test-1" do
      {:ok, i2c} = I2CDev.open("i2c-test-1")

      assert :ok == Backend.write(i2c, 0x20, <<1, 2, 3, 4>>, [])
      assert {:error, _} = Backend.write(i2c, 0x21, <<1, 2, 3, 4>>, [])
      assert {:error, _} = Backend.write(i2c, 0x10, <<1, 2, 3, 4>>, [])

      :ok = Backend.close(i2c)
    end

    test "writing 0x30 works for i2c-flaky with retry" do
      {:ok, i2c} = I2CDev.open("i2c-flaky")

      assert {:error, _} = Backend.write(i2c, 0x30, <<1, 2, 3, 4>>, [])
      assert :ok == Backend.write(i2c, 0x30, <<1, 2, 3, 4>>, retries: 1)

      :ok = Backend.close(i2c)
    end

    test "writing iodata doesn't crash" do
      {:ok, i2c} = I2CDev.open("i2c-test-0")

      assert :ok == Backend.write(i2c, 0x10, [<<1, 2, 3, 4>>], [])
      assert :ok == Backend.write(i2c, 0x10, [<<>>], [])
      assert :ok == Backend.write(i2c, 0x10, [<<1, 2>>, <<3, 4>>], [])
      assert :ok == Backend.write(i2c, 0x10, [1, 2, 3, 4], [])
      assert :ok == Backend.write(i2c, 0x10, [[[[<<1, 2, 3, 4>>]]]], [])

      :ok = Backend.close(i2c)
    end
  end

  describe "write_read/5" do
    test "write_read 0x10 works for i2c-test-0" do
      {:ok, i2c} = I2CDev.open("i2c-test-0")

      assert {:ok, <<0x10, 0x11, 0x12, 0x13, 0x14>>} ==
               Backend.write_read(i2c, 0x10, <<1>>, 5, [])

      assert {:error, _} = Backend.write_read(i2c, 0x11, <<1>>, 5, [])
      assert {:error, _} = Backend.write_read(i2c, 0x20, <<1>>, 5, [])

      :ok = Backend.close(i2c)
    end

    test "write_read 0x20 works for i2c-test-1" do
      {:ok, i2c} = I2CDev.open("i2c-test-1")

      assert {:ok, <<0x20, 0x21, 0x22, 0x23, 0x24>>} ==
               Backend.write_read(i2c, 0x20, <<1>>, 5, [])

      assert {:error, _} = Backend.write_read(i2c, 0x11, <<1>>, 5, [])
      assert {:error, _} = Backend.write_read(i2c, 0x10, <<1>>, 5, [])

      :ok = Backend.close(i2c)
    end

    test "write_read 0x30 works for i2c-flaky with retry" do
      {:ok, i2c} = I2CDev.open("i2c-flaky")

      assert {:error, _} = Backend.write_read(i2c, 0x30, <<1>>, 5, [])

      assert {:ok, <<0x30, 0x31, 0x32, 0x33, 0x34>>} ==
               Backend.write_read(i2c, 0x30, <<1>>, 5, retries: 1)

      :ok = Backend.close(i2c)
    end
  end
end
