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

#include "i2c_nif.h"


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


static int i2c_load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM info)
{
#ifdef DEBUG
#ifdef LOG_PATH
    log_location = fopen(LOG_PATH, "w");
#endif
#endif
    debug("i2c_load");

    I2cNifPriv *priv = enif_alloc(sizeof(I2cNifPriv));
    if (!priv) {
        error("Can't allocate i2c priv");
        return 1;
    }

    priv->i2c_nif_res_type = enif_open_resource_type(env, NULL, "i2c_nif_res_type", NULL, ERL_NIF_RT_CREATE, NULL);
    if (priv->i2c_nif_res_type == NULL) {
        error("open I2C NIF resource type failed");
        return 1;
    }

    priv->i2c_nif_res_list = NULL;
    priv->atom_ok = enif_make_atom(env, "ok");
    priv->atom_error = enif_make_atom(env, "error");

    *priv_data = priv;
    return 0;
}


static void i2c_unload(ErlNifEnv *env, void *priv_data)
{
    debug("i2c_unload");
    I2cNifPriv *priv = enif_priv_data(env);

    I2cNifResList *entry = priv->i2c_nif_res_list;
    I2cNifResList *free_this;

    while(entry != NULL) {
        close(entry->res->fd);
        enif_release_resource(entry->res);
        free_this = entry;
        entry = entry->next;
        enif_free(free_this);
    }

    enif_free(priv);
}


static ERL_NIF_TERM i2c_open(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    I2cNifPriv *priv = enif_priv_data(env);

    char device[16];
    char devpath[64]="/dev/";
    unsigned addr;

    if (!enif_get_string(env, argv[0], device, sizeof(device), ERL_NIF_LATIN1))
        return enif_make_badarg(env);

    if (!enif_get_uint(env, argv[1], &addr))
        return enif_make_badarg(env);

    int fd = get_i2c_res_fd(priv->i2c_nif_res_list, device);

    if (fd == 0 ) { // Device has not been opened yet
        strncat(devpath, device, sizeof(device));
        fd = open(devpath, O_RDWR);
        if (fd < 0)
            return enif_make_tuple2(env, priv->atom_error,
                                    enif_make_atom(env, "access_denied"));
    }

    I2cNifRes *i2c_nif_res = enif_alloc_resource(priv->i2c_nif_res_type, sizeof(I2cNifRes));
    strcpy(i2c_nif_res->device, device);
    i2c_nif_res->fd = fd;
    i2c_nif_res->addr = addr;
    add_i2c_nif_res(&priv->i2c_nif_res_list, i2c_nif_res);

    return enif_make_tuple2(env, priv->atom_ok, enif_make_resource(env, i2c_nif_res));
}


static ERL_NIF_TERM i2c_read(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    I2cNifPriv *priv = enif_priv_data(env);
    I2cNifRes *res;
    unsigned long read_len;
    uint8_t read_data[I2C_BUFFER_MAX];
    ErlNifBinary bin_read;

    if (!enif_get_resource(env, argv[0], priv->i2c_nif_res_type, (void **)&res))
        return enif_make_badarg(env);

    if (!is_i2c_nif_res(priv->i2c_nif_res_list, res))
        return enif_make_tuple2(env, priv->atom_error, enif_make_atom(env, "invalid_reference"));

    if (!enif_get_ulong(env, argv[1], &read_len))
        return enif_make_badarg(env);

    if (i2c_transfer(res->fd, res->addr, 0, 0, read_data, read_len)) {
        bin_read.data = read_data;
        bin_read.size = read_len;
        return enif_make_binary(env, &bin_read);
    }
    else
        return enif_make_tuple2(env, priv->atom_error, enif_make_atom(env, "read_failed"));
}


static ERL_NIF_TERM i2c_read_device(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    I2cNifPriv *priv = enif_priv_data(env);
    I2cNifRes *res;
    unsigned addr;
    unsigned long read_len;
    uint8_t read_data[I2C_BUFFER_MAX];
    ErlNifBinary bin_read;

    if (!enif_get_resource(env, argv[0], priv->i2c_nif_res_type, (void **)&res))
        return enif_make_badarg(env);

    if (!is_i2c_nif_res(priv->i2c_nif_res_list, res))
        return enif_make_tuple2(env, priv->atom_error, enif_make_atom(env, "invalid_reference"));

    if (!enif_get_uint(env, argv[1], &addr))
        return enif_make_badarg(env);

    if (!enif_get_ulong(env, argv[2], &read_len))
        return enif_make_badarg(env);

    if (i2c_transfer(res->fd, addr, 0, 0, read_data, read_len)) {
        bin_read.data = read_data;
        bin_read.size = read_len;
        return enif_make_binary(env, &bin_read);
    }
    else
        return enif_make_tuple2(env, priv->atom_error, enif_make_atom(env, "read_failed"));
}


