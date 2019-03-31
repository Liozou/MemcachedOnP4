
// #include "set_key.p4"

#define REG_READ 8w0
#define REG_WRITE 8w1
// @Xilinx_MaxLatency(1)
// @Xilinx_ControlWidth(1)
// extern void slab2047_reg_rw(in regAddr2047 index,
//                             in bit<2047> newVal,
//                             in bit<8> opCode,
//                             out bit<2047> result);

@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(7)
extern void slab128_reg_rw(in regAddr128 index,
                           in bit<128> newVal,
                           in bit<8> opCode,
                           out bit<128> result);

control MemcachedControl(inout headers hdr,
                inout user_metadata_t user_metadata,
                inout digest_data_t digest_data,
                inout sume_metadata_t sume_metadata) {


    /* memcached_keyvalue: takes the key and returns a pointer to the value
     * (ie the value size to get the slab and the register address) and the
     * flags.
     * The values are not directly stored in the tables because of their size.
     */

    action set_stored_info(regAddr_t reg_addr, bit<32> flags, bit<8> value_size) {
        user_metadata.reg_address = reg_addr;
        user_metadata.flags = flags;
        user_metadata.value_size_out = value_size;
    }
    table memcached_keyvalue {
        key = { user_metadata.key: exact; }
        actions = { set_stored_info; }
        size = 2048;
    }

    /* register_address_##n : no argument, returns an available register address
     * for slab n.
     * Note that the address overwrites that set by memcached_keyvalue.
     */

    action set_register_address(regAddr_t reg_addr) {
        user_metadata.reg_address = reg_addr;
    }
    table register_address  { key = { hdr.memcached.data_type: exact; } actions = { set_register_address; } size = 64; }


    apply {
        if (hdr.memcached.key_length > 384) {
            DROP
        }

        if (!user_metadata.isRequest && hdr.memcached.magic != 0x81) {
            DROP
        }

        bool is_stored_key = memcached_keyvalue.apply().hit;

        bool do_reg_operation = (OP_IS_GET || OP_IS_GETK) && is_stored_key;

        bit<8> reg_opcode = REG_READ;

        if ((user_metadata.isRequest && OP_IS_SET) ||
           (!user_metadata.isRequest && OP_IS_GETK)) {

            do_reg_operation = true;
            bit<8> x_value_size_in = (bit<8>) user_metadata.value_size;
            x_value_size_in = x_value_size_in | (x_value_size_in >> 1);
            x_value_size_in = x_value_size_in | (x_value_size_in >> 2);
            x_value_size_in = x_value_size_in | (x_value_size_in >> 4);
            bit<8> x_value_size_out = user_metadata.value_size_out;
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
                user_metadata.value_size_out = (bit<8>)user_metadata.value_size;

                if (user_metadata.value_size <= 16) { hdr.memcached.data_type = 1; }
                /*
                else if (user_metadata.value_size <= 32) { hdr.memcached.data_type = 2; }
                else if (user_metadata.value_size <= 64) { hdr.memcached.data_type = 3; }
                else if (user_metadata.value_size <= 128) { hdr.memcached.data_type = 4; }
                else { hdr.memcached.data_type = 5; }
                */
                register_address.apply();
                hdr.memcached.data_type = 0;
                digest_data.store_new_key = true;
                digest_data.remove_this_key = is_stored_key;
            }

            if (!user_metadata.isRequest && OP_IS_GETK) {
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

            if (user_metadata.value_size_out <= 16) {
                slab128_reg_rw((regAddr128)user_metadata.reg_address, (bit<128>)user_metadata.value, reg_opcode, user_metadata.value[127:0]);
            }

            /*
            else if (user_metadata.value_size_out <= 32) {
                slab256_reg_rw((regAddr256)user_metadata.reg_address, (bit<256>)user_metadata.value, reg_opcode, user_metadata.value[255:0]);
            } else if (user_metadata.value_size_out <= 64) {
                slab512_reg_rw((regAddr512)user_metadata.reg_address, (bit<512>)user_metadata.value, reg_opcode, user_metadata.value[511:0]);
            } else if (user_metadata.value_size_out <= 128) {
                slab1024_reg_rw((regAddr1024)user_metadata.reg_address, (bit<1024>)user_metadata.value, reg_opcode, user_metadata.value[1023:0]);
            } else { // 128 < value_size_out <= 255
                slab2040_reg_rw((regAddr2040)user_metadata.reg_address, user_metadata.value, reg_opcode, user_metadata.value);
            }
            */
        }

        if (user_metadata.isRequest) {

            if (OP_IS_GET || OP_IS_GETK) {
                if (is_stored_key) {
                    REPOPULATE_VALUE
                    // REPOPULATE_VALUE is defined in generated_macros.p4
                    hdr.extras_flags.setValid();
                    hdr.extras_flags.flags = user_metadata.flags;
                    if (OP_IS_GETK) {
                        hdr.memcached.total_body = (bit<32>)((bit<16>)user_metadata.value_size_out + hdr.memcached.key_length + 4);
                    } else {
                        UNSET_KEY
                        hdr.memcached.total_body = (bit<32>)user_metadata.value_size_out + 4;
                    }
                    hdr.memcached.magic = 0x81; // Returning a response packet
                    hdr.memcached.vbucket_id = 0; // No error
                } else {
                    // hdr.memcached.opcode = 0x0c; // GETK
                    // TODO send to the server
                }
            }

        }

    }

}
