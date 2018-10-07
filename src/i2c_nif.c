/*
 *  Copyright 2018 Frank Hunleth, Mark Sebald
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * I2C NIF implementation.
 */

#include <err.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#include "linux/i2c-dev.h"
#include "erl_nif.h"

//#define DEBUG
#ifdef DEBUG
#define debug(...) do { fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\r\n"); } while(0)
#else
#define debug(...)
#endif

#define I2C_BUFFER_MAX 8192

/**
 * @brief   I2C combined write/read operation
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
 * @return  1 for success, 0 for failure
 */
static int i2c_transfer(int fd,
                        unsigned int addr,
                        const uint8_t *to_write, size_t to_write_len,
                        uint8_t *to_read, size_t to_read_len)
{
    struct i2c_rdwr_ioctl_data data;
    struct i2c_msg msgs[2];

    msgs[0].addr = addr;
    msgs[0].flags = 0;
    msgs[0].len = to_write_len;
    msgs[0].buf = (uint8_t *) to_write;

    msgs[1].addr = addr;
    msgs[1].flags = I2C_M_RD;
    msgs[1].len = to_read_len;
    msgs[1].buf = (uint8_t *) to_read;

    if (to_write_len != 0)
        data.msgs = &msgs[0];
    else
        data.msgs = &msgs[1];

    data.nmsgs = (to_write_len != 0 && to_read_len != 0) ? 2 : 1;

    int rc = ioctl(fd, I2C_RDWR, &data);
    if (rc < 0)
        return 0;
    else
        return 1;
}


static ERL_NIF_TERM open_i2c(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    char device[32];
    char devpath[64]="/dev/";

    if (!enif_get_string(env, argv[0], (char*)&device, sizeof(device), ERL_NIF_LATIN1))
        return enif_make_badarg(env);

    strncat(devpath, device, sizeof(device));

    int fd = open(devpath, O_RDWR);
    if (fd < 0)
        return enif_make_tuple2(env, enif_make_atom(env, "error"),
                                enif_make_atom(env, "access_denied"));

    return enif_make_tuple2(env, enif_make_atom(env, "ok"), enif_make_int(env, fd));
}


static ERL_NIF_TERM read_i2c(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    int fd;
    unsigned int addr;
    unsigned long read_len;
    uint8_t read_data[I2C_BUFFER_MAX];
    ErlNifBinary bin_read;

    if (!enif_get_int(env, argv[0], &fd))
        return enif_make_badarg(env);

    if (!enif_get_uint(env, argv[1], &addr))
        return enif_make_badarg(env);

    if (!enif_get_ulong(env, argv[2], &read_len))
        return enif_make_badarg(env);

    if (i2c_transfer(fd, addr, 0, 0, read_data, read_len)) {
        bin_read.data = read_data;
        bin_read.size = read_len;
        return enif_make_tuple2(env, enif_make_atom(env, "ok"), enif_make_binary(env, &bin_read));
    }
    else
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_atom(env, "read_failed"));
}


static ERL_NIF_TERM write_i2c(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    int fd;
    unsigned int addr;
    ErlNifBinary bin_write;

    if (!enif_get_int(env, argv[0], &fd))
        return enif_make_badarg(env);

    if (!enif_get_uint(env, argv[1], &addr))
        return enif_make_badarg(env);

    if (!enif_inspect_binary(env, argv[2], &bin_write))
        return enif_make_badarg(env);

    if (i2c_transfer(fd, addr, bin_write.data, bin_write.size, 0, 0)) {
        return enif_make_atom(env, "ok");
    }
    else
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_atom(env, "write_failed"));
}


static ERL_NIF_TERM write_read_i2c(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    int fd;
    unsigned int addr;
    ErlNifBinary bin_write;
    uint8_t read_data[I2C_BUFFER_MAX];
    unsigned long read_len;
    ErlNifBinary bin_read;

    if (!enif_get_int(env, argv[0], &fd))
        return enif_make_badarg(env);

    if (!enif_get_uint(env, argv[1], &addr))
        return enif_make_badarg(env);

    if (!enif_inspect_binary(env, argv[2], &bin_write))
        return enif_make_badarg(env);

    if (!enif_get_ulong(env, argv[3], &read_len))
        return enif_make_badarg(env);

    if (i2c_transfer(fd, addr, bin_write.data, bin_write.size, read_data, read_len)) {
        bin_read.data = read_data;
        bin_read.size = read_len;
        return enif_make_tuple2(env, enif_make_atom(env, "ok"), enif_make_binary(env, &bin_read));
    }
    else
        return enif_make_tuple2(env, enif_make_atom(env, "error"), enif_make_atom(env, "write_read_failed"));
}


static ErlNifFunc nif_funcs[] =
{
    {"open", 1, open_i2c, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"read", 3, read_i2c, 0},
    {"write", 3, write_i2c, 0},
    {"write_read", 4, write_read_i2c, 0}
};


ERL_NIF_INIT(Elixir.ElixirCircuits.I2C.Nif, nif_funcs, NULL, NULL, NULL, NULL)
