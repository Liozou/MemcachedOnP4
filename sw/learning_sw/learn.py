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


import sys, os
sys.path.append(os.path.expandvars('$P4_PROJECT_DIR/testdata/'))
from sss_digest_header import *
import numpy as np
sys.path.append(os.path.expandvars('$P4_PROJECT_DIR/sw/CLI/'))
from p4_tables_api import *


from pprint import pprint
import collections
from collections import OrderedDict
"""
This is the learning switch software that adds the appropriate
entries to the forwarding and smac tables
"""

DMA_IFACE = 'nf0'
DIG_PKT_LEN = 32 # 32 bytes, 256 bits

forward_tbl = {}
smac_tbl = {}

class cacheHandler:
    def __init__(self,numberOfFreeSpaces):
	self.freeSpaces = np.zeros(numberOfFreeSpaces)
	self.lruTracker = OrderedDict()
	self.nextFree = 0

    def flagSpaceTaken(self,address):
	self.freeSpaces[address] = 1

    def flagSpaceFree(self,address):
	self.freeSpaces[address] = 0

    def refresh(self,key):
       	try:
		value = self.lruTracker.pop(key)
		self.lruTracker[key] =value
	except KeyError:
		print "error"

    def addEntry(self,key,usedAddress):

	self.lruTracker[key] = usedAddress
        self.flagSpaceTaken(usedAddress)

    def deleteEntry(self,key):
	try:
		value = self.lruTracker.pop(key)
		self.flagSpaceFree(value)
	except KeyError:
		print "trying delete when there is no entry"

    def findNextFree(self):
	nextAvailableIndexes = np.where(self.freeSpaces == 0)
	if np.array(nextAvailableIndexes)[0].shape[0] != 0:
		self.nextFree = nextAvailableIndexes[0][0]
		return nextAvailableIndexes[0][0]
	else:

		lru = self.lruTracker.popitem(last=False)
		key = lru[0]
		value = lru[1]
		self.flagSpaceFree(value)
		self.nextFree = value
		return value

    def isKeyInStore(self,key):
	if key in self.lruTracker:
		return 1
	else:
		return 0

    def flush(self):
	for key,val in self.lruTracker.items():

		(found, val) = table_cam_read_entry('MemcachedControl_memcached_keyvalue_0', [key])
    		if found == "True":
			print "flushing" 
        		table_cam_delete_entry('MemcachedControl_memcached_keyvalue_0',[key])	
		self.deleteEntry(key)
	#reset
	self.freeSpaces = np.zeros(len(self.freeSpaces))
        self.nextFree = 0

slabOneHandler = cacheHandler(256)
slabTwoHandler = cacheHandler(128)
slabThreeHandler = cacheHandler(64)


globalNextAvailableAddressOne = 0
globalNextAvailableAddressTwo = 0
globalNextAvailableAddressThree = 0

#0 means its not taken and is free to use
#slabOneFree = np.zeros(256)
#slabTwoFree = np.zeros(128)
#slabThreeFree = np.zeros(64)


def print_dig_pkt(dig_pkt):
    print "Received Digest packet: "
    print "\tsrc_port = ", bin(dig_pkt.src_port)
    print "\teth_src_addr = ", hex(dig_pkt.eth_src_addr)
    print "\tflags = ", bin(dig_pkt.flags)
    print "\treg_addr = ", dig_pkt.reg_addr
    print "\tvalue_size_out = ", dig_pkt.value_size_out
    print "\texpiration = ", dig_pkt.expiration
    print "\tkey = ", string_from_int(dig_pkt.key)
    print "\topcode = ", hex(dig_pkt.opcode)
    print "\tmagic = ", hex(dig_pkt.magic)
    print "prn pkt = ",
    hexdump(dig_pkt)
    print "###################################"


def string_from_int(n):
    s = ""
    l = hex(n)[2:]
    if len(l)%2:
        l = '0' + l
    for i in range(len(l)/2):
        s += chr(int(l[2*i:2*i+2], 16))
    return s

counter = 0
def learn_digest(pkt):
    global counter
    counter += 1
    print "COUNTER: ", counter
    dig_pkt = Digest_data(str(pkt))
    print "\n\n\n\n\n\n\n"
    if len(dig_pkt) != DIG_PKT_LEN:
        return
    print_dig_pkt(dig_pkt)
   # delete_value(dig_pkt)
   # print_out_tables()
   #read_value(dig_pkt)

    flags = bin(dig_pkt.flags)
    flags =  str(flags)
    lastFlag =  str(flags)[-1]
    secondLastFlag = str(flags)[-2]
    thirdLastFlag = str(flags)[-3]

    if lastFlag == "1":
	print "set last"
	delete_register_table_slab(dig_pkt)
    if secondLastFlag == "1":
        print "set second"
	update_register_table(dig_pkt)
    if thirdLastFlag == "1":
        print "set third"
	#save_source_port(dig_pkt)
        add_to_tables(dig_pkt)


