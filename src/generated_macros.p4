#define _REPEAT_3(macro) macro(8,null)
#define _REPEAT_4(macro) macro(16,8) _REPEAT_3(macro)
#define _REPEAT_5(macro) macro(32,16) _REPEAT_4(macro)
#define _REPEAT_6(macro) macro(64,32) _REPEAT_5(macro)
#define _REPEAT_7(macro) macro(128,64) _REPEAT_6(macro)
#define _REPEAT_8(macro) macro(256,128) _REPEAT_7(macro)
#define _REPEAT_9(macro) macro(512,256) _REPEAT_8(macro)
#define _REPEAT_10(macro) macro(1024,512) _REPEAT_9(macro)

#define _REPEAT_KEY(macro) _REPEAT_8(macro)
#define _REPEAT_VALUE(macro) _REPEAT_10(macro)

#define PARSE_KEY_TOP parse_key_256
#define PARSE_VALUE_TOP parse_value_1024

#define INTERNAL_KEY_SIZE 384
#define INTERNAL_VALUE_SIZE 2040

#define _PARSE_KEY state parse_extract_key_8 {\
  buffer.extract(hdr.key_8);\
  user_metadata.key = (bit<384>)(((bit<368>)user_metadata.key) ++ hdr.key_8.key);\
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
  user_metadata.key = (bit<384>)(((bit<352>)user_metadata.key) ++ hdr.key_16.key);\
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
  user_metadata.key = (bit<384>)(((bit<320>)user_metadata.key) ++ hdr.key_32.key);\
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
  user_metadata.key = (bit<384>)(((bit<256>)user_metadata.key) ++ hdr.key_64.key);\
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
  user_metadata.key = (bit<384>)(((bit<256>)user_metadata.key) ++ hdr.key_128.key);\
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
state parse_extract_key_256 {\
  buffer.extract(hdr.key_256);\
  user_metadata.key = (bit<384>)(hdr.key_256.key);\
  digest_data.key_hash = digest_data.key_hash ^ ((bit<64>)(hdr.key_256.key));\
  transition parse_key_128;\
}\
\
state parse_key_256 {\
  transition select(hdr.memcached.key_length[5:5]) {\
    1 : parse_extract_key_256;\
    _ : parse_key_128;\
  }\
}\


#define _PARSE_VALUE state parse_extract_value_8 {\
  buffer.extract(hdr.value_8);\
  user_metadata.value = (bit<2040>)(((bit<2032>)user_metadata.value) ++ hdr.value_8.value);\
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
  user_metadata.value = (bit<2040>)(((bit<2016>)user_metadata.value) ++ hdr.value_16.value);\
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
  user_metadata.value = (bit<2040>)(((bit<1984>)user_metadata.value) ++ hdr.value_32.value);\
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
  user_metadata.value = (bit<2040>)(((bit<1920>)user_metadata.value) ++ hdr.value_64.value);\
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
  user_metadata.value = (bit<2040>)(((bit<1792>)user_metadata.value) ++ hdr.value_128.value);\
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
state parse_extract_value_256 {\
  buffer.extract(hdr.value_256);\
  user_metadata.value = (bit<2040>)(((bit<1536>)user_metadata.value) ++ hdr.value_256.value);\
  digest_data.value_hash = digest_data.value_hash ^ ((bit<64>)(hdr.value_256.value));\
  transition parse_value_128;\
}\
\
state parse_value_256 {\
  transition select(user_metadata.value_size[5:5]) {\
    1 : parse_extract_value_256;\
    _ : parse_value_128;\
  }\
}\
state parse_extract_value_512 {\
  buffer.extract(hdr.value_512);\
  user_metadata.value = (bit<2040>)(((bit<1024>)user_metadata.value) ++ hdr.value_512.value);\
  digest_data.value_hash = digest_data.value_hash ^ ((bit<64>)(hdr.value_512.value));\
  transition parse_value_256;\
}\
\
state parse_value_512 {\
  transition select(user_metadata.value_size[6:6]) {\
    1 : parse_extract_value_512;\
    _ : parse_value_256;\
  }\
}\
state parse_extract_value_1024 {\
  buffer.extract(hdr.value_1024);\
  user_metadata.value = (bit<2040>)(hdr.value_1024.value);\
  digest_data.value_hash = digest_data.value_hash ^ ((bit<64>)(hdr.value_1024.value));\
  transition parse_value_512;\
}\
\
state parse_value_1024 {\
  transition select(user_metadata.value_size[7:7]) {\
    1 : parse_extract_value_1024;\
    _ : parse_value_512;\
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
  user_metadata.value = (user_metadata.value >> 7);\
}\
if (user_metadata.value_size_out[5:5] == 1) {\
  hdr.value_256.value = (bit<256>)user_metadata.value;\
  hdr.value_256.setValid();\
  user_metadata.value = (user_metadata.value >> 8);\
}\
if (user_metadata.value_size_out[6:6] == 1) {\
  hdr.value_512.value = (bit<512>)user_metadata.value;\
  hdr.value_512.setValid();\
  user_metadata.value = (user_metadata.value >> 9);\
}\
if (user_metadata.value_size_out[7:7] == 1) {\
  hdr.value_1024.value = (bit<1024>)user_metadata.value;\
  hdr.value_1024.setValid();\
  \
}\


