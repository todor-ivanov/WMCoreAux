#!/usr/bin/env python
"""
A simple test function for debugging the wrong behaviour of 'pycurl' which ignores
the 'nscd' cache for DNS lookup.

In order to test this one needs to download the wrong versions of packages and
libraries from the cms repository. Execute the following short script:

$ /bin/bash <<EOF

mkdir tmp
cd tmp

git clone https://github.com/todor-ivanov/auxiliary.git
git clone https://github.com/dmwm/WMCore.git

cd auxiliary/tests
ln -s ../../WMCore

externalsList="
http://cmsrep.cern.ch/cmssw/repos/comp/slc7_amd64_gcc630/0000000000000000000000000000000000000000000000000000000000000000/RPMS/4c/4c03fda0be1e3bf4a2ce613e219f1f9d/external+py2-pycurl+7.19.3-comp2-1-1.slc7_amd64_gcc630.rpm
http://cmsrep.cern.ch/cmssw/repos/comp/slc7_amd64_gcc630/0000000000000000000000000000000000000000000000000000000000000000/RPMS/8c/8c898b53952d5764122d147b16d73640/external+curl+7.35.0-comp-1-1.slc7_amd64_gcc630.rpm
http://cmsrep.cern.ch/cmssw/repos/comp/slc7_amd64_gcc630/0000000000000000000000000000000000000000000000000000000000000000/RPMS/47/479142d10113bbc29861464ede0fe0d6/external+openssl+1.0.1r-comp-1-1.slc7_amd64_gcc630.rpm
http://cmsrep.cern.ch/cmssw/repos/comp/slc7_amd64_gcc630/0000000000000000000000000000000000000000000000000000000000000000/RPMS/83/8394096dfb7c2bb467149bb50d25b50b/external+c-ares+1.10.0-1-1.slc7_amd64_gcc630.rpm
"
mkdir external
cd external
for i in \$externalsList; do wget \$i; done
for i in *.rpm ; do rpm2cpio \$i |cpio -idmv; done
cd ../
EOF
"""

import os, sys
import json
import pdb
from pprint import pprint
from time import sleep
print("PID: %s" % os.getpid())

useExternals=True

if useExternals is True:
    externalPath='./external/build/dmwmbld/srv/state/dmwmbld/builds/comp_gcc630/w/\
slc7_amd64_gcc630/external/'
    pycurlPath =os.path.join(externalPath,
                             'py2-pycurl/7.19.3-comp2/lib/python2.7/site-packages/')
    libcurlPath=os.path.join(externalPath,
                             'curl/7.35.0-comp/lib/')
    opensslPath=os.path.join(externalPath,
                             'openssl/1.0.1r-comp/lib/')
    caresPath  =os.path.join(externalPath,
                             'c-ares/1.10.0/lib/')
    ld_library_path=libcurlPath + ':' + opensslPath + ':' + caresPath

if 'LD_LIBRARY_PATH' not in os.environ:
    try:
        libcurlPath
    except NameError:
        pass
    else:
        os.environ['LD_LIBRARY_PATH'] = ld_library_path
        try:
            os.execv(sys.argv[0], sys.argv)
        except Exception, exc:
            print('Failed re-exec: %s' % exc)
            sys.exit(1)

try:
    pycurlPath
except NameError:
    pass
else:
    if pycurlPath not in sys.path:
        sys.path.insert(0, pycurlPath)

from WMCore.Services.pycurl_manager import RequestHandler
from pycurl import version_info, version

# print('cwd: %s' % os.getcwd())
# print('LD_LIBRARY_PATH: %s' % os.environ['LD_LIBRARY_PATH'])
# print('PYTHONPATH:' % (sys.path))
# print("curl version_info is:")
# pprint(version_info())
print('pycurl version: %s' % version)


url='https://cmsweb-testbed.cern.ch/reqmgr2/requests?status=rejected'
params={}
# ckey = os.path.join(os.environ['HOME'], '.globus/userkey.pem')
# cert = os.path.join(os.environ['HOME'], '.globus/usercert.pem')
ckey = os.path.join(os.environ['HOME'], '.globus/userproxy.pem')
cert = os.path.join(os.environ['HOME'], '.globus/userproxy.pem')

def makeRequest(url, params):
    mgr=RequestHandler()
    header, data = mgr.request(url, params, ckey=ckey, cert=cert)
    if header.status != 200:
        print "ERROR"
    return data

pdb.set_trace()

while True:
    data=makeRequest(url, params)
    pprint(data)
    sleep(1)
