# Changelog

## v2.0.3 - 2024-01-18

* Bug fixes
  * Remove lazy NIF loading. There's an unexplained segfault in a small example
    program that uses the same strategy. Even though it wasn't reproduceable
    here, it's not worth the risk. Thanks to @pojiro for investigating.

## v2.0.2 - 2024-01-14

* Changes
  * Fix race condition when multiple processes load the NIF simultaneously that
    would cause an unnecessary crash.
  * Bump minimum supported version of Elixir to 1.11 since no longer testing
    with it due to a dependency issue.

## v2.0.1 - 2023-10-22

* Changes
  * Add `Circuits.I2C.bus()` type back to fix a dialyzer warning on projects
    that support both Circuits.I2C 1.0 and 2.0.

## v2.0.0 - 2023-08-14

This is a major update to Circuits.I2C that removes the requirement to use
Nerves or Linux. The API is almost the same and the default is to compile and
use the Linux backend, so changes may not be needed.

* Changes
  * Support alternative backends for different operating systems or for
    simulated hardware
  * For the Linux NIF, support passing a `:retry` count to `Circuits.I2C.open/2`
    that will apply to all I2C operations. This simplifies dealing with devices
    with flaky connections.
  * Defer loading the Linux NIF until `Circuits.I2C.open/2` is called
  * Return error on `Circuits.I2C.open/2` if the device isn't a real I2C device.
    This was previously detected on the first operation.
  * For the Linux NIF, return errno numbers rather than their `strerr` strings
    when they're unknown. It turned out that the strings could be more confusing
    that the numbers.

## v1.2.2 - 2023-03-24

* Fixes
  * Add types.h compatibility header to hex package so that host MacOS builds
    work again.

## v1.2.1 - 2023-03-20

* Fixes
  * Detect I2C controllers that don't support 0-byte writes and revert to the
    old detection heuristic. This fixes an issue on Beaglebones (AM335x) that
    caused devices to be missed and kernel warnings to be logged.

## v1.2.0 - 2023-03-17

* Changes
  * Improve device detection by using 0-byte writes on some I2C addresses and
    1-byte reads on others. This matches the i2c-tools heuristic and detects at
    least on more device that wasn't detected before.
  * Simplified NIF by deleting a lot of flexibility that didn't end up being
    useful. Also moved functionality around so that it could be implemented more
    simply.

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
