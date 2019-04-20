#!/usr/bin/env python


import sys
import os
from scapy.layers.all import Ether, IP, TCP
from scapy.all import *
import time
from threading import Timer

def string_from_int(n):
    s = ""
    l = hex(n)[2:]
    if len(l)%2:
        l = '0' + l
    for i in range(len(l)/2):
        s += chr(int(l[2*i:2*i+2], 16))
    return s

class Memcached(Packet):
    name = "Memcached"
    fields_desc=[ByteEnumField("magic",128, {128:"Request", 129:"Response"}),
                 ByteEnumField("opcode",0, {0:"GET",1:"SET",4:"DELETE",12:"GETK",10:"NOOP",8:"FLUSH"}),
                 ShortField("key_length",8),
                 ByteField("extras_length",0),
                 ByteField("data_type",0),
                 ShortField("vbucket_id",0),
                 IntField("total_length",60),
                 IntField("opaque",0),
                 LongField("cas",0)]

bind_layers(UDP, Memcached)

def make_memcached_hdr(keylen, valuelen, op, magic="Request", error=0, opaque=0, **kwargs):
    hdr = Memcached()
    hdr[Memcached].opcode = op
    hdr[Memcached].key_length = keylen
    hdr[Memcached].total_length = keylen + valuelen
    hdr[Memcached].magic = magic
    hdr[Memcached].vbucket_id = error
    hdr[Memcached].opaque = opaque
    if op=="SET" and magic=="Request":
        hdr[Memcached].total_length += 8 # for the extras
        hdr[Memcached].extras_length = 8
    elif (op=="GET" and magic=="Response" and error==0) or (op=="FLUSH" and magic=="Request"):
        hdr[Memcached].total_length += 4 # for the extras
        hdr[Memcached].extras_length = 4
    return hdr

def generate_load(length):
    load = ''
    for i in range(length):
        load += chr(random.randint(0,255))
    return load

def make_extras(op, magic="Request", flags="", expiration=0, error=0, **kwargs):
    if (op=="GET" or op=="GETK") and magic=="Response" and error==0:
        return flags
    if op=="SET" and magic=="Request":
        s = string_from_int(expiration)
        s = ('\x00'*(4 - len(s))) + s
        return flags + s
    if op=="FLUSH" and magic=="Request":
        s = string_from_int(expiration)
        return ('\x00'*(4 - len(s))) + s
    return ""

def make_memcached_pkt(src_MAC, dst_MAC, src_IP, dst_IP, key="", value="", **kwargs):
    pkt = Ether(src=src_MAC, dst=dst_MAC) / IP(src=src_IP, dst=dst_IP) / UDP(dport=11211, sport=11211, chksum=0)
    pkt = pkt / make_memcached_hdr(len(key), len(value), **kwargs)
    extras = make_extras(**kwargs)
    kv = (key + value)
    if extras!="":
        pkt /= extras
    if kv!="":
        pkt /= kv
    return pkt

def make_random_pkt(src_MAC, dst_MAC, src_IP, dst_IP):
    pkt = Ether(src=src_MAC, dst=dst_MAC) / IP(src=src_IP, dst=dst_IP) / UDP(dport=11212, sport=11212)
    return pkt

def pad32(pkt):
    pkt = pkt / ('\x00'*(32*(1+(len(pkt)-1)/32)-len(pkt)))
    del pkt[IP].chksum
    return pkt.__class__(str(pkt))

def padwithn(pkt, n):
    pkt = pkt / ('\x00'*n)
    return pkt


to_send_pkts = []
expected_pkts = {}

def send_packet(pkt, port="eth2", time=None):
    if time is None:
        if to_send_pkts==[]:
            to_send_pkts.append((pkt, port, 0))
        else:
            to_send_pkts.append((pkt, port, to_send_pkts[-1][-1]))
    else:
        to_send_pkts.append((pkt, port, time))

def send_packet32(pkt, port="eth2", time=None):
    send_packet(pad32(pkt), port, time)

def expect_packet(pkt, port="eth2", time=None):
    if not expected_pkts.has_key(port):
        expected_pkts[port] = []
    if time is None:
        if expected_pkts[port]==[]:
            expected_pkts[port].append((pkt, 0))
        else:
            expected_pkts[port].append((pkt, expected_pkts[port][-1][-1]))
    else:
        expected_pkts[port].append((pkt, time))

def expect_packet32(pkt, port="eth2", time=None):
    expect_packet(pad32(pkt), port, time)


