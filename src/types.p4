
// The standard routing parts of this parser are mostly copied from the
// P46NetFPGA contributed project "learning_switch" and from the P4-spec
// example "psa-example-incremental-checksum2".


#include <core.p4>
#include <sume_switch.p4>

typedef bit<48> EthernetAddress;

// standard Ethernet header
header Ethernet_h {
    EthernetAddress dstAddr;
    EthernetAddress srcAddr;
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
    bit<16> length_;
    bit<16> checksum;
}

header memcached_t {
    bit<8> magic;
    bit<8> opcode;
    bit<16> key_length;
    bit<8> extras_length;
    bit<8> data_type;
    bit<16> vbucket_id;
    bit<32> total_length;
    bit<32> opaque;
    bit<64> CAS;
}

header extras_32_t {
    bit<32> flags;
}

header extras_64_t {
    bit<32> flags;
    bit<32> expiration;
}

header_union extras_t {
    extras_32_t extras_32;
    extras_64_t extras_64;
}

header key_t {
    varbit<1024> key;
}

header value_t {
    varbit<2048> value;
}

// List of all recognized headers
struct headers {
    ethernet_t       ethernet;
    ipv4_t           ipv4;
    ipv6_t           ipv6;
    tcp_t            tcp;
    udp_t            udp;
    memcached_t      memcached;
    extras_t         extras;
    key_t            key;
    value_t          value;
}

// digest data to send to cpu if desired
struct digest_data_t {
    bit<120> unused;
    bit<64> allocated_register;
    bit<64> eth_src_addr;
    port_t src_port;
}

struct user_metadata_t {
    bool isRequest;
    bit<8>  unused;
}


typedef bit<64> reg_address_t;
