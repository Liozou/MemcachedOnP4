#include "generated_macros.p4"

#define _REPEAT_0(macro) macro(1,null)
#define _REPEAT_1(macro) macro(2,1) _REPEAT_0(macro)
#define _REPEAT_2(macro) macro(4,2) _REPEAT_1(macro)
#define _REPEAT_3(macro) macro(8,4) _REPEAT_2(macro)
#define _REPEAT_4(macro) macro(16,8) _REPEAT_3(macro)
#define _REPEAT_5(macro) macro(32,16) _REPEAT_4(macro)
#define _REPEAT_6(macro) macro(64,32) _REPEAT_5(macro)
#define _REPEAT_7(macro) macro(128,64) _REPEAT_6(macro)
#define _REPEAT_8(macro) macro(256,128) _REPEAT_7(macro)
#define _REPEAT_9(macro) macro(512,256) _REPEAT_8(macro)
#define _REPEAT_10(macro) macro(1024,512) _REPEAT_9(macro)
#define _REPEAT_11(macro) macro(2048,1024) _REPEAT_10(macro)

#define _REPEAT_KEY(macro) _REPEAT_8(macro)
#define _REPEAT_VALUE(macro) _REPEAT_11(macro)


#define PARSE_KEY_TOP parse_key_256
#define PARSE_VALUE_TOP parse_value_2048


#define _MAKE_KEY_T(n, next) header key_##n##_t { bit<n> key; }
#define MAKE_KEY_T _REPEAT_KEY(_MAKE_KEY_T)
#define _MAKE_VALUE_T(n, next) header value_##n##_t { bit<n> value; }
#define MAKE_VALUE_T _REPEAT_VALUE(_MAKE_VALUE_T)


#define _MAKE_STRUCT_KEYS(n, next) key_##n##_t key_##n;
#define MAKE_STRUCT_KEYS _REPEAT_KEY(_MAKE_STRUCT_KEYS)
#define _MAKE_STRUCT_VALUES(n, next) value_##n##_t value_##n;
#define MAKE_STRUCT_VALUES _REPEAT_VALUE(_MAKE_STRUCT_VALUES)

/*
#define _PARSE_EXTRACT_KEY(n, next)   \
    state parse_extract_key_##n {     \
        buffer.extract(hdr.key_##n);  \
        user_metadata.key = ((bit<(384-n)>)user_metadata.key) ++ hdr.key_##n.key; \
        transition parse_key_##next;  \
    }

#define _PARSE_KEY(n, next)                                \
    state parse_key_##n {                                  \
        transition select(hdr.memcached.key_length[n:n]) { \
            1 : parse_extract_key_##n;                     \
            _ : parse_key_##next;                          \
        }                                                  \
    }

#define PARSE_KEY                                        \
    state parse_key_null { transition PARSE_VALUE_TOP; } \
    _REPEAT_KEY(_PARSE_EXTRACT_KEY)                      \
    _REPEAT_KEY(_PARSE_KEY)


#define _PARSE_EXTRACT_VALUE(n, next)   \
    state parse_extract_value_##n {     \
        buffer.extract(hdr.value_##n);  \
        transition parse_value_##next;  \
    }

#define _PARSE_VALUE(n, next)                              \
    state parse_value_##n {                                \
        transition select(user_metadata.value_size[n:n]) { \
            1 : parse_extract_value_##n;                   \
            _ : parse_value_##next;                        \
        }                                                  \
    }

#define PARSE_VALUE                               \
    state parse_value_null { transition accept; } \
    _REPEAT_VALUE(_PARSE_EXTRACT_VALUE)           \
    _REPEAT_VALUE(_PARSE_VALUE)
*/

#define PARSE_KEY                                        \
    state parse_key_null { transition PARSE_VALUE_TOP; } \
    _PARSE_KEY

#define PARSE_VALUE                               \
    state parse_value_null { transition accept; } \
    _PARSE_VALUE

// _PARSE_VALUE and _PARSE_KEY are defined in generated_macros.p4

#define _DEPARSE_KEY(n, next) packet.emit(hdr.key_##n);
#define DEPARSE_KEY _REPEAT_KEY(_DEPARSE_KEY)
#define _DEPARSE_VALUE(n, next) packet.emit(hdr.value_##n);
#define DEPARSE_VALUE _REPEAT_VALUE(_DEPARSE_VALUE)


#define OP_IS_GET (hdr.memcached.opcode==0x00)
#define OP_IS_SET (hdr.memcached.opcode==0x01)
#define OP_IS_DELETE (hdr.memcached.opcode==0x04)
