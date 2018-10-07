# I2C - Do not use !!

[![CircleCI](https://circleci.com/gh/ElixirCircuits/i2c.svg?style=svg)](https://circleci.com/gh/ElixirCircuits/i2c)
[![Hex version](https://img.shields.io/hexpm/v/i2c.svg "Hex version")](https://hex.pm/packages/i2c)

`i2c` provides high level abstractions for interfacing to I2C
buses on Linux platforms. Internally, it uses the Linux
sysclass interface so that it does not require platform-dependent code.

# Getting started

If you're natively compiling i2c, everything should work like any other
Elixir library. Normally, you would include elixir_ale as a dependency in your
`mix.exs` like this:

```elixir
def deps do
  [{:i2c, "~> 0.1"}]
end
```

If you just want to try it out, you can do the following:

```shell
git clone https://github.com/ElixirCircuits/i2c
cd i2c
mix compile
iex -S mix
```

If you're cross-compiling, you'll need to setup your environment so that the
right C compiler is called. See the `Makefile` for the variables that will need
to be overridden. At a minimum, you will need to set `CROSSCOMPILE`,
`ERL_CFLAGS`, and `ERL_EI_LIBDIR`.

`i2c` doesn't load device drivers, so you'll need to make sure that any
necessary ones for accessing I2C are loaded beforehand. On the Raspberry
Pi, the [Adafruit Raspberry Pi I2C
instructions](https://learn.adafruit.com/adafruits-raspberry-pi-lesson-4-gpio-setup/configuring-i2c)
may be helpful.

If you're trying to compile on a Raspberry Pi and you get errors indicated that Erlang headers are missing
(`ie.h`), you may need to install erlang with `apt-get install
erlang-dev` or build Erlang from source per instructions [here](http://elinux.org/Erlang).

# Examples

`i2c` only supports simple uses of the I2C interface in
Linux, but you can still do quite a bit. The following examples were tested on a
Raspberry Pi that was connected to an [Erlang Embedded Demo
Board](http://solderpad.com/omerk/erlhwdemo/). There's nothing special about
either the demo board or the Raspberry Pi, so these should work similarly on
other embedded Linux platforms.

## I2C

An [Inter-Integrated Circuit](https://en.wikipedia.org/wiki/I%C2%B2C) (I2C)
bus supports addressing hardware components and bidirectional use of the data line.

The following shows a bus IO expander connected via I2C to the processor.

![I2C schematic](assets/images/schematic-i2c.png)

The protocol for talking to the IO expander is described in the [MCP23008
Datasheet](http://www.microchip.com/wwwproducts/Devices.aspx?product=MCP23008).
Here's a simple example of using it.

```Elixir
# On the Raspberry Pi, the IO expander is connected to I2C bus 1 (i2c-1).
# Its 7-bit address is 0x20. (see datasheet)
iex> {:ok, fd} = ElixirCircuits.I2C.open("i2c-1")
{:ok, 34}

# By default, all 8 GPIOs are set to inputs. Set the 4 high bits to outputs
# so that we can toggle the LEDs. (Write 0x0f to register 0x00)
iex> ElixirCircuits.I2C.write(fd, 0x20, <<0x00, 0x0f>>)
:ok

# Turn on the LED attached to bit 4 on the expander. (Write 0x10 to register
# 0x09)
iex> ElixirCircuits.I2C.write(fd, 0x20, <<0x09, 0x10>>)
:ok

# Read all 11 of the expander's registers to see that the bit 0 switch is
# the only one on and that the bit 4 LED is on.
iex> ElixirCircuits.I2C.write(fd, 0x20, <<0>>)  # Set the next register to be read to 0
:ok

iex> ElixirCircuits.I2C.read(fd, 0x20, 11)
{:ok, <<15, 0, 0, 0, 0, 0, 0, 0, 0, 17, 16>>}

# The operation of writing one or more bytes to select a register and
# then reading is very common, so a shortcut is to just run the following:
iex> ElixirCircuits.I2C.write_read(fd, 0x20, <<0>>, 11)
{:ok, <<15, 0, 0, 0, 0, 0, 0, 0, 0, 17, 16>>}

# The 17 in register 9 says that bits 0 and bit 4 are high
# We could have just read register 9.

iex> ElixirCircuits.I2C.write_read(fd, 0x20, <<9>>, 1)
{:ok, <<17>>}
```

## FAQ

### Where can I get help?

Most issues people have are on how to communicate with hardware for the first
time. Since `i2c` is a thin wrapper on the Linux sys class interface, you
may find help by searching for similar issues when using Python or C.

For help specifically with `i2c`, you may also find help on the
nerves channel on the [elixir-lang Slack](https://elixir-slackin.herokuapp.com/).
Many [Nerves](http://nerves-project.org) users also use `i2c`.

### Where's PWM support?

On the hardware that I normally use, PWM has been implemented in a
platform-dependent way. For ease of maintenance, `i2c` doesn't have any
platform-dependent code, so supporting it would be difficult. An Elixir PWM
library would be very interesting, though, should anyone want to implement it.

### Can I develop code that uses i2c on my laptop?

You'll need to fake out the hardware. Code to do this depends
on what your hardware actually does, but here's one example:

  * http://www.cultivatehq.com/posts/compiling-and-testing-elixir-nerves-on-your-host-machine/

Please share other examples if you have them.

### How do I debug?

The most common issue is communicating with an I2C for the first time.
For I2C, first check that an I2C bus is available:

```elixir
iex> ElixirCircuits.I2C.device_names
["i2c-1"]
```

If the list is empty, then I2C is either not available, not enabled, or not
configured in the kernel. If you're using Raspbian, run `raspi-config` and check
that I2C is enabled in the advanced options. If you're on a BeagleBone, try
running `config-pin` and see the [Universal I/O
project](https://github.com/cdsteinkuehler/beaglebone-universal-io) to enable
the I2C pins. On other ARM boards, double check that I2C is enabled in the
kernel and that the device tree configures it.

Once an I2C bus is available, try detecting devices on it:

```elixir
iex> ElixirCircuits.I2C.detect_devices("i2c-1")
[4]
```

The return value here is a list of device addresses that were detected. It is
still possible that the device will work even if it does not detect, but you
probably want to check wires at this point. If you have a logic analyzer, use it
to verify that I2C transactions are being initiated on the bus.

### Will it run on Arduino?

No. I2c  only runs on Linux-based boards. If you're interested in controlling an Arduino from a computer that can run Elixir, check out [nerves_uart](https://hex.pm/packages/nerves_uart) for communicating via the Arduino's serial connection or [firmata](https://github.com/mobileoverlord/firmata) for communication using the Arduino's Firmata protocol.

### Can I help maintain elixir_circuits?

Yes! If your life has been improved by `i2c` and you want to give back,
it would be great to have new energy put into this project. Please email me.

# License

This library draws much of its design and code from the Erlang/ALE project which
is licensed under the Apache License, Version 2.0. As such, it is licensed
similarly.
