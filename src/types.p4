
// The standard routing parts of this parser are mostly copied from the
// P46NetFPGA contributed project "learning_switch" and from the P4-spec
// example "psa-example-incremental-checksum2".


typedef bit<8> regAddr_t;
typedef bit<248> key_t;
typedef bit<248> value_t;

// typedef bit<1> regAddr2040;
// typedef bit<1> regAddr1024;
// typedef bit<1> regAddr512;
// typedef bit<1> regAddr256;
typedef bit<7> regAddr128;
// Note: Size of one BRAM tile = 32768 bits (32kb)
// 2^7 * 128 = 32768 / 2 so slab128 takes half a tile


// standard Ethernet header
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

header udp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<16> udpLength;
    bit<16> checksum;
}

header memcached_t {
    bit<8> magic;
    bit<8> opcode;
    bit<16> key_length;   // in bytes
    bit<8> extras_length; // in bytes
    bit<8> data_type;
    bit<16> vbucket_id;
    bit<32> total_body;   // length of extras + key + value, in bytes
    bit<32> opaque;
    bit<64> CAS;
}

header extras_flags_t {
    bit<32> flags;
}

header extras_expiration_t {
    bit<32> expiration;
}

MAKE_KEY_T

MAKE_VALUE_T

// List of all recognized headers
struct headers {
    ethernet_t       ethernet;
    ipv4_t           ipv4;
    udp_t            udp;
    memcached_t      memcached;
    extras_flags_t   extras_flags;
    extras_expiration_t extras_expiration;
    MAKE_STRUCT_KEYS
    MAKE_STRUCT_VALUES
}

// digest data to send to cpu if desired
struct digest_data_t {
    bit<16> fuzz;
    bit<16> unused1;
    bit<64> key_hash;
    bit<8> unused2;
    bit<64> value_hash;
    bool store_new_key;
    bool remove_this_key;
    bit<14> unused3;
    bit<64> eth_src_addr;
    port_t src_port;
}

struct user_metadata_t {
    bit<32> value_size;    // in bytes
    regAddr_t reg_address;
    bit<8> value_size_out; // in bytes
    bit<32> flags;
    bool isRequest;
    key_t key;
    value_t value;
}
