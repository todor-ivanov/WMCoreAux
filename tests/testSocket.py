import socket
import pdb
from pprint import pprint
from time import sleep
from os import getpid

print("PID: %s" % getpid())
pdb.set_trace()
while True:
    addrinfo=[]
    addrinfo=socket.getaddrinfo('cmsweb.cern.ch', 443, 0, 0, socket.IPPROTO_TCP)
    print(addrinfo)
    sleep(1)
    
