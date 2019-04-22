#!/usr/bin/env python


import sys
import os
from scapy.layers.all import Ether, IP, TCP
from scapy.all import *
import time
from threading import Timer, Thread
from Queue import Queue
from atexit import register
import pcapy

def string_from_int(n):
    s = ""
    l = hex(n)[2:]
    if len(l)%2:
        l = '0' + l
    for i in range(len(l)/2):
        s += chr(int(l[2*i:2*i+2], 16))
    return s

def int_from_string(s):
    x = 0
    for c in s:
        x = (x<<8) + ord(c)
    return x

memcached_opcodes = {0:"GET",1:"SET",4:"DELETE",12:"GETK",10:"NOOP",8:"FLUSH"}

class Memcached(Packet):
    name = "Memcached"
    fields_desc=[ByteEnumField("magic",128, {128:"Request", 129:"Response"}),
                 ByteEnumField("opcode",0, memcached_opcodes),
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

def generate_ascii(length):
    load = ''
    for i in range(length):
        load += chr(random.randint(33,126))
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
    payload = make_extras(**kwargs) + key + value
    return pkt / payload

def make_random_pkt(src_MAC, dst_MAC, src_IP, dst_IP):
    pkt = Ether(src=src_MAC, dst=dst_MAC) / IP(src=src_IP, dst=dst_IP) / UDP(dport=11212, sport=11212)
    return pkt / generate_load(random.randint(0,100))

def pad32(pkt):
    pkt = pkt / ('\x00'*(32*(1+(len(pkt)-1)/32)-len(pkt)))
    del pkt[IP].chksum
    return pkt.__class__(str(pkt))

def padwithn(pkt, n):
    pkt = pkt / ('\x00'*n)
    return pkt.__class__(str(pkt))


to_send_pkts = []
expected_pkts = {}
record_expected_pkts = {}

def send_packet(pkt, port, delay):
    if to_send_pkts==[]:
        to_send_pkts.append((pkt, port, delay))
    else:
        to_send_pkts.append((pkt, port, to_send_pkts[-1][-1]+delay))

# def send_packet32(pkt, port, time):
#     send_packet(pad32(pkt), port, time)

def expect_packet(pkt, port, delay):
    if not expected_pkts.has_key(port):
        expected_pkts[port] = []
    if expected_pkts[port]==[]:
        expected_pkts[port].append((pkt, delay))
    else:
        expected_pkts[port].append((pkt, expected_pkts[port][-1][-1]+delay))

# def expect_packet32(pkt, port, time):
#     expect_packet(pad32(pkt), port, time)

def _expect_packets():
    port, pkts = expected_pkts.popitem()
    record_expected_pkts[port] = pkts
    received_cap = Queue()

    def recv_packet(pkt):
        if pkt[Memcached].magic==128:
            print "Sniffed sent packet on port", port
            return
        if (Memcached not in pkt):
            print "NON MEMCACHED PACKET"
            pkt.show()
            exit(1)
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
        elif pkts==[]:
            exit(0)

    cap = pcapy.open_live(port, 65536, True, 0)
    while True:
        header,payload = cap.next()
        recv_packet(Ether(payload))

# sniff(iface=port, prn=recv_packet, timeout=timeout)

def checkAllArrived():
    flag = True
    for (k,v) in record_expected_pkts.iteritems():
        print k
        for (x,t) in v:
            flag = False
            print "Unobserved packet on port", k, ":"
            x.show()
    if flag:
        print "All packets arrived!"

def run_hw_test(timeout):
    to_send_pkts.sort(key=lambda x:-x[-1])
    timeout += to_send_pkts[0][-1]
    for v in expected_pkts.itervalues():
        v.sort(key=lambda x:x[-1])

    for k in range(len(expected_pkts)):
        t = Thread(target=_expect_packets)
        t.daemon = True
        t.start()

    time_0 = time.time()
    while to_send_pkts!=[]:
        pkt, port, t = to_send_pkts.pop()
        while time.time()-time_0 <= t:
            pass
        sendp(pkt, iface=port)

    Timer(timeout, checkAllArrived).start()


def find_value(key, time):
    n = len(to_send_pkts)
    m = len(key)
    value = None
    latest = -1
    for i in range(n):
        pkt, port, t = to_send_pkts[-i-1]
        if t > time:
            continue
        if Memcached in pkt:
            if pkt[Memcached].opcode == 1 and pkt[Memcached].key_length == m and str(pkt[Raw])[8:m+8] == key: # Set
                if t == time:
                    raise Exception("SET and GET sent at the same time -> unpredictable hit or miss")
                if t > latest:
                    value = str(pkt[Raw])[m+8:pkt[Memcached].total_length]
                    latest = t
                elif t == latest:
                    if value is None:
                        op = "FLUSH"
                    else:
                        op = "SET with different value"
                    raise Exception("SET and "+op+" sent at the same time -> unpredictable hit or miss")
            elif pkt[Memcached].opcode == 8: # Flush
                if Raw in pkt:
                    t += int_from_string(str(pkt[Raw])[:4])
                if t > time:
                    continue
                elif t==time:
                    raise Exception("FLUSH and GET sent at the same time -> unpredictable hit or miss")
                if t > latest:
                    value = None
                    latest = t
                elif t == latest and value is not None:
                    raise Exception("FLUSH and SET sent at the same time -> unpredictable hit or miss")
    return value

def _make_response(pkt, **kwargs):
    op = pkt[Memcached].opcode
    return make_memcached_pkt(dst_MAC=pkt[Ether].src, src_MAC=pkt[Ether].dst,
                               dst_IP=pkt[IP].src, src_IP=pkt[IP].dst,
                               op=memcached_opcodes.get(op, op), magic="Response", **kwargs)
def make_response(pkt, time):
    assert(Memcached in pkt)
    if pkt[Memcached].opcode == 0: # GET
        payload = str(pkt[Raw])
        # assert(len(payload) == pkt[Memcached].key_length)
        value = find_value(payload[:pkt[Memcached].key_length], time)
        if value is None:
            return _make_response(pkt, error=1)
        return _make_response(pkt, value=value, flags="\x00\x00\x00\x00")
    else:
        return _make_response(pkt)

# Predicts the expected responses and store them
def prepare_expected():
    for (pkt, port, t) in to_send_pkts:
        expect_packet(pad32(make_response(pkt, t)), port, 1)

def send_memcached(port="eth2", delay=0, dst_MAC="f8:f2:1e:41:45:d8", src_MAC="f8:f2:1e:42:dd:9c", dst_IP="192.168.100.6", src_IP="192.168.101.1", **kwargs):
    pkt = make_memcached_pkt(dst_MAC=dst_MAC, src_MAC=src_MAC, dst_IP=dst_IP, src_IP=src_IP, **kwargs)
    send_packet(pad32(pkt), port, delay)


send_memcached(op="FLUSH")
send_memcached(op="NOOP", delay=1)
keys = []
for i in range(100):
    key = generate_ascii(3)
    while key in keys:
        key = generate_ascii(3)
    keys.append(key)
    value = generate_load(31)
    send_memcached(op="SET", key=key, value=value, flags="\x00\x00\x00\x00", expiration=0, delay=1e-1)

get_keys = keys * 10
random.shuffle(get_keys)

send_memcached(op="NOOP", delay=1)

for k in get_keys:
    send_memcached(op="GET", key=k, delay=1e-6)

# key = generate_ascii(3)
# value = generate_load(31)
# send_memcached(op="SET", key=key, value=value, flags="\x00\x00\x00\x00", expiration=0, delay=1)
#
# for i in range(100):
#     send_memcached(op="GET", key=key, delay=1e-4)

#
# for (pkt, port, t) in to_send_pkts:
#     print "TO SEND at time", t, "\n"
#     pkt.show()

prepare_expected()
#
# for (port, pkts) in expected_pkts.iteritems():
#     print "EXPECTED ON", port
#     for (pkt, t) in pkts:
#         print "at time", t
#         pkt.show()

run_hw_test(2)
