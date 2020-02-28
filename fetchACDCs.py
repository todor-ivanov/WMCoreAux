#!/usr/bin/env python
from __future__ import print_function

import argparse
import httplib
import json
import os
import pwd
import sys
import urllib
import urllib2
import re
import numpy as np

from pprint import pprint
from urllib2 import HTTPError, URLError
from textwrap import TextWrapper
from collections import OrderedDict

# URL for ACDCs
# https://cmsweb-testbed.cern.ch/reqmgr2/data/request?request_type=Resubmission&mask=TotalEstimatedJobs

# table parameters
SEPARATELINE = "|" + "-" * 51 + "|"
SPLITLINE = "|" + "*" * 51 + "|"

# ID for the User-Agent
CLIENT_ID = 'fetchACDC/0.1::python/%s.%s' % sys.version_info[:2]

# Cached DQMGui data
cachedDqmgui = None


class HTTPSClientAuthHandler(urllib2.HTTPSHandler):
    """
    Basic HTTPS class
    """

    def __init__(self, key, cert):
        urllib2.HTTPSHandler.__init__(self)
        self.key = key
        self.cert = cert

    def https_open(self, req):
        # Rather than pass in a reference to a connection class, we pass in
        # a reference to a function which, for all intents and purposes,
        # will behave as a constructor
        return self.do_open(self.getConnection, req)

    def getConnection(self, host, timeout=290):
        return httplib.HTTPSConnection(host, key_file=self.key, cert_file=self.cert)


def getX509():
    "Helper function to get x509 from env or tmp file"
    proxy = os.environ.get('X509_USER_PROXY', '')
    if not proxy:
        proxy = '/tmp/x509up_u%s' % pwd.getpwuid(os.getuid()).pw_uid
        if not os.path.isfile(proxy):
            return ''
    return proxy


def getContent(url, params=None):
    cert = getX509()
    client = '%s (%s)' % (CLIENT_ID, os.environ.get('USER', ''))
    handler = HTTPSClientAuthHandler(cert, cert)
    opener = urllib2.build_opener(handler)
    opener.addheaders = [("User-Agent", client),
                         ("Accept", "application/json")]
    try:
        response = opener.open(url, params)
        output = response.read()
    except HTTPError as e:
        print("The server couldn't fulfill the request at %s" % url)
        print("Error code: ", e.code)
        output = '{}'
        # sys.exit(1)
    except URLError as e:
        print('Failed to reach server at %s' % url)
        print('Reason: ', e.reason)
        sys.exit(2)
    return output






def twClosure(replaceWhiteSpace=False,
              breakLongWords=False,
              width=120,
              initialIndent=''):
    """
    Deals with indentation of dictionaries with very long key, value pairs.
    params: look at TextWrapper documentation

    Wraps all strings for both keys and values to 120 chars.
    Uses 4 spaces indentation for both keys and values.
    Nested dictionaries and lists go to next line.
    """
    twr = TextWrapper(replace_whitespace=replaceWhiteSpace,
                      break_long_words=breakLongWords,
                      width=width,
                      initial_indent=initialIndent)

    def twEnclosed(obj, ind=''):
        """
        The inner function of the closure
        """
        output = ''
        if isinstance(obj, dict):
            obj = OrderedDict(sorted(obj.items(),
                                     key=lambda t: t[0],
                                     reverse=False))
            output += '\n'
            ind += '    '
            for key, value in obj.iteritems():
                output += "%s%s: %s\n" % (ind,
                                          ''.join(twr.wrap(key)),
                                          twEnclosed(value, ind))
        elif isinstance(obj, list):
            output += '\n'
            ind += '    '
            for value in obj:
                output += "%s%s\n" % (ind, twEnclosed(value, ind))
        else:
            output += "%s" % ''.join(twr.wrap(str(obj)))
        # TODO: On every recursive call an additional '\n' is accumulated at the
        #       end of the 'output' string. We may use the regexp mentioned
        #       bellow to clean it, but it also strips the '\n's between nested
        #       dicts/lists, which emphasizes them better.
        output = re.sub(r'(\n+)', r"\n", output)
        return output
    return twEnclosed


def twPrint(obj):
    """
    A simple caller of twClosure (see docstring for twClosure)
    """
    twPrinter = twClosure()
    print(twPrinter(obj))


def getACDC(baseUrl, reqName=None , api=None):
    """
    gets information for ACDC Workflows from reqmgr2
    """
    mask = '&mask=' + api
    urn = baseUrl +  '/reqmgr2/data/request?request_type=Resubmission' + mask
    if reqName:
        reqmgrOutput = json.loads(getContent(urn))['result'][0][reqName]
    else:
        reqmgrOutput = json.loads(getContent(urn))['result'][0]
    return reqmgrOutput


def main():
    """
    Requirements: you need to have your proxy and proper x509 environment
     variables set.

    Fetches all the ACDCs from reqmgr using the given a central services instance
    default is cmsweb-testbed.cern.ch

    """
    parser = argparse.ArgumentParser(description="Validate workflow input, output and config")
    # group = parser.add_mutually_exclusive_group()
    parser.add_argument('-p', '--plot', help='Plot the output before saving to file.', action="store_true")
    parser.add_argument('-o', '--output', help='A file name for the ouput. Default: acdcsEstimJobs.json ')
    parser.add_argument('-c', '--cms', help='CMSWEB url to talk to DBS/PhEDEx/Reqmgr2. Default: cmsweb-testbed.cern.ch')
    parser.add_argument('-r', '--reqmgr', help='Request Manager URL. Default: cmsweb-testbed.cern.ch')
    parser.add_argument('-v', '--verbose', help='Increase output verbosity - prints the output before saving it to file', action="store_true")

    args = parser.parse_args()

    plot = True if args.plot else False
    verbose = True if args.verbose else False
    outputFile = args.output if args.output else 'acdcsEstimJobs.json'
    cmswebUrl = "https://" + args.cms if args.cms else "https://cmsweb-testbed.cern.ch"
    reqmgrUrl = "https://" + args.reqmgr if args.reqmgr else "https://cmsweb-testbed.cern.ch"

    api = 'TotalEstimatedJobs'
    TotalEstimatedJobsAll = []
    acdcs=getACDC(baseUrl=reqmgrUrl, api=api)

    if verbose:
        twPrint(acdcs)

    for wf, value in acdcs.items():
        if value['TotalEstimatedJobs']:
            TotalEstimatedJobsAll.append(value['TotalEstimatedJobs'])

    TotalEstimatedJobsSample = {
        "0": {'n': 0,
              'sample': TotalEstimatedJobsAll,
              'eta': 0.9,
              'm': 0,
              'sigma': 0 }}

    with open(outputFile, 'w') as fp:
        json.dump(TotalEstimatedJobsSample, fp)

    
   # pprint(TotalEstimatedJobsSample)

    # TotalEstimatedJobsAllNP=np.array(TotalEstimatedJobsAll)
    # print(np.mean(TotalEstimatedJobsAllNP))

    sys.exit(0)


if __name__ == "__main__":
    sys.exit(main())
