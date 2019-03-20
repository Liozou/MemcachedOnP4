#define DO_AND_GOTO_NEXT_0(macro) macro(null,0)
#define DO_AND_GOTO_NEXT_1(macro) DO_AND_GOTO_NEXT_0(macro) macro(0,1)
#define DO_AND_GOTO_NEXT_2(macro) DO_AND_GOTO_NEXT_1(macro) macro(1,2)
#define DO_AND_GOTO_NEXT_3(macro) DO_AND_GOTO_NEXT_2(macro) macro(2,3)
#define DO_AND_GOTO_NEXT_4(macro) DO_AND_GOTO_NEXT_3(macro) macro(3,4)
#define DO_AND_GOTO_NEXT_5(macro) DO_AND_GOTO_NEXT_4(macro) macro(4,5)
#define DO_AND_GOTO_NEXT_6(macro) DO_AND_GOTO_NEXT_5(macro) macro(5,6)
#define DO_AND_GOTO_NEXT_7(macro) DO_AND_GOTO_NEXT_6(macro) macro(6,7)
#define DO_AND_GOTO_NEXT_8(macro) DO_AND_GOTO_NEXT_7(macro) macro(7,8)
#define DO_AND_GOTO_NEXT_9(macro) DO_AND_GOTO_NEXT_8(macro) macro(8,9)
#define DO_AND_GOTO_NEXT_10(macro) DO_AND_GOTO_NEXT_9(macro) macro(9,10)
#define DO_AND_GOTO_NEXT_11(macro) DO_AND_GOTO_NEXT_10(macro) macro(10,11)

#define GOTO_AND_DO_NEXT_0(macro) macro(null,0)
#define GOTO_AND_DO_NEXT_1(macro) macro(0,1) GOTO_AND_DO_NEXT_0(macro)
#define GOTO_AND_DO_NEXT_2(macro) macro(1,2) GOTO_AND_DO_NEXT_1(macro)
#define GOTO_AND_DO_NEXT_3(macro) macro(2,3) GOTO_AND_DO_NEXT_2(macro)
#define GOTO_AND_DO_NEXT_4(macro) macro(3,4) GOTO_AND_DO_NEXT_3(macro)
#define GOTO_AND_DO_NEXT_5(macro) macro(4,5) GOTO_AND_DO_NEXT_4(macro)
#define GOTO_AND_DO_NEXT_6(macro) macro(5,6) GOTO_AND_DO_NEXT_5(macro)
#define GOTO_AND_DO_NEXT_7(macro) macro(6,7) GOTO_AND_DO_NEXT_6(macro)
#define GOTO_AND_DO_NEXT_8(macro) macro(7,8) GOTO_AND_DO_NEXT_7(macro)
#define GOTO_AND_DO_NEXT_9(macro) macro(8,9) GOTO_AND_DO_NEXT_8(macro)
#define GOTO_AND_DO_NEXT_10(macro) macro(9,10) GOTO_AND_DO_NEXT_9(macro)
#define GOTO_AND_DO_NEXT_11(macro) macro(10,11) GOTO_AND_DO_NEXT_10(macro)


#define REPEAT_EXP_0(macro) macro(0,1)
#define REPEAT_EXP_1(macro) macro(1,2) REPEAT_EXP_0(macro)
#define REPEAT_EXP_2(macro) macro(2,4) REPEAT_EXP_1(macro)
#define REPEAT_EXP_3(macro) macro(3,8) REPEAT_EXP_2(macro)
#define REPEAT_EXP_4(macro) macro(4,16) REPEAT_EXP_3(macro)
#define REPEAT_EXP_5(macro) macro(5,32) REPEAT_EXP_4(macro)
#define REPEAT_EXP_6(macro) macro(6,64) REPEAT_EXP_5(macro)
#define REPEAT_EXP_7(macro) macro(7,128) REPEAT_EXP_6(macro)
#define REPEAT_EXP_8(macro) macro(8,256) REPEAT_EXP_7(macro)
#define REPEAT_EXP_9(macro) macro(9,512) REPEAT_EXP_8(macro)
#define REPEAT_EXP_10(macro) macro(10,1024) REPEAT_EXP_9(macro)
#define REPEAT_EXP_11(macro) macro(11,2048) REPEAT_EXP_10(macro)

#define _REPEAT_EXP_KEY(macro) REPEAT_EXP_10(macro)
#define _REPEAT_EXP_VALUE(macro) REPEAT_EXP_11(macro)


#define _REPEAT_KEY(macro) DO_AND_GOTO_NEXT_10(macro)
#define _REPEAT_VALUE(macro) DO_AND_GOTO_NEXT_11(macro)

#define _REPEAT_KEY_ORDER(macro) GOTO_AND_DO_NEXT_10(macro)
#define _REPEAT_VALUE_ORDER(macro) GOTO_AND_DO_NEXT_11(macro)


#define MAKE_VARBIT_KEY(name, val) header key_##name##_t { bit<val> key; }
#define MAKE_KEY_T _REPEAT_KEY(MAKE_VARBIT_KEY)
#define MAKE_VARBIT_VALUE(name, val) header value_##name##_t { bit<val> value; }
#define MAKE_VALUE_T _REPEAT_VALUE(MAKE_VARBIT_VALUE)


#define _MAKE_STRUCT_KEYS(null, n) key_##n##_t key_##n;
#define MAKE_STRUCT_KEYS _REPEAT_KEY(_MAKE_STRUCT_KEYS)
#define _MAKE_STRUCT_VALUES(null, n) value_##n##_t value_##n;
#define MAKE_STRUCT_VALUES _REPEAT_VALUE(_MAKE_STRUCT_VALUES)


#define _PARSE_KEY(next, n)                        \
    state parse_key_##n {                           \
        if(hdr.memcached.key_length[n] == 1) {      \
            buffer.extract(hdr.key_##n);            \
        }                                           \
        transition parse_key_##next;                \
    }
#define PARSE_KEY \
    parse_key_null { transition parse_value_11; } \
    _REPEAT_KEY(_PARSE_KEY)

#define _PARSE_VALUE(next, n)                      \
    state parse_value_##n {                         \
        if(user_metadata.value_size[n] == 1) {      \
            buffer.extract(hdr.value_##n);          \
        }                                           \
        transition parse_value_##next;              \
    }
#define PARSE_VALUE \
    parse_value_null { transition accept; } \
    _REPEAT_VALUE(_PARSE_VALUE)


#define _DEPARSE_KEY(null, n) packet.emit(hdr.key_##n);
#define DEPARSE_KEY _REPEAT_KEY_ORDER(_DEPARSE_KEY)
#define _DEPARSE_VALUE(null, n) packet.emit(hdr.value_##n);
#define DEPARSE_VALUE _REPEAT_VALUE_ORDER(_DEPARSE_VALUE)
