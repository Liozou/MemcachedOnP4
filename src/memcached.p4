
#include "set_key.p4"

#define REG_READ 8w0
#define REG_WRITE 8w1
@Xilinx_MaxLatency(1)
@Xilinx_ControlWidth(4)
extern void slab2048_reg_rw(in regAddr2048 index,
                            in bit<2048> newVal,
                            in bit<8> opCode,
                            out bit<2048> result);

control MemcachedControl(inout headers hdr,
                inout user_metadata_t user_metadata,
                inout digest_data_t digest_data,
                inout sume_metadata_t sume_metadata) {


    action drop() { sume_metadata.dst_port = 0; }


    action set_register_address(slabId_t sID, regAddr_t reg_addr) {
        user_metadata.slabID = sID;
        user_metadata.reg_address = reg_addr;
    }
    table memcached_keyvalue {
        key = { user_metadata.key: exact; }
        actions = { set_register_address; }
    }


    apply {
        if (hdr.memcached.key_length > 384) {
            drop();
        }
        user_metadata.isRequest = (hdr.memcached.magic == 0x80);
        if (!user_metadata.isRequest && hdr.memcached.magic != 0x81) {
            drop();
        }

        SetKey.apply(hdr, user_metadata);

        if (memcached_keyvalue.apply().hit) {
            bit<8> opCode = 2; // This value should be before use or it will error
            bool do_reg_operation = false;
            if (OP_IS_GET) {
                do_reg_operation = true;
                opCode = REG_READ;
            } else if (OP_IS_SET) {
                do_reg_operation = true;
                opCode = REG_WRITE;
            }

            if (do_reg_operation) {
                if (user_metadata.slabID == 7) {
                    hdr.value_11.setValid(); // TODO change
                    slab2048_reg_rw((regAddr2048)user_metadata.reg_address, hdr.value_11.value, opCode, hdr.value_11.value);
                }
            }

            hdr.memcached.magic = 0x81; // Returning a response packet
            hdr.memcached.vbucket_id = 0; // No error

        } else { // If miss

        }

    }

}