#    address_value = dig_pkt.reg_addr
    memCacheOpCode = dig_pkt.opcode
    memCacheMagic = dig_pkt.magic
    slabSize = find_slab_size(dig_pkt.value_size_out)
    key = dig_pkt.key
    if memCacheOpCode == 1 and memCacheMagic == 128:
	#set operation - update
	add_to_memcached_key_value(dig_pkt)

    if (memCacheOpCode == 0 or memCacheOpCode == 1) and memCacheMagic == 128:
        #this  is  Get operation(0) or a Set operation (1) - therfore need update LRU cache handler
#       slabSizeId = find_slab_size(dig_pkt.value_size_out)
	if slabSize == 1:
	     slabOneHandler.refresh(key)
	elif slabSize == 2:
             slabTwoHandler.refresh(key)
   	elif slabSize == 3:
             slabThreeHandler.refresh(key)
#    elif memCacheOpCode == 4:
        # this is DELETE operation - remove from key value table
#	delete_register_table_slab(dig_pkt)

    if memCacheOpCode == 8 :
	#flush operation
	flush()

def flush():

	slabOneHandler.flush()

	(found, val) = table_cam_read_entry('MemcachedControl_register_address_0',[1])
	if (found == 'True'):
		table_cam_delete_entry('MemcachedControl_register_address_0',[1])
        table_cam_add_entry('MemcachedControl_register_address_0', [1], 'MemcachedControl.set_register_address', [1])


	slabTwoHandler.flush()

	(found, val) = table_cam_read_entry('MemcachedControl_register_address_0',[2])
        if (found == 'True'):
                table_cam_delete_entry('MemcachedControl_register_address_0',[2])
        table_cam_add_entry('MemcachedControl_register_address_0', [2], 'MemcachedControl.set_register_address', [2])

	slabThreeHandler.flush()

	(found, val) = table_cam_read_entry('MemcachedControl_register_address_0',[3])
        if (found == 'True'):
                table_cam_delete_entry('MemcachedControl_register_address_0',[3])
        table_cam_add_entry('MemcachedControl_register_address_0', [3], 'MemcachedControl.set_register_address', [3])

def find_slab_size(size):
    if size <= 8 :
	return 1
    elif size >8 and size <= 16:
        return 2
    elif size>16:
        return 3

def find_next_available(slabSize):

   if slabSize == 1:
	return slabOneHandler.findNextFree() 
   elif slabSize == 2:
	return slabTwoHandler.findNextFree()
   elif slabSize == 3:
	return slabThreeHandler.findNextFree()

def delete_register_table_slab(dig_pkt):
    # last bit is set
    key = dig_pkt.key
    address_value = dig_pkt.reg_addr
    #value_size = dig_pkt.value_size_out

    ##will need to find slab size based upon key

    slabSizeId = find_slab_size(dig_pkt.value_size_out)


    (found, val) = table_cam_read_entry('MemcachedControl_memcached_keyvalue_0', [key])
    if found == "True":
	table_cam_delete_entry('MemcachedControl_memcached_keyvalue_0',[key])

    if slabOneHandler.isKeyInStore(key)  == 1:
	slabOneHandler.deleteEntry(key)

    if slabTwoHandler.isKeyInStore(key) == 1:
	slabTwoHandler.deleteEntry(key)

    if slabThreeHandler.isKeyInStore(key) == 1:
	slabThreeHandler.deleteEntry(key)

    #address is now free to use!
#    if slabSizeId == 1:
#        return slabOneHandler.flagSpaceFree(address_value)
#    elif slabSizeId == 2:
#        return slabTwoHandler.findNextFree(address_value)
#    elif slabSizeId == 3:
#        return slabThreeHandler.findNextFree(address_value)


def add_to_memcached_key_value(dig_pkt):
    #require key ,adress,value_size

    key = dig_pkt.key
    address_value = dig_pkt.reg_addr
    value_size = dig_pkt.value_size_out

    (found, val) = table_cam_read_entry('MemcachedControl_memcached_keyvalue_0', [key])
    if (found == 'False'):
 	table_cam_add_entry('MemcachedControl_memcached_keyvalue_0', [key], 'MemcachedControl.set_stored_info', [address_value,value_size])
    else:
	table_cam_delete_entry('MemcachedControl_memcached_keyvalue_0',[key])
	table_cam_add_entry('MemcachedControl_memcached_keyvalue_0', [key], 'MemcachedControl.set_stored_info', [address_value,value_size])


