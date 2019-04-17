#include <core.p4>
#include <sume_switch.p4>
#include "utils.p4"
#include "types.p4"
#include "parser.p4"
#include "memcached.p4"

@Xilinx_MaxLatency(3)
@Xilinx_ControlWidth(0)
extern void ck_ip_chksum(in bit<4> version,
                         in bit<4> ihl,
                         in bit<8> tos,
                         in bit<16> totalLen,
                         in bit<16> identification,
                         in bit<3> flags,
                         in bit<13> fragOffset,
                         in bit<8> ttl,
                         in bit<8> protocol,
                         in bit<16> hdrChecksum,
                         in bit<32> srcAddr,
                         in bit<32> dstAddr,
                         out bit<16> result);

@Xilinx_MaxLatency(3)
@Xilinx_ControlWidth(0)
extern void compute_ip_chksum(in bit<4> version,
                         in bit<4> ihl,
                         in bit<8> tos,
                         in bit<16> totalLen,
                         in bit<16> identification,
                         in bit<3> flags,
                         in bit<13> fragOffset,
                         in bit<8> ttl,
                         in bit<8> protocol,
                         in bit<16> hdrChecksum,
                         in bit<32> srcAddr,
                         in bit<32> dstAddr,
                         out bit<16> result);

// match-action pipeline
control TopPipe(inout headers hdr,
                inout user_metadata_t user_metadata,
                inout digest_data_t digest_data,
                inout sume_metadata_t sume_metadata) {

    // Apart from the MemcachedControl part below, this control is copied from
    // the P46NetFPGA contributed project "learning_switch".

    action set_output_port(port_t port) {
        sume_metadata.dst_port = port;
    }

    table forward {
        key = { hdr.ethernet.dstAddr: exact; }

        actions = {
            set_output_port;
            NoAction;
        }
        size = 64;
        default_action = NoAction;
    }

    table smac {
        key = { hdr.ethernet.srcAddr: exact; }

        actions = {
            NoAction;
        }
        size = 64;
        default_action = NoAction;
    }

    action send_to_control() {
        digest_data.src_port = sume_metadata.src_port;
        digest_data.eth_src_addr = 16w0 ++ hdr.ethernet.srcAddr;
        digest_data.save_src_port = 1;
        sume_metadata.send_dig_to_cpu = 1;
    }

    apply {

        if (hdr.ipv4.isValid()) {
            bit<16> result = 0;
            bit<16> IPchecksum = hdr.ipv4.hdrChecksum;
            hdr.ipv4.hdrChecksum = 0;
            ck_ip_chksum(hdr.ipv4.version, hdr.ipv4.ihl, hdr.ipv4.diffserv, hdr.ipv4.totalLen, hdr.ipv4.identification, hdr.ipv4.flags, hdr.ipv4.fragOffset, hdr.ipv4.ttl, hdr.ipv4.protocol, hdr.ipv4.hdrChecksum, hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, result);
            if (result != IPchecksum) { // Invalid checksum -> drop the packet
                sume_metadata.dst_port = 0;
                return;
            }
        }

        // try to forward based on destination Ethernet address
        if (!forward.apply().hit) {
            // miss in forwarding table
            sume_metadata.dst_port = 8w0b01010101 & (~sume_metadata.src_port);
        }

        // check if src Ethernet address is in the forwarding database
        if (!smac.apply().hit) {
            // unknown source MAC address
            send_to_control();
        }

        if (hdr.memcached.isValid()) {
            MemcachedControl.apply(hdr, user_metadata, digest_data, sume_metadata);
        }

        if (hdr.ipv4.isValid()) {
            bit<16> result = 0;
            // At this point, hdr.ipv4.hdrChecksum is still set to 0.
            compute_ip_chksum(hdr.ipv4.version, hdr.ipv4.ihl, hdr.ipv4.diffserv, hdr.ipv4.totalLen, hdr.ipv4.identification, hdr.ipv4.flags, hdr.ipv4.fragOffset, hdr.ipv4.ttl, hdr.ipv4.protocol, hdr.ipv4.hdrChecksum, hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, result);
            hdr.ipv4.hdrChecksum = result;
        }
    }
}


// Deparser Implementation
// @Xilinx_MaxPacketRegion(16384)
control TopDeparser(packet_out packet,
                    in headers hdr,
                    in user_metadata_t user_metadata,
                    inout digest_data_t digest_data,
                    inout sume_metadata_t sume_metadata) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.udp);
        packet.emit(hdr.memcached);
        packet.emit(hdr.extras_flags);
        packet.emit(hdr.extras_expiration);
        DEPARSE_KEY
        DEPARSE_VALUE
    }
}


// Instantiate the switch
SimpleSumeSwitch(TopParser(), TopPipe(), TopDeparser()) main;
