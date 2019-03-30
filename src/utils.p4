#include "generated_macros.p4"

/* The following commented macros are defined in generated_macros.p4 */

// #define _REPEAT_KEY(macro) _REPEAT_8(macro)
// #define _REPEAT_VALUE(macro) _REPEAT_10(macro)
// #define PARSE_KEY_TOP parse_key_256
// #define PARSE_VALUE_TOP parse_value_1024
// #define INTERNAL_KEY_SIZE 384
// #define INTERNAL_VALUE_SIZE 2040
// #define _PARSE_VALUE
// #define _PARSE_KEY


#define _MAKE_KEY_T(n, next) header key_##n##_t { bit<n> key; }
#define MAKE_KEY_T _REPEAT_KEY(_MAKE_KEY_T)
#define _MAKE_VALUE_T(n, next) header value_##n##_t { bit<n> value; }
#define MAKE_VALUE_T _REPEAT_VALUE(_MAKE_VALUE_T)


#define _MAKE_STRUCT_KEYS(n, next) key_##n##_t key_##n;
#define MAKE_STRUCT_KEYS _REPEAT_KEY(_MAKE_STRUCT_KEYS)
#define _MAKE_STRUCT_VALUES(n, next) value_##n##_t value_##n;
#define MAKE_STRUCT_VALUES _REPEAT_VALUE(_MAKE_STRUCT_VALUES)


#define PARSE_KEY                                        \
    state parse_key_null { transition PARSE_VALUE_TOP; } \
    _PARSE_KEY

#define PARSE_VALUE                               \
    state parse_value_null { transition accept; } \
    _PARSE_VALUE


#define _UNSET_KEY(n, next) hdr.key_##n.setInvalid();
#define UNSET_KEY _REPEAT_KEY(_UNSET_KEY)

#define _DEPARSE_KEY(n, next) packet.emit(hdr.key_##n);
#define DEPARSE_KEY _REPEAT_KEY(_DEPARSE_KEY)
#define _DEPARSE_VALUE(n, next) packet.emit(hdr.value_##n);
#define DEPARSE_VALUE _REPEAT_VALUE(_DEPARSE_VALUE)


#define DROP {sume_metadata.dst_port = 0; return;}


#define INDEX_WIDTH_SLAB_128 7
#define INDEX_WIDTH_SLAB_256 6
#define INDEX_WIDTH_SLAB_512 5
#define INDEX_WIDTH_SLAB_1024 4
#define INDEX_WIDTH_SLAB_2040 3

#define OP_IS_GET (hdr.memcached.opcode==0x00)
#define OP_IS_SET (hdr.memcached.opcode==0x01)
#define OP_IS_GETK (hdr.memcached.opcode==0x0c)
#define OP_IS_DELETE (hdr.memcached.opcode==0x04)
