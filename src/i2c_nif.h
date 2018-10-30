#ifndef I2C_NIF_H
#define I2C_NIF_H

#include <erl_nif.h>
#include <err.h>
#include <stdint.h>
#include <stdio.h>

//#define DEBUG

#ifdef DEBUG
#define log_location stderr
//#define LOG_PATH "/tmp/circuits_i2c.log"
#define debug(...) do { enif_fprintf(log_location, __VA_ARGS__); enif_fprintf(log_location, "\r\n"); fflush(log_location); } while(0)
#define error(...) do { debug(__VA_ARGS__); } while (0)
#define start_timing() ErlNifTime __start = enif_monotonic_time(ERL_NIF_USEC)
#define elapsed_microseconds() (enif_monotonic_time(ERL_NIF_USEC) - __start)
#else
#define debug(...)
#define error(...) do { enif_fprintf(stderr, __VA_ARGS__); enif_fprintf(stderr, "\n"); } while(0)
#define start_timing()
#define elapsed_microseconds() 0
#endif

#define I2C_BUFFER_MAX 8192

/**
 * Open an I2C device
 *
 * @param device the name of the I2C device
 *
 * @return <0 on error or a handle on success
 */
int hal_i2c_open(const char *device);

/**
 * Free resources associated with an I2C device
 */
void hal_i2c_close(int fd);

/**
 * I2C combined write/read operation
 *
 * This function can be used to individually read or write
 * bytes across the bus. Additionally, a write and read
 * operation can be combined into one transaction. This is
 * useful for communicating with register-based devices that
 * support setting the current register via the first one or
 * two bytes written.
 *
 * @param   fd            The I2C device file descriptor
 * @param   addr          The device address
 * @param   to_write      Optional write buffer
 * @param   to_write_len  Write buffer length
 * @param   to_read       Optional read buffer
 * @param   to_read_len   Read buffer length
 *
 * @return  <0 for failure
 */
int hal_i2c_transfer(int fd,
                     unsigned int addr,
                     const uint8_t *to_write, size_t to_write_len,
                     uint8_t *to_read, size_t to_read_len);

#endif // I2C_NIF_H
