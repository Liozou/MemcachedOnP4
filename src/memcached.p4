
#include "types.p4"

control MemcachedControl(inout headers headers,
                inout user_metadata_t user_metadata,
                inout digest_data_t digest_data,
                inout sume_metadata_t sume_metadata) {

    action   set_isRequest() { user_data.isRequest = true; }
    action unset_isRequest() { user_data.isRequest = false; }

    table memcached_magic {
        key = { headers.memcached.magic: exact; }
        actions = { set_isRequest; unset_isRequest; drop; }
        default_action = drop;
        const entries = {
            0x80 :   set_isRequest;
            0x81 : unset_isRequest;
        }
    }


    action handle_set() {
        if (user_data.isRequest) {
            MemcachedSet.apply(headers, user_metadata, digest_data, sume_metadata);
        }
    }


    table memcached_opcode {
        key = { headers.memcached.opcode: exact; }
        actions = {
            handle_get;
            handle_set;
            handle_delete;
            drop;
        }
        default_action = drop;
        const_entries = {
            0x00 : handle_get;
            0x01 : handle_set;
            0x04 : handle_delete;
        }
    }

    apply {
        memcached_magic.apply();
        memcached_keyvalue.apply();
        memcached_opcode.apply();
    }

}
