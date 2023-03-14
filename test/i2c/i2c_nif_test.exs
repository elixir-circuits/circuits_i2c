defmodule Circuits.I2CNifTest do
  use ExUnit.Case

  alias Circuits.I2C.Nif

  describe "info/0" do
    test "info identifies as a stub and not a real i2c driver" do
      info = Nif.info()

      assert is_map(info)
      assert info.name == :stub
    end
  end

  describe "open/1" do
    test "only i2c-test-0 and i2c-test-1 work" do
      {:ok, i2c} = Nif.open("i2c-test-0")
      Nif.close(i2c)

      {:ok, i2c} = Nif.open("i2c-test-1")
      Nif.close(i2c)

      assert {:error, _} = Nif.open("i2c-2")
    end
  end

  test "unloading NIF" do
    # The theory here is that there shouldn't be a crash if this is reloaded a
    # few times.
    for _times <- 1..10 do
      assert {:module, Circuits.I2C.Nif} == :code.ensure_loaded(Circuits.I2C.Nif)

      # Try running something to verify that it works.
      {:ok, i2c} = Nif.open("i2c-test-0")
      assert is_reference(i2c)
      Nif.close(i2c)

      assert true == :code.delete(Circuits.I2C.Nif)

      # The purge will call the unload which can be verified by turning DEBUG on
      # in the C code.
      assert false == :code.purge(Circuits.I2C.Nif)
    end
  end

  describe "read/4" do
    test "reading 0x10 works for i2c-test-0" do
      {:ok, i2c} = Nif.open("i2c-test-0")

      assert {:ok, <<0x10, 0x11, 0x12, 0x13, 0x14>>} == Nif.read(i2c, 0x10, 5, 0)
      assert {:error, _} = Nif.read(i2c, 0x11, 5, 0)
      assert {:error, _} = Nif.read(i2c, 0x20, 5, 0)

      :ok = Nif.close(i2c)
    end

    test "reading 0x20 works for i2c-test-1" do
      {:ok, i2c} = Nif.open("i2c-test-1")

      assert {:ok, <<0x20, 0x21, 0x22, 0x23, 0x24>>} == Nif.read(i2c, 0x20, 5, 0)
      assert {:error, _} = Nif.read(i2c, 0x10, 5, 0)
      assert {:error, _} = Nif.read(i2c, 0x21, 5, 0)

      :ok = Nif.close(i2c)
    end
  end

  describe "write/4" do
    test "writing 0x10 works for i2c-test-0" do
      {:ok, i2c} = Nif.open("i2c-test-0")

      assert :ok == Nif.write(i2c, 0x10, <<1, 2, 3, 4>>, 0)
      assert {:error, _} = Nif.write(i2c, 0x11, <<1, 2, 3, 4>>, 0)
      assert {:error, _} = Nif.write(i2c, 0x20, <<1, 2, 3, 4>>, 0)

      :ok = Nif.close(i2c)
    end

    test "writing 0x20 works for i2c-test-1" do
      {:ok, i2c} = Nif.open("i2c-test-1")

      assert :ok == Nif.write(i2c, 0x20, <<1, 2, 3, 4>>, 0)
      assert {:error, _} = Nif.write(i2c, 0x21, <<1, 2, 3, 4>>, 0)
      assert {:error, _} = Nif.write(i2c, 0x10, <<1, 2, 3, 4>>, 0)

      :ok = Nif.close(i2c)
    end

    test "writing iodata doesn't crash" do
      {:ok, i2c} = Nif.open("i2c-test-0")

      assert :ok == Nif.write(i2c, 0x10, [<<1, 2, 3, 4>>], 0)
      assert :ok == Nif.write(i2c, 0x10, [<<>>], 0)
      assert :ok == Nif.write(i2c, 0x10, [<<1, 2>>, <<3, 4>>], 0)
      assert :ok == Nif.write(i2c, 0x10, [1, 2, 3, 4], 0)
      assert :ok == Nif.write(i2c, 0x10, [[[[<<1, 2, 3, 4>>]]]], 0)

      :ok = Nif.close(i2c)
    end
  end

  describe "write_read/5" do
    test "write_read 0x10 works for i2c-test-0" do
      {:ok, i2c} = Nif.open("i2c-test-0")

      assert {:ok, <<0x10, 0x11, 0x12, 0x13, 0x14>>} == Nif.write_read(i2c, 0x10, <<1>>, 5, 0)
      assert {:error, _} = Nif.write_read(i2c, 0x11, <<1>>, 5, 0)
      assert {:error, _} = Nif.write_read(i2c, 0x20, <<1>>, 5, 0)

      :ok = Nif.close(i2c)
    end

    test "write_read 0x20 works for i2c-test-1" do
      {:ok, i2c} = Nif.open("i2c-test-1")

      assert {:ok, <<0x20, 0x21, 0x22, 0x23, 0x24>>} == Nif.write_read(i2c, 0x20, <<1>>, 5, 0)
      assert {:error, _} = Nif.write_read(i2c, 0x11, <<1>>, 5, 0)
      assert {:error, _} = Nif.write_read(i2c, 0x10, <<1>>, 5, 0)

      :ok = Nif.close(i2c)
    end
  end

  describe "load tests" do
    test "unloading NIF" do
      # The theory here is that there shouldn't be a crash if this is reloaded a
      # few times.
      for _times <- 1..10 do
        assert {:module, Circuits.I2C.Nif} == :code.ensure_loaded(Circuits.I2C.Nif)

        # Try running something to verify that it works.
        {:ok, i2c} = Nif.open("i2c-test-0")
        assert is_reference(i2c)
        Nif.close(i2c)

        assert true == :code.delete(Circuits.I2C.Nif)

        # The purge will call the unload which can be verified by turning DEBUG on
        # in the C code.
        assert false == :code.purge(Circuits.I2C.Nif)
      end

      # Load it again for any other subsequent tests
      assert {:module, Circuits.I2C.Nif} == :code.ensure_loaded(Circuits.I2C.Nif)
    end
  end
end
