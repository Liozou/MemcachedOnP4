
from NFTest import *

NUM_WRITES = 60

def config_tables():
    nftest_regwrite(0x44020050, 0x11111108)
    nftest_regwrite(0x44020054, 0x00000811)
    nftest_regwrite(0x44020080, 0x00000101)
    nftest_regwrite(0x44020040, 0x00000001)
    nftest_regwrite(0x44020050, 0x22222208)
    nftest_regwrite(0x44020054, 0x00000822)
    nftest_regwrite(0x44020080, 0x00000104)
    nftest_regwrite(0x44020040, 0x00000001)
    nftest_regwrite(0x44020050, 0x33333308)
    nftest_regwrite(0x44020054, 0x00000833)
    nftest_regwrite(0x44020080, 0x00000110)
    nftest_regwrite(0x44020040, 0x00000001)
    nftest_regwrite(0x44020050, 0x44444408)
    nftest_regwrite(0x44020054, 0x00000844)
    nftest_regwrite(0x44020080, 0x00000140)
    nftest_regwrite(0x44020040, 0x00000001)
    nftest_regwrite(0x44020050, 0xffffffff)
    nftest_regwrite(0x44020054, 0x0000ffff)
    nftest_regwrite(0x44020080, 0x00000155)
    nftest_regwrite(0x44020040, 0x00000001)
    nftest_regwrite(0x44020150, 0x00000001)
    nftest_regwrite(0x44020180, 0x00000154)
    nftest_regwrite(0x44020140, 0x00000001)
    nftest_regwrite(0x44020150, 0x00000004)
    nftest_regwrite(0x44020180, 0x00000151)
    nftest_regwrite(0x44020140, 0x00000001)
    nftest_regwrite(0x44020150, 0x00000010)
    nftest_regwrite(0x44020180, 0x00000145)
    nftest_regwrite(0x44020140, 0x00000001)
    nftest_regwrite(0x44020150, 0x00000040)
    nftest_regwrite(0x44020180, 0x00000115)
    nftest_regwrite(0x44020140, 0x00000001)
    nftest_regwrite(0x44020250, 0x11111108)
    nftest_regwrite(0x44020254, 0x00000811)
    nftest_regwrite(0x44020280, 0x00000001)
    nftest_regwrite(0x44020240, 0x00000001)
    nftest_regwrite(0x44020250, 0x22222208)
    nftest_regwrite(0x44020254, 0x00000822)
    nftest_regwrite(0x44020280, 0x00000001)
    nftest_regwrite(0x44020240, 0x00000001)
    nftest_regwrite(0x44020250, 0x33333308)
    nftest_regwrite(0x44020254, 0x00000833)
    nftest_regwrite(0x44020280, 0x00000001)
    nftest_regwrite(0x44020240, 0x00000001)
    nftest_regwrite(0x44020250, 0x44444408)
    nftest_regwrite(0x44020254, 0x00000844)
    nftest_regwrite(0x44020280, 0x00000001)
    nftest_regwrite(0x44020240, 0x00000001)
    nftest_regwrite(0x44020250, 0xffffffff)
    nftest_regwrite(0x44020254, 0x0000ffff)
    nftest_regwrite(0x44020280, 0x00000001)
    nftest_regwrite(0x44020240, 0x00000001)
    nftest_regwrite(0x44020350, 0x65737431)
    nftest_regwrite(0x44020354, 0x005f5f74)
    nftest_regwrite(0x44020380, 0x00002547)
    nftest_regwrite(0x44020340, 0x00000001)
    nftest_regwrite(0x44020350, 0x65737432)
    nftest_regwrite(0x44020354, 0x005f5f74)
    nftest_regwrite(0x44020380, 0x0000257f)
    nftest_regwrite(0x44020340, 0x00000001)