def add_entry_to_cache_handler(slabSizeId,key,address):
    if slabSizeId == 1:
        slabOneHandler.addEntry(key,address)
    elif slabSizeId == 2:
        slabTwoHandler.addEntry(key,address)
    elif slabSizeId == 3:
        slabThreeHandler.addEntry(key,address)

def update_register_table(dig_pkt):
    # when the second to last bit is set it means we need to update the register adresss table

    # must find slab size of request
    slabSizeId = find_slab_size(dig_pkt.value_size_out)
    

    #gets the address of the value that has just been used.
    if slabSizeId == 1:

        justUsed = slabOneHandler.nextFree 
    
    elif slabSizeId == 2:
        justUsed = slabTwoHandler.nextFree 

    elif slabSizeId == 3:
        justUsed = slabThreeHandler.nextFree 


#    table_cam_add_entry('MemcachedControl_register_address_0', [5], 'MemcachedControl.set_register_address', [101])
#    (found, val) = table_cam_read_entry('MemcachedControl_register_address_0',[5])

#    (found, val) = table_cam_read_entry('MemcachedControl_register_address_0',[slabSizeId])
    # need to post-proces val!!!!!!!!!!!!#############################################
#    print "in update register"
#    print val
#    print found

    #Therefore we now have to indicate in our store that this is now not free and then find the next free one
    add_entry_to_cache_handler(slabSizeId,dig_pkt.key,justUsed)

    # then must find the next new available register
    nextAvailable = find_next_available(slabSizeId)

    #to update you have to delete and then add  <key = slabSizeId>

    #if (found == 'True'):
    #	table_cam_delete_entry('MemcachedControl_register_address_0',[slabSizeId])

    table_cam_add_entry('MemcachedControl_register_address_0', [slabSizeId], 'MemcachedControl.set_register_address', [nextAvailable])

    #also add to memcached key value
    add_to_memcached_key_value(dig_pkt)

def save_source_port(dig_pkt):
    #add this as normal - when 3rd last flag is set
    add_to_tables(dig_pkt)

def add_to_tables(dig_pkt):
    src_port = dig_pkt.src_port
    eth_src_addr = dig_pkt.eth_src_addr

    (found, val) = table_cam_read_entry('smac', [eth_src_addr])
    print(eth_src_addr)
    print type(eth_src_addr)
    if (found == 'False'):

        print 'Adding entry: ({0}, set_output_port, {1}) to the forward table'.format(hex(eth_src_addr), bin(src_port))
        table_cam_add_entry('forward', [eth_src_addr], 'set_output_port', [src_port])
        print 'Adding entry: ({0}, NoAction, []) to the smac table'.format(hex(eth_src_addr))
        table_cam_add_entry('smac', [eth_src_addr], 'NoAction', [])
    else:
        print "Entry: ({0}, set_output_port, {1}) is already in the tables".format(hex(eth_src_addr), bin(src_port))

def print_out_tables():
    for table_name,table in PX_CAM_TABLES.items():
        print table_name
        pprint(table.info)

def read_value(dig_pkt):
     src_port = dig_pkt.src_port
     eth_src_addr = dig_pkt.eth_src_addr
     (found,val) = table_cam_read_entry('forward',[eth_src_addr])
     print "############################################"
     print found
     print bin(src_port)
     print hex(src_port)
     print src_port
     print bin(int(val,16))
     print int(val)
     print "############################################"
     return val

def delete_value(dig_pkt):
    src_port = dig_pkt.src_port
    eth_src_addr = dig_pkt.eth_src_addr

    table_cam_delete_entry('forward',[eth_src_addr])
    table_cam_delete_entry('smac',[eth_src_addr])

def update_value(dig_pkt):
    src_port = dig_pkt.src_port
    eth_src_addr = dig_pkt.eth_src_addr
    (found, val) = table_cam_read_entry('forward', [eth_src_addr])
    if (found == 'False'):
         add_to_tables(dig_pkt)
    else:
         delete_value(dig_pkt)
         add_to_tables(dig_pkt)


def main():
    sniff(iface=DMA_IFACE, prn=learn_digest, count=0)


if __name__ == "__main__":
    main()
