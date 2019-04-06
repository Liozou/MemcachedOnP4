
// The standard routing parts of this parser are mostly copied from the
// P46NetFPGA contributed project "learning_switch" and from the P4-spec
// example "psa-example-incremental-checksum2".


typedef bit<8> regAddr_t;
typedef bit<INTERNAL_VALUE_SIZE> value_t;
typedef bit<INTERNAL_KEY_SIZE> key_t;

typedef bit<8> regAddr64;
typedef bit<7> regAddr128;
typedef bit<6> regAddr256;
// typedef bit<1> regAddr512;
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
    bit<8> magic;
    bit<8> opcode;
    bit<8> unused;
    bit<56> key;
    bit<32> flags_value;
    bit<32> expiration;
    bit<8> value_size_out;
    bit<8> reg_addr;
    bit<6> reserved_flags;
    bool store_new_key;
    bool remove_this_key;
    bit<64> eth_src_addr;
    port_t src_port;
}

struct user_metadata_t {
    bit<32> value_size;    // in bytes
    bool isRequest;
    bit<8> value_size_out;
    bit<8> reg_addr;
    key_t key;
    value_t value;
}
