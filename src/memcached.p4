#include "xilinx_core.p4"

#define REG_READ 8w0
#define REG_WRITE 8w1

@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(8)
extern void slab64_reg_rw(in regAddr64 index,
                           in bit<96> newVal,
                           in bit<8> opCode,
                           out bit<96> result);

@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(7)
extern void slab128_reg_rw(in regAddr128 index,
                           in bit<160> newVal,
                           in bit<8> opCode,
                           out bit<160> result);

@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(6)
extern void slab256_reg_rw(in regAddr256 index,
                           in bit<280> newVal,
                           in bit<8> opCode,
                           out bit<280> result);

control MemcachedControl(inout headers hdr,
                inout user_metadata_t user_metadata,
                inout digest_data_t digest_data,
                inout sume_metadata_t sume_metadata) {

    bit<8> value_size_out = 0;
    regAddr_t reg_addr = 0;
    key_t key_local = 0;
    bit<12> slabID = 0;

    /* memcached_keyvalue: takes the key and returns a pointer to the value
     * (ie the value size to get the slab and the register address) and the
     * flags.
     * The values are not directly stored in the tables because of their size.
     */

    action set_stored_info(regAddr_t reg_addr_table, bit<8> value_size_table) {
        reg_addr = reg_addr_table;
        value_size_out = value_size_table;
    }
    table memcached_keyvalue {
        key = { key_local: exact; }
        actions = { set_stored_info; }
        size = 1024;
    }

    /* register_address_##n : no argument, returns an available register address
     * for slab n.
     * Note that the address overwrites that set by memcached_keyvalue.
     */

    action set_register_address(regAddr_t reg_addr_table) {
        reg_addr = reg_addr_table;
    }
    table register_address  { key = { slabID: exact; } actions = { set_register_address; } size=64; }


    apply {

        if (user_metadata.value_size_in > 31) {
            DROP
        }
        if (hdr.memcached.key_length > 120) {
            DROP
        }

        bool isRequest = (hdr.memcached.magic == 0x80);

        if (!isRequest && hdr.memcached.magic != 0x81) {
            DROP
        }

        bit<8> value_size = user_metadata.value_size_in[7:0];
        value_t value = 0;

        POPULATE_KEY

        POPULATE_VALUE

        bool is_stored_key = memcached_keyvalue.apply().hit;

        bool do_reg_operation = (OP_IS_GET || OP_IS_GETK) && is_stored_key;

        bit<8> reg_opcode = REG_READ;

        if ((isRequest && OP_IS_SET) ||
           (!isRequest && OP_IS_GETK)) {

            do_reg_operation = true;
            bit<8> x_value_size_in = (bit<8>) value_size;
            x_value_size_in = x_value_size_in | (x_value_size_in >> 1);
            x_value_size_in = x_value_size_in | (x_value_size_in >> 2);
            x_value_size_in = x_value_size_in | (x_value_size_in >> 4);
            bit<8> x_value_size_out = value_size_out;
            x_value_size_out = x_value_size_out | (x_value_size_out >> 1);
            x_value_size_out = x_value_size_out | (x_value_size_out >> 2);
            x_value_size_out = x_value_size_out | (x_value_size_out >> 4);

            reg_opcode = REG_WRITE;
            if (x_value_size_in != x_value_size_out) {
                /* This will be executed either if memcached_keyvalue was a miss
                 * (because then value_size_out = 0) or if it was a hit but the
                 * stored value is not in the same slab as the new value.
                 * Indeed, _value_size_in == _value_size_out if and only if
                 * value_size_out and value_size have the same highest set bit.
                 */
                value_size_out = (bit<8>)value_size;

                if (value_size <= 8) { slabID = 1; }
                else if (value_size <= 16) { slabID = 2; }
                else if (value_size <= 32) { slabID = 3; }
                register_address.apply();
                digest_data.store_new_key = true;
                digest_data.remove_this_key = is_stored_key;
            }

            if (!isRequest && OP_IS_GETK) {
                hdr.memcached.opcode = 0x00; // Seems authorized by BinaryProtocolRevamped even for GETK
                // Past this point, OP_IS_GETK merges with OP_IS_GET if the packet is a response
            }

        }

        if (do_reg_operation) {
            /* slab##n##_reg_rw corresponds to the slab for values of size
             * at most n bits.
             * The last slab has size 2040, which corresponds to the maximum
             * size that can be stored by filling headers 8, 16, 32, 64,
             * 128, 256, 512 and 1024.
             * Recall that value_size_out is expressed in bytes. Since
             * 2040 bits = 255 bytes, value_size_out can only take values
             * between 1 and 255, hence it is stored on 8 bits.
             */

            if (value_size_out <= 8) {
                slab64_reg_rw((regAddr64)reg_addr, ((bit<64>)value)++hdr.extras_flags.flags, reg_opcode, value[95:0]);
            } else if (value_size_out <= 16) {
                slab128_reg_rw((regAddr128)reg_addr, ((bit<128>)value)++hdr.extras_flags.flags, reg_opcode, value[159:0]);
            } else if (value_size_out <= 32) {
                slab256_reg_rw((regAddr256)reg_addr, ((bit<248>)value)++hdr.extras_flags.flags, reg_opcode, value);
            }
        }

        if (isRequest) {

            if (OP_IS_GET || OP_IS_GETK) {
                if (is_stored_key) {
                    hdr.extras_flags.setValid();
                    hdr.extras_flags.flags = value[31:0];
                    value[INTERNAL_VALUE_SIZE-33:0] = value[INTERNAL_VALUE_SIZE-1:32];
                    REPOPULATE_VALUE
                    if (OP_IS_GETK) {
                        hdr.memcached.total_body = (bit<32>)((bit<16>)value_size_out + hdr.memcached.key_length + 4);
                    } else {
                        UNSET_KEY
                        hdr.memcached.total_body = (bit<32>)value_size_out + 4;
                    }
                    hdr.memcached.magic = 0x81; // Returning a response packet
                    hdr.memcached.vbucket_id = 0; // No error
                } else {
                    // hdr.memcached.opcode = 0x0c; // GETK
                    // TODO send to the server
                }
            }

        }

        sume_metadata.send_dig_to_cpu = 1;
        digest_data.fuzz = 0xcafe;
        digest_data.magic = hdr.memcached.magic;
        digest_data.opcode = hdr.memcached.opcode;
        digest_data.key = key_local;
        digest_data.value_size_out = value_size_out;
        digest_data.reg_addr = reg_addr;

    }

}