def run_hw_test(timeout=10):
    to_send_pkts.sort(key=lambda x:-x[-1])
    for v in expected_pkts.itervalues():
        v.sort(key=lambda x:x[-1])

    unexpected = []

    def expect_packets():
        port, pkts = expected_pkts.popitem()
        def recv_packet(pkt):
            if (Memcached not in pkt) or pkt[Memcached].magic==128:
                return
            found = False
            for i in range(len(pkts)):
                if pkt == pkts[i][0]:
                    pkts.pop(i)
                    found = True
                    print "Found expected packet on port", port, " ; opcode is ", pkt[Memcached].opcode
                    break
            if not found:
                print "Unexpected packet received on port ", port
                print "LEN OF OBSERVED: ", len(pkt)
                pkt.show()
                print "LEN OF EXPECTED: ", len(pkts[0][0])
                pkts[0][0].show()
                unexpected.append((port, pkt))
            elif pkts==[]:
                exit(0)
        sniff(iface=port, prn=recv_packet, timeout=timeout)

    for k in range(len(expected_pkts)):
        Timer(0, expect_packets).start()

    time_0 = time.time()
    while to_send_pkts!=[]:
        pkt, port, t = to_send_pkts.pop()
        while time.time()-time_0 <= t:
            pass
        sendp(pkt, iface=port)



pkt_set1 = make_memcached_pkt(dst_MAC="f8:f2:1e:41:45:d8", src_MAC="f8:f2:1e:42:dd:9c",
                         dst_IP="192.168.100.6"       , src_IP="192.168.101.1",
                         op="SET", key="hello!", value="goodbye", flags="\x00\x00\x00\x00", expiration=0)

pkt_set2 = make_memcached_pkt(dst_MAC="f8:f2:1e:42:dd:9c", src_MAC="f8:f2:1e:41:45:d8",
                         dst_IP="192.168.101.1"       , src_IP="192.168.100.6",
                         op="SET", key="hello!", value="0123456789abcdefghijklmnopqrtu", flags="\x00\x00\x00\x00", expiration=0)

pkt_set_resp = make_memcached_pkt(dst_MAC="f8:f2:1e:42:dd:9c", src_MAC="f8:f2:1e:41:45:d8",
                         dst_IP="192.168.101.1"       , src_IP="192.168.100.6",
                         op="SET", magic="Response")


pkt_get = make_memcached_pkt(dst_MAC="f8:f2:1e:41:45:d8", src_MAC="f8:f2:1e:42:dd:9c",
                         dst_IP="192.168.100.6"       , src_IP="192.168.101.1",
                         op="GET", key="hello!")

pkt_not_found = make_memcached_pkt(dst_MAC="f8:f2:1e:42:dd:9c", src_MAC="f8:f2:1e:41:45:d8",
                         dst_IP="192.168.101.1"       , src_IP="192.168.100.6",
                         op="GET", error=1, magic="Response")


pkt_resp1 = make_memcached_pkt(dst_MAC="f8:f2:1e:42:dd:9c", src_MAC="f8:f2:1e:41:45:d8",
                         dst_IP="192.168.101.1"          , src_IP="192.168.100.6",
                         op="GET", value="goodbye", magic="Response", flags="\x00\x00\x00\x00")

pkt_resp2 = make_memcached_pkt(dst_MAC="f8:f2:1e:42:dd:9c", src_MAC="f8:f2:1e:41:45:d8",
                         dst_IP="192.168.100.1"          , src_IP="192.168.100.5",
                         op="GET", value="0123456789abcdefghijklmnopqrstu", magic="Response", flags="\x00\x00\x00\x00")


pkt_flush = make_memcached_pkt(dst_MAC="f8:f2:1e:41:45:d8", src_MAC="f8:f2:1e:42:dd:9c",
                         dst_IP="192.168.100.5"       , src_IP="192.168.100.1",
                         op="FLUSH", expiration=0)
pkt_flush_resp = make_memcached_pkt(dst_MAC="f8:f2:1e:42:dd:9c", src_MAC="f8:f2:1e:41:45:d8",
                         dst_IP="192.168.100.1"       , src_IP="192.168.100.5",
                         op="FLUSH", magic="Response")

pkt_noop = make_memcached_pkt(dst_MAC="f8:f2:1e:41:45:d8", src_MAC="f8:f2:1e:42:dd:9c",
                         dst_IP="192.168.100.5"       , src_IP="192.168.100.1",
                         op="NOOP")

send_packet32(pkt_flush)
expect_packet32(pkt_flush_resp)

send_packet32(pkt_get, time=1e-4)
expect_packet32(pkt_not_found)


send_packet32(pkt_set1, time=2e-4)
expect_packet32(pkt_set_resp)
send_packet32(pkt_get, time=3e-4)
expect_packet32(pkt_resp1)

send_packet32(pkt_set2, time=4e-4)
expect_packet32(pkt_set_resp)
send_packet32(pkt_get, time=5e-4)
expect_packet32(pkt_resp2)

# send_packet32(pkt_set1)
# expect_packet32(pkt_set1)
# send_packet32(pkt_get)
# expect_packet32(pkt_resp1)
# send_packet32(pkt_set2)
# expect_packet32(pkt_set2)
# send_packet32(pkt_get)
# expect_packet(padwithn(pkt_resp2, len(pad32(pkt_get)) - len(pkt_get)))


run_hw_test()
