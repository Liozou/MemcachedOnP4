
control MemcachedControl(inout headers hdr,
                inout user_metadata_t user_metadata,
                inout digest_data_t digest_data,
                inout sume_metadata_t sume_metadata) {

    action   set_isRequest() { user_metadata.isRequest = true; }
    action unset_isRequest() { user_metadata.isRequest = false; }

    action drop() { sume_metadata.dst_port = 0; }

    table memcached_magic {
        key = { hdr.memcached.magic: exact; }
        actions = { set_isRequest; unset_isRequest; drop; }
        default_action = drop;
        const entries = {
            0x80 :   set_isRequest();
            0x81 : unset_isRequest();
        }
    }


    action handle_set() {
    }

    action handle_get() {
    }

    action handle_delete() {
    }

    table memcached_opcode {
        key = { hdr.memcached.opcode: exact; }
        actions = {
            handle_get;
            handle_set;
            handle_delete;
            drop;
        }
        default_action = drop;
        const entries = {
            0x00 : handle_get();
            0x01 : handle_set();
            0x04 : handle_delete();
        }
    }

    apply {
        memcached_magic.apply();
        // memcached_keyvalue.apply();
        memcached_opcode.apply();
    }

}
