
// The standard routing parts of this parser are mostly copied from the
// P46NetFPGA contributed project "learning_switch" and from the P4-spec
// example "psa-example-incremental-checksum2".

//
// Copyright (c) 2017 Stephen Ibanez
// All rights reserved.
//
// This software was developed by Stanford University and the University of Cambridge Computer Laboratory
// under National Science Foundation under Grant No. CNS-0855268,
// the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
// by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"),
// as part of the DARPA MRC research programme.
//
// @NETFPGA_LICENSE_HEADER_START@
//
// Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
// license agreements.  See the NOTICE file distributed with this work for
// additional information regarding copyright ownership.  NetFPGA licenses this
// file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
// "License"); you may not use this file except in compliance with the
// License.  You may obtain a copy of the License at:
//
//   http://www.netfpga-cic.org
//
// Unless required by applicable law or agreed to in writing, Work distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@
//



// Parser Implementation
@Xilinx_MaxPacketRegion(16384)
parser TopParser(packet_in buffer,
                 out headers hdr,
                 out user_metadata_t user_metadata,
                 out digest_data_t digest_data,
                 inout sume_metadata_t sume_metadata) {

    state start {
        buffer.extract(hdr.ethernet);
        user_metadata.isRequest = false;
        user_metadata.slabID = 0;
        user_metadata.reg_address = 0;
        user_metadata.value_size = 0;
        digest_data.src_port = 0;
        digest_data.eth_src_addr = 0;
        digest_data.unused = 0;
        transition select(hdr.ethernet.etherType) {
            0x0800: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        buffer.extract(hdr.ipv4);
        // verify(hdr.ipv4.ihl == 5, error.UnhandledIPv4Options);
        transition select(hdr.ipv4.protocol) {
            17: parse_udp;
            default: accept;
        }
    }

    state parse_udp {
        buffer.extract(hdr.udp);
        transition select(hdr.udp.dstPort) {
            11211: parse_memcached;
            default: accept;
        }
    }

    state parse_memcached {
        buffer.extract(hdr.memcached);
        user_metadata.value_size = (bit<32>)(hdr.memcached.total_length - 192 - ((bit<32>)(hdr.memcached.key_length)) - ((bit<32>)hdr.memcached.extras_length));
        transition select(hdr.memcached.extras_length) {
            0:  PARSE_KEY_TOP;
            32: parse_extras_32;
            64: parse_extras_64;
            default: reject;
        }
    }

    state parse_extras_32 {
        buffer.extract(hdr.extras_flags);
        transition PARSE_KEY_TOP;
    }
    state parse_extras_64 {
        buffer.extract(hdr.extras_flags);
        buffer.extract(hdr.extras_expiration);
        transition PARSE_KEY_TOP;
    }

    PARSE_VALUE

    PARSE_KEY
}
