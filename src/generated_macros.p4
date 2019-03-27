#define _REPEAT_3(macro) macro(8,null)
#define _REPEAT_4(macro) macro(16,8) _REPEAT_3(macro)
#define _REPEAT_5(macro) macro(32,16) _REPEAT_4(macro)
#define _REPEAT_6(macro) macro(64,32) _REPEAT_5(macro)
#define _REPEAT_7(macro) macro(128,64) _REPEAT_6(macro)

#define _REPEAT_KEY(macro) _REPEAT_7(macro)
#define _REPEAT_VALUE(macro) _REPEAT_7(macro)
#define PARSE_KEY_TOP parse_key_128
#define PARSE_VALUE_TOP parse_value_128

#define _PARSE_KEY state parse_extract_key_8 {\
  buffer.extract(hdr.key_8);\
  user_metadata.key = (bit<248>)(((bit<240>)user_metadata.key) ++ hdr.key_8.key);\
  digest_data.key_hash = digest_data.key_hash ^ ((bit<64>)(hdr.key_8.key));\
  transition parse_key_null;\
}\
\
state parse_key_8 {\
  transition select(hdr.memcached.key_length[0:0]) {\
    1 : parse_extract_key_8;\
    _ : parse_key_null;\
  }\
}\
state parse_extract_key_16 {\
  buffer.extract(hdr.key_16);\
  user_metadata.key = (bit<248>)(((bit<224>)user_metadata.key) ++ hdr.key_16.key);\
  digest_data.key_hash = digest_data.key_hash ^ ((bit<64>)(hdr.key_16.key));\
  transition parse_key_8;\
}\
\
state parse_key_16 {\
  transition select(hdr.memcached.key_length[1:1]) {\
    1 : parse_extract_key_16;\
    _ : parse_key_8;\
  }\
}\
state parse_extract_key_32 {\
  buffer.extract(hdr.key_32);\
  user_metadata.key = (bit<248>)(((bit<192>)user_metadata.key) ++ hdr.key_32.key);\
  digest_data.key_hash = digest_data.key_hash ^ ((bit<64>)(hdr.key_32.key));\
  transition parse_key_16;\
}\
\
state parse_key_32 {\
  transition select(hdr.memcached.key_length[2:2]) {\
    1 : parse_extract_key_32;\
    _ : parse_key_16;\
  }\
}\
state parse_extract_key_64 {\
  buffer.extract(hdr.key_64);\
  user_metadata.key = (bit<248>)(((bit<128>)user_metadata.key) ++ hdr.key_64.key);\
  digest_data.key_hash = digest_data.key_hash ^ ((bit<64>)(hdr.key_64.key));\
  transition parse_key_32;\
}\
\
state parse_key_64 {\
  transition select(hdr.memcached.key_length[3:3]) {\
    1 : parse_extract_key_64;\
    _ : parse_key_32;\
  }\
}\
state parse_extract_key_128 {\
  buffer.extract(hdr.key_128);\
  user_metadata.key = (bit<248>)(hdr.key_128.key);\
  digest_data.key_hash = digest_data.key_hash ^ ((bit<64>)(hdr.key_128.key));\
  transition parse_key_64;\
}\
\
state parse_key_128 {\
  transition select(hdr.memcached.key_length[4:4]) {\
    1 : parse_extract_key_128;\
    _ : parse_key_64;\
  }\
}\


#define _PARSE_VALUE state parse_extract_value_8 {\
  buffer.extract(hdr.value_8);\
  user_metadata.value = (bit<248>)(((bit<240>)user_metadata.value) ++ hdr.value_8.value);\
  digest_data.value_hash = digest_data.value_hash ^ ((bit<64>)(hdr.value_8.value));\
  transition parse_value_null;\
}\
\
state parse_value_8 {\
  transition select(user_metadata.value_size[0:0]) {\
    1 : parse_extract_value_8;\
    _ : parse_value_null;\
  }\
}\
state parse_extract_value_16 {\
  buffer.extract(hdr.value_16);\
  user_metadata.value = (bit<248>)(((bit<224>)user_metadata.value) ++ hdr.value_16.value);\
  digest_data.value_hash = digest_data.value_hash ^ ((bit<64>)(hdr.value_16.value));\
  transition parse_value_8;\
}\
\
state parse_value_16 {\
  transition select(user_metadata.value_size[1:1]) {\
    1 : parse_extract_value_16;\
    _ : parse_value_8;\
  }\
}\
state parse_extract_value_32 {\
  buffer.extract(hdr.value_32);\
  user_metadata.value = (bit<248>)(((bit<192>)user_metadata.value) ++ hdr.value_32.value);\
  digest_data.value_hash = digest_data.value_hash ^ ((bit<64>)(hdr.value_32.value));\
  transition parse_value_16;\
}\
\
state parse_value_32 {\
  transition select(user_metadata.value_size[2:2]) {\
    1 : parse_extract_value_32;\
    _ : parse_value_16;\
  }\
}\
state parse_extract_value_64 {\
  buffer.extract(hdr.value_64);\
  user_metadata.value = (bit<248>)(((bit<128>)user_metadata.value) ++ hdr.value_64.value);\
  digest_data.value_hash = digest_data.value_hash ^ ((bit<64>)(hdr.value_64.value));\
  transition parse_value_32;\
}\
\
state parse_value_64 {\
  transition select(user_metadata.value_size[3:3]) {\
    1 : parse_extract_value_64;\
    _ : parse_value_32;\
  }\
}\
state parse_extract_value_128 {\
  buffer.extract(hdr.value_128);\
  user_metadata.value = (bit<248>)(hdr.value_128.value);\
  digest_data.value_hash = digest_data.value_hash ^ ((bit<64>)(hdr.value_128.value));\
  transition parse_value_64;\
}\
\
state parse_value_128 {\
  transition select(user_metadata.value_size[4:4]) {\
    1 : parse_extract_value_128;\
    _ : parse_value_64;\
  }\
}\


#define REPOPULATE_VALUE if (user_metadata.value_size_out[0:0] == 1) {\
  hdr.value_8.value = (bit<8>)user_metadata.value;\
  hdr.value_8.setValid();\
  user_metadata.value = (user_metadata.value >> 3);\
}\
if (user_metadata.value_size_out[1:1] == 1) {\
  hdr.value_16.value = (bit<16>)user_metadata.value;\
  hdr.value_16.setValid();\
  user_metadata.value = (user_metadata.value >> 4);\
}\
if (user_metadata.value_size_out[2:2] == 1) {\
  hdr.value_32.value = (bit<32>)user_metadata.value;\
  hdr.value_32.setValid();\
  user_metadata.value = (user_metadata.value >> 5);\
}\
if (user_metadata.value_size_out[3:3] == 1) {\
  hdr.value_64.value = (bit<64>)user_metadata.value;\
  hdr.value_64.setValid();\
  user_metadata.value = (user_metadata.value >> 6);\
}\
if (user_metadata.value_size_out[4:4] == 1) {\
  hdr.value_128.value = (bit<128>)user_metadata.value;\
  hdr.value_128.setValid();\
  \
}\


