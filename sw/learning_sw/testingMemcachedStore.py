#!/usr/bin/env python

#import memcache
import socket
import sys
import pcapy
import scapy
from scapy.all import *
import numpy as np
import sys, os
sys.path.append(os.path.expandvars('$P4_PROJECT_DIR/testdata/'))
from sss_digest_header import *
import numpy as np
sys.path.append(os.path.expandvars('$P4_PROJECT_DIR/sw/CLI/'))
from p4_tables_api import *
from NFTest import *


import pymemcache
from pymemcache.client.base import Client

client = Client(('192.168.100.5',11211),allow_unicode_keys=True)

from threading import Timer


#### how to use memcache using the CPU
#client  = memcache.Client(["192.168.100.5"], debug=1)

sample_obj = {"name": "Soliman",
"lang": "Python"}

sample_obj = {"hello!": "Soliman",
"lang": "Python"}
client.set("sample_user", sample_obj)
client.set("hello!", "hellosdf")

value = client.get("sample_user")

print "before delete"
print client.get("sample_user")
print "before wrong delete"
print client.delete("sdfasdfsadfasdfasdf")
print "after wrong delete"
print client.delete("sample_user")
client.flush_all(5)
print "after delete"
print client.get("sample_user")
print client.get("asdfasdfadfasdfadf")



#### #below is more about how to get python to 

class Memcached(Packet):
    name = "MemcachedPacket "
    fields_desc=[ByteEnumField("magic",128, {128:"Request", 129:"Response"}),
                 ByteEnumField("opcode",0, {0:"GET",1:"SET",4:"DELETE",12:"GETK",10:"NOOP",8:"FLUSH"}),
                 ShortField("key_length",8),
                 ByteField("extras_length",0),
                 ByteField("data_type",0),
                 ShortField("vbucket_id",0),
                 IntField("total_length",60),
                 IntField("opaque",0),
                 LongField("cas",0)]

def string_from_int(n):
    s = ""
#    l = hex(n)[2:]
    l = n
    if len(l)%2:
        l = '0' + l
    for i in range(len(l)/2):
        s += chr(int(l[2*i:2*i+2], 16))
    return s



bind_layers(UDP,Memcached)

def setOperation(key,value):
	returned = client.set(key,value)
	return returned

def getOperation(key):
	print "before"
	value = client.get(key)
	return value

print "trying"
value = getOperation('2')
print value


def deleteOperation(key):
	value = client.delete(key)
	return value

def pad32(pkt):
    pkt = pkt / ('\x00'*(32*(1+(len(pkt)-1)/32)-len(pkt)))
    #print("SIZE OF PKT (after padding32) = ", lvbucket_iden(pkt))
    return pkt

def setPacket(pkt):
	#pkt.show()
	raw = pkt.lastlayer()
	#data = Digest_data(pkt)
	#pktInHex = hex(raw)
	#print hexdump(raw)
	stringVersion = str(raw).encode("HEX")
	
	#extracting Flags
	flags = string_from_int(stringVersion[0:8]) #chr(int(stringVersion[0:8],16))
	print flags

	#extracting expiration
	expiration = string_from_int(stringVersion[8:16])
	print expiration

	#extracting key
	keyLength = pkt[Memcached].key_length
	keyLengthForHex = keyLength *2
	keyEndPoint =  16 + keyLengthForHex
	key =  string_from_int(stringVersion[16:keyEndPoint])
	print key

	#extracting value
	valueLength = pkt[Memcached].total_length - pkt[Memcached].key_length - pkt[Memcached].extras_length
	valueEndPoint = (valueLength*2) + keyEndPoint
	value =  string_from_int(stringVersion[keyEndPoint:valueEndPoint])
	print value
	
	setOperation(key,value)

	#now need to send back a packet
	oldPacket = pkt
	pktNew = pkt

	padlength = len(pktNew[Raw].load)
	pktNew[Raw].load = ""

	pktNew[UDP].len += len(pad32(pktNew)) - len(pktNew) - padlength
	pktNew[IP].len += len(pad32(pktNew)) - len(pktNew) - padlength

	pktNew[Memcached].magic = 129
	pktNew[Memcached].key_length = 0
	pktNew[Memcached].extras_length = 0
	pktNew[Memcached].total_length = 0

	oldEthSrc = pkt[Ether].src
	oldEthDst = pkt[Ether].dst
	pktNew[Ether].src = oldEthDst
	pktNew[Ether].dst  = oldEthSrc

	oldIPSrc = pkt[IP].src
	oldIPDst = pkt[IP].dst
	pktNew[IP].src = oldIPDst
	pktNew[IP].dst = oldIPSrc

	del pktNew[IP].chksum
	#pktNew.show2()
	pktNew = pktNew.__class__(str(pktNew))


	print "set - new packet"
	#hexdump(pktNew)
	pktNew.show()
	print "LEN END: ", len(pktNew), " -> pad: ", len(pad32(pktNew))
	sendp(pad32(pktNew),iface = "eth2")

