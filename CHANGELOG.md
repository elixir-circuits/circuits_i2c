# Changelog

## v1.1.0 - 2022-11-16

* Changes
  * Immediately close I2C bus references after discovery. Waiting for the GC to
    collect them could cause intermittent failures in rare scenarios where
    multiple I2C device discoveries are done close together. This likely only
    affects CI in practice.
  * Remove Erlang convenience functions since no one used them
  * Require Elixir 1.10 or later. Previous versions probably work, but won't be
    supported. This opens up the possibility of using Elixir 1.10+ features in
    future releases.

## v1.0.1 - 2021-12-28

* Fixes
  * Properly mark I/O bound functions in NIF.

## v1.0.0 - 2021-10-20

This release only changes the version number. No code has changed.

## v0.3.9

This release only has doc and build output cleanup. No code has changed.

## v0.3.8

* New features
  * Add `Circuits.I2C.discover/2` and `Circuits.I2C.discover_one/2`. These
    functions are intended for library authors wanting to provide good
    suggestions or defaults to their users. See the hex docs for more
    information. Thanks to Bruce Tate for the idea and PR.

* Improvements
  * The stub I2C implementation is now used whenever `MIX_ENV=test`. While this
    is not generally useful for testing code that uses Circuits.I2C, it does
    prevent accidental use of real I2C buses in unit tests on those systems
    with real I2C buses.

## v0.3.7

* Improvements
  * Add I2C address in hex showing detected devices

## v0.3.6

* Bug fixes
  * Add -fPIC to compilation flags to fix build with `nerves_system_x86_64` and
    other environments using the Musl C toolchains

## v0.3.5

* Bug fixes
  * Reduce the number of I2C addresses scanned for detection to avoid confusing
    some devices.

## v0.3.4

This release should work on Erlang/OTP 20 - 22 and Elixir 1.4 and
newer. The CI process has been updated to verify more versions now.

* Bug fixes
  * Improve error message when bus doesn't exist

## v0.3.3

* Bug fixes
  * Fix binary handling in NIF. This fixes segfaults and other errors when run
    on Raspbian.

## v0.3.2

* Bug fixes
  * Fix file handle leak when I2C bus references were garbage collected.

## v0.3.1

* Bug fixes
  * Build C source under the `_build` directory so that changing targets
    properly rebuilds the C code as well as the Elixir code.

## v0.3.0

Print detected devices instead of an error.

## v0.2.0

Minor text updates.

Remove i2c_ from i2c_address and i2c_bus.

## v0.1.0

Initial release to hex.
