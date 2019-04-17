#!/usr/bin/env python

#
# Copyright (c) 2017 Stephen Ibanez
# All rights reserved.
#
# This software was developed by Stanford University and the University of Cambridge Computer Laboratory
# under National Science Foundation under Grant No. CNS-0855268,
# the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
# by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"),
# as part of the DARPA MRC research programme.
#
# @NETFPGA_LICENSE_HEADER_START@
#
# Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  NetFPGA licenses this
# file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at:
#
#   http://www.netfpga-cic.org
#
# Unless required by applicable law or agreed to in writing, Work distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations under the License.
#
# @NETFPGA_LICENSE_HEADER_END@
#


"""
This version uses the digest data bus and expects all digest pkts
to be received on the dma0 interface
"""

from nf_sim_tools import *
from collections import OrderedDict
import random
import sss_sdnet_tuples
from sss_digest_header import *

ETH_KNOWN = ["08:11:11:11:11:08",
            "08:22:22:22:22:08",
            "08:33:33:33:33:08",
            "08:44:44:44:44:08"]

ETH_UNKNOWN = ["08:de:ad:be:ef:08",
              "08:ca:fe:ba:be:08",
              "08:ba:5e:ba:11:08",
              "08:b0:1d:fa:ce:08"]

IPv4_ADDR = ["192.168.10.1",
            "192.168.10.2",
            "192.168.10.3",
            "192.168.10.4"]

portMap = {0 : 0b00000001, 1 : 0b00000100, 2 : 0b00010000, 3 : 0b01000000}
bcast_portMap = {0 : 0b01010100, 1 : 0b01010001, 2 : 0b01000101, 3 : 0b00010101}

sss_sdnet_tuples.clear_tuple_files()

pkt_num = 0
pktsApplied = []
pktsExpected = []

# Pkt lists for SUME simulations
nf_applied = OrderedDict()
nf_applied[0] = []
nf_applied[1] = []
nf_applied[2] = []
nf_applied[3] = []
nf_expected = OrderedDict()
nf_expected[0] = []
nf_expected[1] = []
nf_expected[2] = []
nf_expected[3] = []

dma0_expected = []



from math import log

def bits_from_int(n, size):
    l = [0] * size
    for i in range(size):
        l[-i-1] = n%2
        n/=2
    return l

def int_from_bits(l):
    l = list(reversed(l))
    x = 0
    while len(l)!=0:
        x = (x<<1) + l.pop()
    return x

def bits_from_string(s):
    l = []
    for c in s:
        l.extend(bits_from_int(ord(c), 8))
    return l

def int_from_string(s):
    x = 0
    for c in s:
        x = (x<<8) + ord(c)
    return x

def generate_obj(l):
    load = ""
    l = list(reversed(l))
    while (len(l)%8 != 0):
        l.append(0)
    l = list(reversed(l))
    for i in range(0,len(l)/8):
        x = 0
        for j in range(0,8):
            x = (x<<1) + l[-8*(i+1)+j]
        load = chr(x) + load
    return load

def compute_simple_hash(obj, max_length=64):
    intobj = 0
    arrayobj = bits_from_string(obj)
    length = len(arrayobj)
    assert(length%8==0)
    ret = [0]*max_length
    loglength = int(log(length,2))
    for i in range(loglength, -1, -1):
        if ((length >> i) % 2 == 1):
            newobj = arrayobj[0:(1<<i)]
            for j in range(max_length-1, max(-1,max_length-1-(1<<i)), -1):
                ret[j] = ret[j] ^ newobj[j-max_length+(1<<i)]
            arrayobj = arrayobj[(1<<i):]
    return int_from_bits(ret)

def test_hash(n):
    return compute_simple_hash(generate_obj(bits_from_int(n, 1+int(log(max(n,1),2)))))

def inverse_hex_from_int(n):
    x = hex(n)[2:]
    if len(x)%2==1:
        x = "0" + x
    l = ""
    for i in range(len(x)/2):
        l = x[2*i] + x[2*i+1] + l
    return int(l,16)

class Memcached(Packet):
    name = "MemcachedPacket "
    fields_desc=[ByteEnumField("magic",128, {128:"Request", 129:"Response"}),
                 ByteEnumField("opcode",0, {0:"GET",1:"SET",4:"DELETE",12:"GETK",10:"NOOP"}),
                 ShortField("key_length",8),
                 ByteField("extras_length",0),
                 ByteField("data_type",0),
                 ShortField("vbucket_id",0),
                 IntField("total_length",60),
                 IntField("opaque",0),
                 LongField("cas",0)]

def make_memcached_hdr(op, keylen, valuelen):
    hdr = Memcached()
    hdr[Memcached].opcode = op
    hdr[Memcached].key_length = keylen
    hdr[Memcached].total_length = keylen + valuelen
    if op=="SET":
        hdr[Memcached].total_length += 8 # for the extras
        hdr[Memcached].extras_length = 8
    return hdr

def generate_load(length):
    load = ''
    for i in range(length):
        load += chr(random.randint(0,255))
    return load

def make_memcached_pkt(op, keylen, valuelen): # keylen and valuelen are expressed in bytes
    key = generate_load(keylen)
    value = generate_load(valuelen)
    pkt = make_memcached_hdr(op, keylen, valuelen) / (key + value)
    return pkt, key, value