def returningGetPacket(pkt,flag,value,key):
	pktNew = pkt



	if flag == 0:
		#means key not in memcached client
		padlength = len(pktNew[Raw].load)
		pktNew[Raw].load = ""

		pktNew[UDP].len += len(pad32(pktNew)) - len(pktNew) - padlength
		pktNew[IP].len += len(pad32(pktNew)) - len(pktNew) - padlength

		pktNew[Memcached].magic = 129
		pktNew[Memcached].key_length = 0
		pktNew[Memcached].extras_length = 0
		pktNew[Memcached].total_length = 0
		pktNew[Memcached].vbucket_id = 1

		oldEthSrc = pkt[Ether].src
		oldEthDst = pkt[Ether].dst
		pktNew[Ether].src = oldEthDst
		pktNew[Ether].dst  = oldEthSrc

		oldIPSrc = pkt[IP].src
		oldIPDst = pkt[IP].dst
		pktNew[IP].src = oldIPDst
		pktNew[IP].dst = oldIPSrc

		del pktNew[IP].chksum
		#pktNew.show2()
		pktNew = pktNew.__class__(str(pktNew))
		pktNew.show()

	if flag == 1:
		#get successful

		padlength = len(pktNew[Raw].load)
		pktNew[Raw].load = ""

		pktNew[UDP].len += len(pad32(pktNew)) - len(pktNew) - padlength
		pktNew[IP].len += len(pad32(pktNew)) - len(pktNew) - padlength

		pktNew[Memcached].magic = 129
		pktNew[Memcached].key_length = 0
		pktNew[Memcached].vbucket_id = 0
		pktNew[Memcached].extras_length = 4
		pktNew[Memcached].total_length = 4 + len(value)		

		oldEthSrc = pkt[Ether].src
		oldEthDst = pkt[Ether].dst
		pktNew[Ether].src = oldEthDst
		pktNew[Ether].dst  = oldEthSrc

		oldIPSrc = pkt[IP].src
		oldIPDst = pkt[IP].dst
		pktNew[IP].src = oldIPDst
		pktNew[IP].dst = oldIPSrc
		print "type ", type(value)
		pktNew = pktNew / '\x00\x00\x00\x00'
		pktNew =pktNew / value

		del pktNew[IP].chksum
		#pktNew.show2()
		pktNew = pktNew.__class__(str(pktNew))
		pktNew.show()
	
	if flag == 2:
		print "flag is 2"
		padlength = len(pktNew[Raw].load)
		pktNew[Raw].load = ""

		pktNew[UDP].len += len(pad32(pktNew)) - len(pktNew) - padlength
		pktNew[IP].len += len(pad32(pktNew)) - len(pktNew) - padlength

		pktNew[Memcached].magic = 129
		pktNew[Memcached].key_length = len(key)
		pktNew[Memcached].vbucket_id = 0
		pktNew[Memcached].extras_length = 4
		print key
		print value
		pktNew[Memcached].total_length = 4 + len(key) + len(value)		
		
		oldEthSrc = pkt[Ether].src
		oldEthDst = pkt[Ether].dst
		pktNew[Ether].src = oldEthDst
		pktNew[Ether].dst  = oldEthSrc

		oldIPSrc = pkt[IP].src
		oldIPDst = pkt[IP].dst
		pktNew[IP].src = oldIPDst
		pktNew[IP].dst = oldIPSrc
		
		pktNew = pktNew / '\x00\x00\x00\x00'
		pktNew = pktNew / key
		pktNew = pktNew / value

		del pktNew[IP].chksum
		#pktNew.show2()
		pktNew = pktNew.__class__(str(pktNew))
		#pktNew.show()
		

	sendp(pad32(pktNew),iface = "eth2")
		

