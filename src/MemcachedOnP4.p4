#include <core.p4>
#include <sume_switch.p4>
#include "utils.p4"
#include "types.p4"
#include "parser.p4"
#include "memcached.p4"


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
        // try to forward based on destination Ethernet address
        if (!forward.apply().hit) {
            // miss in forwarding table
            if (sume_metadata.src_port[0:0]==1) {
                sume_metadata.dst_port = 8w0b01010100;
            }
            if (sume_metadata.src_port[2:2]==1) {
                sume_metadata.dst_port = 8w0b01010001;
            }
            if (sume_metadata.src_port[4:4]==1) {
                sume_metadata.dst_port = 8w0b01000101;
            }
            if (sume_metadata.src_port[6:6]==1) {
                sume_metadata.dst_port = 8w0b00010101;
            }
        }

        // check if src Ethernet address is in the forwarding database
        if (!smac.apply().hit) {
            // unknown source MAC address
            send_to_control();
        }

        if (hdr.memcached.isValid()) {
            MemcachedControl.apply(hdr, user_metadata, digest_data, sume_metadata);
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