def applyPkt(pkt, src_ind):
    global pkt_num
    pktsApplied.append(pkt)
    sss_sdnet_tuples.sume_tuple_in['src_port'] = portMap[src_ind]
    sss_sdnet_tuples.sume_tuple_expect['src_port'] = portMap[src_ind]
    pkt.time = pkt_num
    nf_applied[src_ind].append(pkt)
    pkt_num += 1

def expPkt(pkt, src_ind, dst_ind, src_known, dst_known, isMemcached, key, value):
    pktsExpected.append(pkt)
    # If dst MAC address is unknown, broadcast with src port pruning
    if dst_known:
        sss_sdnet_tuples.sume_tuple_expect['dst_port'] = portMap[dst_ind]
        nf_expected[dst_ind].append(pkt)
    else:
        sss_sdnet_tuples.sume_tuple_expect['dst_port'] = bcast_portMap[src_ind]
        for ind in [0,1,2,3]:
            if ind != src_ind:
                nf_expected[ind].append(pkt)

    if isMemcached:
        print "Memcached Packet with key = ", hex(int_from_string(key))
        int_key = int_from_string(key);
        fuzz = int('aaaa', 16)
        magic = int('80', 16)
        opcode = int('0a',16)
        sss_sdnet_tuples.dig_tuple_expect['key'] = int_from_string(key)
    else:
        print "Non-M Packet"
        int_key = 0; magic = 0; opcode = 0
        fuzz = int('bbbb', 16)
        sss_sdnet_tuples.dig_tuple_expect['key'] = 0

    # If src MAC address is unknown, send over DMA
    if not src_known:
        src_port = portMap[src_ind]
        eth_src_addr = int(pkt[Ether].src.replace(':',''),16)
        flags = 4
    else:
        src_port = 0; eth_src_addr = 0; flags = 0

    sss_sdnet_tuples.sume_tuple_expect['send_dig_to_cpu'] = 0
    sss_sdnet_tuples.dig_tuple_expect['src_port'] = src_port
    sss_sdnet_tuples.dig_tuple_expect['eth_src_addr'] = eth_src_addr
    sss_sdnet_tuples.dig_tuple_expect['magic'] = magic
    sss_sdnet_tuples.dig_tuple_expect['opcode'] = opcode
    sss_sdnet_tuples.dig_tuple_expect['fuzz'] = fuzz
    sss_sdnet_tuples.dig_tuple_expect['flags'] = flags

    if isMemcached or not src_known:
        digest_pkt = Digest_data(src_port=src_port, eth_src_addr=eth_src_addr, fuzz=inverse_hex_from_int(fuzz), key=int_key, magic=magic, opcode=opcode, flags=flags)
        dma0_expected.append(digest_pkt)
        sss_sdnet_tuples.sume_tuple_expect['send_dig_to_cpu'] = 1


    sss_sdnet_tuples.write_tuples()

def write_pcap_files():
    wrpcap("src.pcap", pktsApplied)
    wrpcap("dst.pcap", pktsExpected)

    for i in nf_applied.keys():
        if (len(nf_applied[i]) > 0):
            wrpcap('nf{0}_applied.pcap'.format(i), nf_applied[i])

    for i in nf_expected.keys():
        if (len(nf_expected[i]) > 0):
            wrpcap('nf{0}_expected.pcap'.format(i), nf_expected[i])

    for i in nf_applied.keys():
        print "nf{0}_applied times: ".format(i), [p.time for p in nf_applied[i]]

    if (len(dma0_expected) > 0):
        wrpcap('dma0_expected.pcap', dma0_expected)


src_pkts = []
dst_pkts = []
# create some packets that are known and some that are unknown
for i in range(20):
    src_known = bool(random.getrandbits(1))
    dst_known = bool(random.getrandbits(1))
    src_ind = random.randint(0,3)
    dst_ind = random.randint(0,3)
    isMemcached = bool(random.getrandbits(1))

    # pick src MAC
    if src_known:
        src_MAC = ETH_KNOWN[src_ind]
    else:
        src_MAC = ETH_UNKNOWN[src_ind]

    # pick dst MAC
    if dst_known:
        dst_MAC = ETH_KNOWN[dst_ind]
    else:
        dst_MAC = ETH_UNKNOWN[dst_ind]

    if isMemcached:
        memcachedPkt, key, value = make_memcached_pkt("NOOP", random.randint(1,7), random.randint(1,15))
        pkt = Ether(src=src_MAC, dst=dst_MAC) / IP(src=IPv4_ADDR[src_ind], dst=IPv4_ADDR[dst_ind]) / UDP(dport=11211, chksum=0) / memcachedPkt
    else:
        key = 0; value = 0
        pkt = Ether(src=src_MAC, dst=dst_MAC) / IP(src=IPv4_ADDR[src_ind], dst=IPv4_ADDR[dst_ind]) / TCP()
    pkt = pad_pkt(pkt, 64)
    applyPkt(pkt, src_ind)
    expPkt(pkt, src_ind, dst_ind, src_known, dst_known, isMemcached, key, value)

write_pcap_files()