def getPacket(pkt):
	raw = pkt.lastlayer()
	stringVersion = str(raw).encode("HEX")
	pkt.show()
	print stringVersion

	keyLength = pkt[Memcached].key_length
	keyLengthForHex = keyLength *2
	keyEndPoint =  0 +  keyLengthForHex
	key =  string_from_int(stringVersion[0:keyEndPoint])
	print key
	
	value = getOperation(key)
	
	print value

	if value  is None:
		
		returningGetPacket(pkt,0,0,0)
	else:
		if pkt[Memcached].opcode == 0:
			returningGetPacket(pkt,1,value,key)
		else:
			print("get K packet")
			returningGetPacket(pkt,2,value,key)

def newNothingReplyPacket(pkt,raw):
	oldPacket = pkt
	pktNew = pkt

	padlength = len(pktNew[Raw].load)
	pktNew[Raw].load = ""

	pktNew[UDP].len += len(pad32(pktNew)) - len(pktNew) - padlength
	pktNew[IP].len += len(pad32(pktNew)) - len(pktNew) - padlength

	pktNew[Memcached].magic = 129
	pktNew[Memcached].key_length = 0
	pktNew[Memcached].extras_length = 0
	pktNew[Memcached].total_length = 0

	oldEthSrc = pkt[Ether].src
	oldEthDst = pkt[Ether].dst
	pktNew[Ether].src = oldEthDst
	pktNew[Ether].dst  = oldEthSrc

	oldIPSrc = pkt[IP].src
	oldIPDst = pkt[IP].dst
	pktNew[IP].src = oldIPDst
	pktNew[IP].dst = oldIPSrc

	del pktNew[IP].chksum
	#pktNew.show2()
	pktNew = pktNew.__class__(str(pktNew))


	#print "generic - new packet"
	#hexdump(pktNew)
	#pktNew.show()
	return pktNew

def deletePacket(pkt):
	raw = pkt.lastlayer()
	stringVersion = str(raw).encode("HEX")
	pkt.show()
	print stringVersion

	keyLength = pkt[Memcached].key_length
	keyLengthForHex = keyLength *2
	keyEndPoint =  0 +  keyLengthForHex
	key =  string_from_int(stringVersion[0:keyEndPoint])
	
	client.delete(key)

	pktNew = newNothingReplyPacket(pkt,raw)

	sendp(pad32(pktNew),iface = "eth2")

def flushCache(pkt):
	raw = pkt.lastlayer()
	stringVersion = str(raw).encode("HEX")
	#pkt.show()
	#print stringVersion

	#extract expiration

	expirationTime = int(stringVersion[0:8],16)
	#print expirationTime
	client.flush_all(expirationTime)

	pktNew = newNothingReplyPacket(pkt,raw)
	
	sendp(pad32(pktNew),iface = "eth2")

