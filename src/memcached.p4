#include "xilinx_core.p4"

#define REG_READ 8w0
#define REG_WRITE 8w1

@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(0)
extern void slab64_reg_dataRW(in regAddr64 index,
                           in bit<96> newVal,
                           in bit<8> opCode,
                           out bit<96> result);

@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(0)
extern void slab128_reg_dataRW(in regAddr128 index,
                           in bit<160> newVal,
                           in bit<8> opCode,
                           out bit<160> result);

@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(0)
extern void slab256_reg_dataRW(in regAddr256 index,
                           in bit<280> newVal,
                           in bit<8> opCode,
                           out bit<280> result);

control MemcachedControl(inout headers hdr,
                inout user_metadata_t user_metadata,
                inout digest_data_t digest_data,
                inout sume_metadata_t sume_metadata) {

    /* memcached_keyvalue: takes the key and returns a pointer to the value
     * (ie the value size to get the slab and the register address) and the
     * flags.
     * The values are not directly stored in the tables because of their size.
     */

    action set_stored_info(regAddr_t reg_addr, bit<5> value_size) {
        user_metadata.reg_addr = reg_addr;
        user_metadata.value_size_out = value_size;
    }
    table memcached_keyvalue {
        key = { user_metadata.key: exact; }
        actions = { set_stored_info; }
        size = 448;
    }

    /* register_address : takes a slabID as key and returns an available
     * register address for the corresponding slab.
     * Note that the address overwrites that set by memcached_keyvalue.
     */

    action set_register_address(regAddr_t reg_addr) {
        user_metadata.reg_addr = reg_addr;
    }

    bit<12> slabID;
    table register_address {
        key = { slabID: exact; }
        actions = { set_register_address; }
        size = 64;
    }


    apply {

        if (user_metadata.value_size > 31 || hdr.memcached.key_length > 7) {
            return;
        }

        bool is_stored_key = memcached_keyvalue.apply().hit;

        bool do_reg_operation = OP_IS_GET && is_stored_key;

        bit<8> reg_opcode = REG_READ;

        if (user_metadata.isRequest ? OP_IS_SET : OP_IS_GETK) {

            do_reg_operation = (hdr.memcached.vbucket_id == 0);
            /* If OP_IS_SET, this is just a sanity check since we only handle a
             * single bucket
             * If OP_IS_GETK, this ensures that the server had the key-value
             * pair and no error happened there.
             */

            bit<5> x_value_size_in = user_metadata.value_size[4:0];
            x_value_size_in = x_value_size_in | (x_value_size_in >> 1);
            x_value_size_in = x_value_size_in | (x_value_size_in >> 2);
            x_value_size_in[0:0] = x_value_size_in[0:0] | x_value_size_in[1:1];
            bit<5> x_value_size_out = user_metadata.value_size_out;
            x_value_size_out = x_value_size_out | (x_value_size_out >> 1);
            x_value_size_out = x_value_size_out | (x_value_size_out >> 2);
            x_value_size_out[0:0] = x_value_size_out[0:0] | x_value_size_out[1:1];

            user_metadata.value_size_out = user_metadata.value_size[4:0];
            reg_opcode = REG_WRITE;
            if (x_value_size_in != x_value_size_out) {
                /* This will be executed either if memcached_keyvalue was a miss
                 * (because then value_size_out = 0) or if it was a hit but the
                 * stored value is not in the same slab as the new value.
                 * Indeed, x_value_size_in == x_value_size_out if and only if
                 * value_size_out and value_size have the same highest set bit.
                 */

                if (user_metadata.value_size_out <= 8) { slabID = 1; }
                else if (user_metadata.value_size_out <= 16) { slabID = 2; }
                else { slabID = 3; }

                register_address.apply();
                digest_data.store_new_key = 1;
                digest_data.remove_this_key = (bit<1>)is_stored_key;
            }

            if (!user_metadata.isRequest) { // i.e. opcode is GETK
                hdr.memcached.opcode = 0x00;
                hdr.memcached.total_body = hdr.memcached.total_body - (bit<32>) hdr.memcached.key_length;
                hdr.memcached.key_length = 0;
                UNSET_KEY
                /* Past this point, OP_IS_GETK merges with OP_IS_GET if the
                 * packet is a response.
                 * The only difference is that if the packet used to be
                 * OP_IS_GETK, the new key-value will be added to the store
                 */
            }

        }

        if (do_reg_operation) {
            /* slab##n##_reg_dataRW corresponds to the slab for values of size
             * at most n bits.
             * The last slab has size 248, which corresponds to the maximum
             * size that can be stored by filling headers 8, 16, 32, 64, 128.
             * Recall that value_size_out is expressed in bytes. Since
             * 248 bits = 31 bytes, value_size_out can only take values
             * between 1 and 31, hence it can be stored on 5 bits.
             */

            if (user_metadata.value_size_out <= 8) {
                slab64_reg_dataRW((regAddr64)user_metadata.reg_addr, ((bit<64>)user_metadata.value)++hdr.extras_flags.flags, reg_opcode, user_metadata.value[95:0]);
            } else if (user_metadata.value_size_out <= 16) {
                slab128_reg_dataRW((regAddr128)user_metadata.reg_addr, ((bit<128>)user_metadata.value)++hdr.extras_flags.flags, reg_opcode, user_metadata.value[159:0]);
            } else {
                slab256_reg_dataRW((regAddr256)user_metadata.reg_addr, ((bit<248>)user_metadata.value)++hdr.extras_flags.flags, reg_opcode, user_metadata.value);
            }

        }

        digest_data.magic = hdr.memcached.magic;
        digest_data.opcode = hdr.memcached.opcode;

        if (user_metadata.isRequest && OP_IS_GET) {
            if (is_stored_key) {
                hdr.extras_flags.setValid();
                hdr.extras_flags.flags = user_metadata.value[31:0];
                user_metadata.value[INTERNAL_VALUE_SIZE-33:0] = user_metadata.value[INTERNAL_VALUE_SIZE-1:32];

                REPOPULATE_VALUE
                UNSET_KEY


                hdr.memcached.total_body = (bit<32>)user_metadata.value_size_out + 4;
                bit<16> size_diff = (bit<16>)user_metadata.value_size_out + 4 - hdr.memcached.key_length;
                hdr.ipv4.totalLen = hdr.ipv4.totalLen + size_diff;
                hdr.udp.udpLength = hdr.udp.udpLength + size_diff;
                sume_metadata.pkt_len = sume_metadata.pkt_len + size_diff;

                hdr.memcached.key_length = 0;
                hdr.memcached.extras_length = 4;
                hdr.memcached.magic = 0x81; // Returning a response packet
                hdr.memcached.vbucket_id = 0; // No error

                sume_metadata.dst_port = sume_metadata.src_port;
                bit<48> tmpEth = hdr.ethernet.dstAddr;
                hdr.ethernet.dstAddr = hdr.ethernet.srcAddr;
                hdr.ethernet.srcAddr = tmpEth;
                bit<32> tmpIP = hdr.ipv4.dstAddr;
                hdr.ipv4.dstAddr = hdr.ipv4.srcAddr;
                hdr.ipv4.srcAddr = tmpIP;
                hdr.ipv4.ttl = 0x40; // Creating a new packet so setting up a new TTL.
            } else {
                hdr.memcached.opcode = 0x0c; // GETK
            }
        }

        sume_metadata.send_dig_to_cpu = 1;

        /* The next values are copied back from user_metadata instead of being
         * directly modified on the digest because it leads to better timing
         * performance */
        digest_data.key = user_metadata.key;
        digest_data.value_size_out = user_metadata.value_size_out;
        digest_data.reg_addr = user_metadata.reg_addr;

        hdr.udp.checksum = 0; // We do not support udp checksum computation.
    }

}
