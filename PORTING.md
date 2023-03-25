# Porting

## Upgrading Circuits.I2C 1.0 projects to 2.0

Circuits.I2C 2.0 supports alternative I2C hardware and the ability to mock or
emulate devices via backends. The Linux i2c-dev backend is the default and this
matches Circuits.I2C 1.0. Most projects won't need any changes other than to
update the dependency in `mix.exs`. If upgrading a library, The following
dependency specification is recommended to allow both `circuits_i2c` versions:

```elixir
   {:circuits_i2c, "~> 2.0 or ~> 1.0"}
```

The following potentially breaking changes were made:

1. `Circuits.I2C.open/1` no longer accepts Erlang strings.
2. The `stub` implementation has been renamed to `i2c_dev_test`. If using the
   stub implementation for testing, you may have to update your tests since
   there were minor changes.

## Upgrading Elixir/ALE projects to Circuits.I2C

The `Circuits.I2C` package is the next version of Elixir/ALE's I2C support.
If you're currently using Elixir/ALE, you're encouraged to switch. Here are some
benefits:

1. Supported by both the maintainer of Elixir/ALE and a couple others. They'd
   prefer to support `Circuits.I2C` issues.
2. Much faster than Elixir/ALE.
3. Simplified API

`Circuits.I2C` uses Erlang's NIF interface. NIFs have the downside of being able
to crash the Erlang VM. Experience with Elixir/ALE has given many of us
confidence that this won't be a problem.

### Code modifications

`Circuits.I2C` is not a `GenServer`, so if you've added `ElixirALE.I2C` to a
supervision tree, you'll have to take it out and manually call
`Circuits.I2C.open` to obtain a reference. A common pattern is to create a
`GenServer` that is descriptive of what the I2C device does and have it be
responsible for all I2C calls.

The remain modifications should mostly be mechanical:

1. Rename references to `ElixirALE.I2C` to `Circuits.I2C` and `elixir_ale`
   to `circuits_i2c`
2. Change calls to `ElixirALE.I2C.start_link/2` to `Circuits.I2C.open/1`. You'll
   need to remove the I2C address from the call to open. While you're at it,
   review the arguments to open to not include any `GenServer` options.
3. Add the I2C device's bus address to all of the `read`, `write`, and
   `write_read` calls. We recommend making a short helper function that has
   the I2C address.
4. The `read` and `write_read` functions now return `{:ok, result}` tuples on
   success so add code to handle that. Alternately, call `read!` or `write_read!`
   and they will raise an exception if there's an error.
5. Look for calls to `I2C.read_device`, `I2C.write_device` and
   `I2C.write_read_device` and remove the `_device` part.
6. Consider adding a call to `Circuits.I2C.close/1` if there's an obvious place
   to release the I2C. This is not strictly necessary since the garbage
   collector will free unreferenced I2C references.
7. If you manually implemented I2C bus retry logic, consider specifying the
   `:retries` option to have `Circuits.I2C` retry for you.
8. Change calls to `ElixirALE.I2C.device_names/0` to `Circuits.I2C.bus_names/0`.

If you find that you have to make any other changes, please let us know via an
issue or PR so that other users can benefit.
