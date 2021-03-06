#define _REPEAT_3(macro) macro(8,null)
#define _REPEAT_4(macro) macro(16,8) _REPEAT_3(macro)
#define _REPEAT_5(macro) macro(32,16) _REPEAT_4(macro)
#define _REPEAT_6(macro) macro(64,32) _REPEAT_5(macro)
#define _REPEAT_7(macro) macro(128,64) _REPEAT_6(macro)

#define _REPEAT_KEY(macro) _REPEAT_5(macro)
#define _REPEAT_VALUE(macro) _REPEAT_7(macro)

#define PARSE_KEY_TOP parse_key_32
#define PARSE_VALUE_TOP parse_value_128

#define INTERNAL_KEY_SIZE 56
#define INTERNAL_VALUE_SIZE 280

#define _PARSE_KEY state parse_extract_key_8 {\
  buffer.extract(hdr.key_8);\
  user_metadata.key[55:0] = user_metadata.key[47:0] ++ hdr.key_8.key;\
  transition parse_key_null;\
}\
\
state parse_key_8 {\
  transition select(hdr.memcached.key_length[0:0]) {\
    1 : parse_extract_key_8;\
    _ : parse_key_null;\
  }\
}\
\
state parse_extract_key_16 {\
  buffer.extract(hdr.key_16);\
  user_metadata.key[47:0] = user_metadata.key[31:0] ++ hdr.key_16.key;\
  transition parse_key_8;\
}\
\
state parse_key_16 {\
  transition select(hdr.memcached.key_length[1:1]) {\
    1 : parse_extract_key_16;\
    _ : parse_key_8;\
  }\
}\
\
state parse_extract_key_32 {\
  buffer.extract(hdr.key_32);\
  user_metadata.key[31:0] = hdr.key_32.key;\
  transition parse_key_16;\
}\
\
state parse_key_32 {\
  transition select(hdr.memcached.key_length[2:2]) {\
    1 : parse_extract_key_32;\
    _ : parse_key_16;\
  }\
}\
\


#define _PARSE_VALUE state parse_extract_value_8 {\
  buffer.extract(hdr.value_8);\
  user_metadata.value[247:0] = user_metadata.value[239:0] ++ hdr.value_8.value;\
  transition parse_value_null;\
}\
\
state parse_value_8 {\
  transition select(user_metadata.value_size[0:0]) {\
    1 : parse_extract_value_8;\
    _ : parse_value_null;\
  }\
}\
\
state parse_extract_value_16 {\
  buffer.extract(hdr.value_16);\
  user_metadata.value[239:0] = user_metadata.value[223:0] ++ hdr.value_16.value;\
  transition parse_value_8;\
}\
\
state parse_value_16 {\
  transition select(user_metadata.value_size[1:1]) {\
    1 : parse_extract_value_16;\
    _ : parse_value_8;\
  }\
}\
\
state parse_extract_value_32 {\
  buffer.extract(hdr.value_32);\
  user_metadata.value[223:0] = user_metadata.value[191:0] ++ hdr.value_32.value;\
  transition parse_value_16;\
}\
\
state parse_value_32 {\
  transition select(user_metadata.value_size[2:2]) {\
    1 : parse_extract_value_32;\
    _ : parse_value_16;\
  }\
}\
\
state parse_extract_value_64 {\
  buffer.extract(hdr.value_64);\
  user_metadata.value[191:0] = user_metadata.value[127:0] ++ hdr.value_64.value;\
  transition parse_value_32;\
}\
\
state parse_value_64 {\
  transition select(user_metadata.value_size[3:3]) {\
    1 : parse_extract_value_64;\
    _ : parse_value_32;\
  }\
}\
\
state parse_extract_value_128 {\
  buffer.extract(hdr.value_128);\
  user_metadata.value[127:0] = hdr.value_128.value;\
  transition parse_value_64;\
}\
\
state parse_value_128 {\
  transition select(user_metadata.value_size[4:4]) {\
    1 : parse_extract_value_128;\
    _ : parse_value_64;\
  }\
}\
\


#define REPOPULATE_VALUE if (user_metadata.value_size_out[0:0] == 1) {\
  hdr.value_8.setValid();\
  hdr.value_8.value = user_metadata.value[7:0];\
  user_metadata.value[239:0] = user_metadata.value[247:8];\
}\
\
if (user_metadata.value_size_out[1:1] == 1) {\
  hdr.value_16.setValid();\
  hdr.value_16.value = user_metadata.value[15:0];\
  user_metadata.value[223:0] = user_metadata.value[239:16];\
}\
\
if (user_metadata.value_size_out[2:2] == 1) {\
  hdr.value_32.setValid();\
  hdr.value_32.value = user_metadata.value[31:0];\
  user_metadata.value[191:0] = user_metadata.value[223:32];\
}\
\
if (user_metadata.value_size_out[3:3] == 1) {\
  hdr.value_64.setValid();\
  hdr.value_64.value = user_metadata.value[63:0];\
  user_metadata.value[127:0] = user_metadata.value[191:64];\
}\
\
if (user_metadata.value_size_out[4:4] == 1) {\
  hdr.value_128.setValid();\
  hdr.value_128.value = user_metadata.value[127:0];\
  \
}\
\


