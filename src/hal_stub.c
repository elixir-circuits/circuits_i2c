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
#include <string.h>
#include <errno.h>

static int i2c_test_0_open_count = 0;
static int i2c_test_1_open_count = 0;

ERL_NIF_TERM hal_info(ErlNifEnv *env)
{
    ERL_NIF_TERM info = enif_make_new_map(env);
    enif_make_map_put(env, info, enif_make_atom(env, "name"), enif_make_atom(env, "stub"), &info);
    enif_make_map_put(env, info, enif_make_atom(env, "i2c_test_0_open"), enif_make_int(env, i2c_test_0_open_count), &info);
    enif_make_map_put(env, info, enif_make_atom(env, "i2c_test_1_open"), enif_make_int(env, i2c_test_1_open_count), &info);
    return info;
}

int hal_i2c_open(const char *device)
{
    if (strcmp(device, "i2c-test-0") == 0) {
        i2c_test_0_open_count++;
        debug("stub open 0 (0 count=%d)", i2c_test_0_open_count);
        return 0;
    } else if (strcmp(device, "i2c-test-1") == 0) {
        i2c_test_1_open_count++;
        debug("stub open 1 (1 count=%d)", i2c_test_1_open_count);
        return 1;
    } else {
        errno = ENOENT;
        return -1;
    }
}

void hal_i2c_close(int fd)
{
    if (fd == 0)
        i2c_test_0_open_count--;
    if (fd == 1)
        i2c_test_1_open_count--;
    debug("stub close %d (0 count=%d, 1 count=%d)", fd, i2c_test_0_open_count, i2c_test_1_open_count);
}

int hal_i2c_transfer(int fd,
                     unsigned int addr,
                     const uint8_t *to_write, size_t to_write_len,
                     uint8_t *to_read, size_t to_read_len)
{
    debug("transfer fd=%d, addr=0x%0x", fd, addr);
    if (fd == 0 && i2c_test_0_open_count > 0 && addr == 0x10) {
        // Address 0x10 exists on "i2c-test-0"
        if (to_read_len > 0)
            memset(to_read, 0, to_read_len);

        return 0;
    }
    else if (fd == 1 && i2c_test_1_open_count > 0 && addr == 0x20) {
        // Address 0x20 exists on "i2c-test-1"
        if (to_read_len > 0)
            memset(to_read, 0, to_read_len);
        return 0;
    }

    return -1;
}