static ERL_NIF_TERM i2c_write(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    I2cNifPriv *priv = enif_priv_data(env);
    I2cNifRes *res;
    ErlNifBinary bin_write;

    if (!enif_get_resource(env, argv[0], priv->i2c_nif_res_type, (void **)&res))
        return enif_make_badarg(env);

    if (!is_i2c_nif_res(priv->i2c_nif_res_list, res))
        return enif_make_tuple2(env, priv->atom_error, enif_make_atom(env, "invalid_reference"));

    if (!enif_inspect_binary(env, argv[1], &bin_write))
        return enif_make_badarg(env);

    if (i2c_transfer(res->fd, res->addr, bin_write.data, bin_write.size, 0, 0)) {
        return priv->atom_ok;
    }
    else
        return enif_make_tuple2(env, priv->atom_error, enif_make_atom(env, "write_failed"));
}


static ERL_NIF_TERM i2c_write_device(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    I2cNifPriv *priv = enif_priv_data(env);
    I2cNifRes *res;
    unsigned addr;
    ErlNifBinary bin_write;

    if (!enif_get_resource(env, argv[0], priv->i2c_nif_res_type, (void **)&res))
        return enif_make_badarg(env);

    if (!is_i2c_nif_res(priv->i2c_nif_res_list, res))
        return enif_make_tuple2(env, priv->atom_error, enif_make_atom(env, "invalid_reference"));

    if (!enif_get_uint(env, argv[1], &addr))
        return enif_make_badarg(env);

    if (!enif_inspect_binary(env, argv[2], &bin_write))
        return enif_make_badarg(env);

    if (i2c_transfer(res->fd, addr, bin_write.data, bin_write.size, 0, 0)) {
        return priv->atom_ok;
    }
    else
        return enif_make_tuple2(env, priv->atom_error, enif_make_atom(env, "write_failed"));
}


static ERL_NIF_TERM i2c_write_read(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    I2cNifPriv *priv = enif_priv_data(env);
    I2cNifRes *res;
    ErlNifBinary bin_write;
    uint8_t read_data[I2C_BUFFER_MAX];
    unsigned long read_len;
    ErlNifBinary bin_read;

    if (!enif_get_resource(env, argv[0], priv->i2c_nif_res_type, (void **)&res))
        return enif_make_badarg(env);

    if (!is_i2c_nif_res(priv->i2c_nif_res_list, res))
        return enif_make_tuple2(env, priv->atom_error, enif_make_atom(env, "invalid_reference"));

    if (!enif_inspect_binary(env, argv[1], &bin_write))
        return enif_make_badarg(env);

    if (!enif_get_ulong(env, argv[2], &read_len))
        return enif_make_badarg(env);

    if (i2c_transfer(res->fd, res->addr, bin_write.data, bin_write.size, read_data, read_len)) {
        bin_read.data = read_data;
        bin_read.size = read_len;
        return enif_make_binary(env, &bin_read);
    }
    else
        return enif_make_tuple2(env, priv->atom_error, enif_make_atom(env, "write_read_failed"));
}


static ERL_NIF_TERM i2c_write_read_device(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    I2cNifPriv *priv = enif_priv_data(env);
    I2cNifRes *res;
    unsigned addr;
    ErlNifBinary bin_write;
    uint8_t read_data[I2C_BUFFER_MAX];
    unsigned long read_len;
    ErlNifBinary bin_read;

    if (!enif_get_resource(env, argv[0], priv->i2c_nif_res_type, (void **)&res))
        return enif_make_badarg(env);

    if (!is_i2c_nif_res(priv->i2c_nif_res_list, res))
        return enif_make_tuple2(env, priv->atom_error, enif_make_atom(env, "invalid_reference"));

    if (!enif_get_uint(env, argv[1], &addr))
        return enif_make_badarg(env);

    if (!enif_inspect_binary(env, argv[2], &bin_write))
        return enif_make_badarg(env);

    if (!enif_get_ulong(env, argv[3], &read_len))
        return enif_make_badarg(env);

    if (i2c_transfer(res->fd, addr, bin_write.data, bin_write.size, read_data, read_len)) {
        bin_read.data = read_data;
        bin_read.size = read_len;
        return enif_make_binary(env, &bin_read);
    }
    else
        return enif_make_tuple2(env, priv->atom_error, enif_make_atom(env, "write_read_failed"));
}


static ERL_NIF_TERM i2c_close(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    I2cNifPriv *priv = enif_priv_data(env);
    I2cNifRes *res;

    if (!enif_get_resource(env, argv[0], priv->i2c_nif_res_type, (void **)&res))
        return enif_make_badarg(env);

    if (!is_i2c_nif_res(priv->i2c_nif_res_list, res))
        return enif_make_tuple2(env, priv->atom_error, enif_make_atom(env, "invalid_reference"));

    del_i2c_nif_res(&priv->i2c_nif_res_list, res);

    enif_release_resource(res);

    return priv->atom_ok;
}


static ErlNifFunc nif_funcs[] =
{
    {"open", 2, i2c_open, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"read", 2, i2c_read, 0},
    {"read_device", 3, i2c_read_device, 0},
    {"write", 2, i2c_write, 0},
    {"write_device", 3, i2c_write_device, 0},
    {"write_read", 3, i2c_write_read, 0},
    {"write_read_device", 4, i2c_write_read_device, 0},
    {"close", 1, i2c_close, 0}
};

ERL_NIF_INIT(Elixir.ElixirCircuits.I2C.Nif, nif_funcs, i2c_load, NULL, NULL, i2c_unload)
