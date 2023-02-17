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
#include <errno.h>
#include <string.h>

// I2C NIF Resource.
struct I2cNifRes {
    int fd;
};

// I2C NIF Private data
struct I2cNifPriv {
    ErlNifResourceType *i2c_nif_res_type;
};

static ERL_NIF_TERM atom_ok;
static ERL_NIF_TERM atom_error;
static ERL_NIF_TERM atom_nak;

static void i2c_dtor(ErlNifEnv *env, void *obj)
{
    struct I2cNifRes *res = (struct I2cNifRes *) obj;

    debug("i2c_dtor");
    if (res->fd >= 0) {
        hal_i2c_close(res->fd);
        res->fd = -1;
    }
}

static int i2c_load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM info)
{
#ifdef DEBUG
#ifdef LOG_PATH
    log_location = fopen(LOG_PATH, "w");
#endif
#endif
    debug("i2c_load");

    struct I2cNifPriv *priv = enif_alloc(sizeof(struct I2cNifPriv));
    if (!priv) {
        error("Can't allocate i2c priv");
        return 1;
    }

    priv->i2c_nif_res_type = enif_open_resource_type(env, NULL, "i2c_nif_res_type", i2c_dtor, ERL_NIF_RT_CREATE, NULL);
    if (priv->i2c_nif_res_type == NULL) {
        error("open I2C NIF resource type failed");
        return 1;
    }

    atom_ok = enif_make_atom(env, "ok");
    atom_error = enif_make_atom(env, "error");
    atom_nak = enif_make_atom(env, "i2c_nak");

    *priv_data = priv;
    return 0;
}

static void i2c_unload(ErlNifEnv *env, void *priv_data)
{
    debug("i2c_unload");
    struct I2cNifPriv *priv = enif_priv_data(env);

    enif_free(priv);
}

static ERL_NIF_TERM enif_make_errno_error(ErlNifEnv *env)
{
    ERL_NIF_TERM reason;
    switch (errno) {
#ifdef EREMOTEIO
    case EREMOTEIO:
        // Remote I/O errors are I2C naks
        reason = atom_nak;
        break;
#endif
    case ENOENT:
        reason = enif_make_atom(env, "bus_not_found");
        break;

    default:
        // strerror isn't usually that helpful, so if these
        // errors happen, please report or update this code
        // to provide a better reason.
        reason = enif_make_atom(env, strerror(errno));
        break;
    }

    return enif_make_tuple2(env, atom_error, reason);
}

static ERL_NIF_TERM i2c_open(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct I2cNifPriv *priv = enif_priv_data(env);
    char device[16];

    if (!enif_get_string(env, argv[0], device, sizeof(device), ERL_NIF_LATIN1))
        return enif_make_badarg(env);

    int fd = hal_i2c_open(device);
    if (fd < 0)
        return enif_make_errno_error(env);

    struct I2cNifRes *i2c_nif_res = enif_alloc_resource(priv->i2c_nif_res_type, sizeof(struct I2cNifRes));
    i2c_nif_res->fd = fd;
    ERL_NIF_TERM res_term = enif_make_resource(env, i2c_nif_res);

    // Elixir side owns the resource. Safe for NIF side to release it.
    enif_release_resource(i2c_nif_res);

    return enif_make_tuple2(env, atom_ok, res_term);
}

static ERL_NIF_TERM i2c_read(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct I2cNifPriv *priv = enif_priv_data(env);
    struct I2cNifRes *res;
    unsigned int addr;
    unsigned long read_len;
    ERL_NIF_TERM bin_read;
    unsigned char *raw_bin_read;


    if (!enif_get_resource(env, argv[0], priv->i2c_nif_res_type, (void **)&res))
        return enif_make_badarg(env);

    if (!enif_get_uint(env, argv[1], &addr))
        return enif_make_badarg(env);

    if (!enif_get_ulong(env, argv[2], &read_len))
        return enif_make_badarg(env);

    raw_bin_read = enif_make_new_binary(env, read_len, &bin_read);

    if (!raw_bin_read)
        return enif_make_tuple2(env, atom_error, enif_make_atom(env, "alloc_failed"));

    if (hal_i2c_transfer(res->fd, addr, 0, 0, raw_bin_read, read_len) >= 0) {
        return enif_make_tuple2(env, atom_ok, bin_read);

    }
    else
        return enif_make_errno_error(env);
}

static ERL_NIF_TERM i2c_write(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct I2cNifPriv *priv = enif_priv_data(env);
    struct I2cNifRes *res;
    unsigned int addr;
    ErlNifBinary bin_write;

    if (!enif_get_resource(env, argv[0], priv->i2c_nif_res_type, (void **)&res))
        return enif_make_badarg(env);

    if (!enif_get_uint(env, argv[1], &addr))
        return enif_make_badarg(env);

    if (!enif_inspect_binary(env, argv[2], &bin_write))
        return enif_make_badarg(env);

    if (hal_i2c_transfer(res->fd, addr, bin_write.data, bin_write.size, 0, 0) >= 0)
        return atom_ok;
    else
        return enif_make_errno_error(env);
}

static ERL_NIF_TERM i2c_write_read(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct I2cNifPriv *priv = enif_priv_data(env);
    struct I2cNifRes *res;
    unsigned int addr;
    ErlNifBinary bin_write;
    unsigned long read_len;
    ERL_NIF_TERM bin_read;
    unsigned char *raw_bin_read;

    if (!enif_get_resource(env, argv[0], priv->i2c_nif_res_type, (void **)&res))
        return enif_make_badarg(env);

    if (!enif_get_uint(env, argv[1], &addr))
        return enif_make_badarg(env);

    if (!enif_inspect_binary(env, argv[2], &bin_write))
        return enif_make_badarg(env);

    if (!enif_get_ulong(env, argv[3], &read_len))
        return enif_make_badarg(env);

    raw_bin_read = enif_make_new_binary(env, read_len, &bin_read);

    if (!raw_bin_read)
        return enif_make_tuple2(env, atom_error, enif_make_atom(env, "alloc_failed"));

    if (hal_i2c_transfer(res->fd, addr, bin_write.data, bin_write.size, raw_bin_read, read_len) >= 0) {
        return enif_make_tuple2(env, atom_ok, bin_read);
    }
    else
        return enif_make_errno_error(env);
}

static ERL_NIF_TERM i2c_close(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    struct I2cNifPriv *priv = enif_priv_data(env);
    struct I2cNifRes *res;

    if (!enif_get_resource(env, argv[0], priv->i2c_nif_res_type, (void **)&res))
        return enif_make_badarg(env);

    if (res->fd >= 0) {
        hal_i2c_close(res->fd);
        res->fd = -1;
    }

    return atom_ok;
}

static ERL_NIF_TERM i2c_info(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    return hal_info(env);
}

static ErlNifFunc nif_funcs[] =
{
    {"open", 1, i2c_open, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"read", 3, i2c_read, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"write", 3, i2c_write, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"write_read", 4, i2c_write_read, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"close", 1, i2c_close, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"info", 0, i2c_info, 0}
};

ERL_NIF_INIT(Elixir.Circuits.I2C.Nif, nif_funcs, i2c_load, NULL, NULL, i2c_unload)
