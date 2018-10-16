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
 */

#include "i2c_nif.h"

// Handle a linked list of I2C NIF Resources

// Delete the given I2C NIF Resource from the list of resources
void del_i2c_nif_res(I2cNifResList **head, I2cNifRes *del_res)
{
    I2cNifResList *prev_entry = NULL;
    I2cNifResList *curr_entry = *head;

    while(curr_entry != NULL){
        if (curr_entry->res == del_res){
            if (prev_entry == NULL)
                *head = curr_entry->next;
            else
                prev_entry->next = curr_entry->next;

            enif_free(curr_entry);
            return;
        }
        prev_entry = curr_entry;
        curr_entry = curr_entry->next;
    }
}

// Add the given I2C NIF Resource to the list of resources
void add_i2c_nif_res(I2cNifResList **head, I2cNifRes *add_res)
{
    I2cNifResList *new_entry = enif_alloc(sizeof(I2cNifResList));
    new_entry->res = add_res;
    new_entry->next = *head;
    *head = new_entry;
}

// Check if the given I2C NIF Resource exists in the list of resources
int is_i2c_nif_res(I2cNifResList *head, I2cNifRes *chk_res)
{
    I2cNifResList *curr_entry = head;

    while(curr_entry != NULL){
        if (curr_entry->res == chk_res)
            return 1;

        curr_entry = curr_entry->next;
    }
    return 0;  // resource is not in list
}

// Get the fd of the first I2C NIF Resource, that matches the given device name
// Return zero if no resource has opened the device, yet
int get_i2c_res_fd(I2cNifResList *head, const char *device)
{
    I2cNifResList *curr_entry = head;

    while(curr_entry != NULL){
        if (strcmp(curr_entry->res->device, device) == 0)
            return curr_entry->res->fd;

        curr_entry = curr_entry->next;
    }
    return 0;  // device not open yet
}