def noOperation(pkt):
	raw = pkt.lastlayer()
	stringVersion = str(raw).encode("HEX")
	pktNew = newNothingReplyPacket(pkt,raw)
	sendp(pad32(pktNew),iface = "eth2")

def error(pkt):
	raw = pkt.lastlayer()
	stringVersion = str(raw).encode("HEX")
	#pktNew = newNothingReplyPacket(pkt,raw)


	#oldPacket = pkt
	pktNew = pkt

	padlength = len(pktNew[Raw].load)
	pktNew[Raw].load = ""

	pktNew[UDP].len += len(pad32(pktNew)) - len(pktNew) - padlength
	pktNew[IP].len += len(pad32(pktNew)) - len(pktNew) - padlength

	pktNew[Memcached].magic = 129
	pktNew[Memcached].key_length = 0
	pktNew[Memcached].extras_length = 0
	pktNew[Memcached].total_length = 0
	pktNew[Memcached].vbucket_id = 131

	oldEthSrc = pkt[Ether].src
	oldEthDst = pkt[Ether].dst
	pktNew[Ether].src = oldEthDst
	pktNew[Ether].dst  = oldEthSrc

	oldIPSrc = pkt[IP].src
	oldIPDst = pkt[IP].dst
	pktNew[IP].src = oldIPDst
	pktNew[IP].dst = oldIPSrc

	del pktNew[IP].chksum
	#pktNew.show2()
	pktNew = pktNew.__class__(str(pktNew))


	print "error - new packet"
	#hexdump(pktNew)
	#pktNew.show()
	sendp(pad32(pktNew),iface = "eth2")
	#return pktNew


def recievingPackets(pkt):
	#print("hello")
	if Memcached not in pkt:
		print "not a memcache packet"
		return
	#print "recieved packet"
	
	#pkt.show()
	global iterator
	iterator = iterator + 1 
	print iterator
	if pkt[Memcached].magic == 129:
		#print "return packet"
		#pkt.show()
		return

	elif pkt[Memcached].opcode == 1:
		#set packet
		setPacket(pkt)

	elif pkt[Memcached].opcode == 0 or pkt[Memcached].opcode == 12:
		#this is a get or getK packet
		getPacket(pkt)

	elif pkt[Memcached].opcode == 4:

		#this is a delete packet
		print("delete packet")
		deletePacket(pkt)

	elif pkt[Memcached].opcode == 8:
		#this is flush
		print "flush"
		flushCache(pkt)
	elif pkt[Memcached].opcode == 10:
		#no - op
		noOperation(pkt)
	else:
		#return only the header with the vbucket id = 131, clear to all to length
		print "error"	
		error(pkt)
		

	#oldPacket[Memcached].remove_payload()
	#pktNew  /= oldPacket
	#pktNew.opcode = 8
	#print "before"
	#print pktNew.show()
	#print hexdump(pkt.lastlayer().remove_payload() )

#sniffedpkts = []
#def timer0():
#	recievingPackets(sniffedpkts.pop())
#def doonsniff(x):
#	sniffedpkts.append(x)
#	Timer(0, timer0).start()
iterator = 0
def main():
	#sniff(iface="eth2", prn=doonsniff, count=0)
        #sniff(iface="eth2", prn=recievingPackets, count=0)
	#sniff(iface="eth2", prn=recievingPackets, opened_socket=L2ListenTcpdump(), count=0)
	cap = pcapy.open_live("eth2",65536,True,0)
	iterator = 0
	
	try:
		while(True):
			header,payload = cap.next()
			iterator = iterator +1
			#print type(payload)
			#pkt = Ether()/IP()/UDP()/Memcached()
			pkt = Ether(payload)
			pkt.show()
			#print pkt[Memcached].summary()
			#print pkt.summary()
			#print list(expand(pkt))
			recievingPackets(pkt)
	
	#except pcapy.PcapError:
	#	print "error"
	except KeyboardInterrupt:
		print "interrupt"


if __name__ == "__main__":
    main()
