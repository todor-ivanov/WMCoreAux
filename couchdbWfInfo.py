#!/usr/bin/python
"""
Script to retrieve and dump all the WorkFlow information from couchdb
"""
from __future__ import print_function, division

import argparse
import httplib
import json
import os
import pwd
import sys
import urllib2
from urllib2 import HTTPError, URLError
from textwrap import TextWrapper
from collections import OrderedDict


# ID for the User-Agent
CLIENT_ID = 'workflowCompletion::python/%s.%s' % sys.version_info[:2]


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


def handleReqMgr(reqName, reqmgrUrl):
    """
    Return the list of output datasets
    """
    urn = reqmgrUrl + "/reqmgr2/data/request/" + reqName
    reqmgrOut = json.loads(getContent(urn))['result'][0][reqName]

    if reqmgrOut['RequestStatus'] in ['assignment-approved', 'assigned', 'staging', 'staged']:
        print("Workflow %s in status: %s , skipping!\n" % (reqName, reqmgrOut['RequestStatus']))
        return None, None

    if 'InputDataset' in reqmgrOut:
        inputData = reqmgrOut['InputDataset']
    elif 'Task1' in reqmgrOut and 'InputDataset' in reqmgrOut['Task1']:
        inputData = reqmgrOut['Task1']['InputDataset']
    elif 'Step1' in reqmgrOut and 'InputDataset' in reqmgrOut['Step1']:
        inputData = reqmgrOut['Step1']['InputDataset']
    else:
        inputData = None

    print("==> %s\t(status: %s)" % (reqName, reqmgrOut['RequestStatus']))
    print("InputDataset:\n    %s (total input lumis: %s)" % (inputData, reqmgrOut['TotalInputLumis']))
    return reqmgrOut['TotalInputLumis'], reqmgrOut['OutputDatasets']


def handleCoucdb(reqName, reqmgrUrl):
    """
    Return a dictionary with all the information from couchdb
    """
    urn = reqmgrUrl + "/couchdb/workloadsummary/" + reqName
    couchdbOut = json.loads(getContent(urn))
    return couchdbOut


def twClosure(replace_whitespace=False,
              break_long_words=False,
              width=120,
              initial_indent=''):
    """
    Deals with indentation of dictionaries with very long key, value pairs.
    replace_whitespace: Replace each whitespace character with a single space.
    break_long_words: If True words longer than width will be broken.
    width: The maximum length of wrapped lines.
    initial_indent: String that will be prepended to the first line of the output

    Wraps all strings for both keys and values to 120 chars.
    Uses 4 spaces indentation for both keys and values.
    Nested dictionaries and lists go to next line.
    """
    twr = TextWrapper(replace_whitespace=replace_whitespace,
                      break_long_words=break_long_words,
                      width=width,
                      initial_indent=initial_indent)

    def twEnclosed(obj, ind='', reCall=False):
        """
        The inner function of the closure
        ind: Initial indentation for the single output string
        reCall: Flag to indicate a recursive call (should not be used outside)
        """
        output = ''
        if isinstance(obj, dict):
            obj = OrderedDict(sorted(obj.items(),
                                     key=lambda t: t[0],
                                     reverse=False))
            if reCall:
                output += '\n'
            ind += '    '
            for key, value in obj.iteritems():
                output += "%s%s: %s" % (ind,
                                        ''.join(twr.wrap(key)),
                                        twEnclosed(value, ind, reCall=True))
        elif isinstance(obj, list):
            if reCall:
                output += '\n'
            ind += '    '
            for value in obj:
                output += "%s%s" % (ind, twEnclosed(value, ind, reCall=True))
        else:
            output += "%s\n" % str(obj)# join(twr.wrap(str(obj)))
        return output
    return twEnclosed


def twPrint(obj):
    """
    A simple caller of twClosure (see docstring for twClosure)
    """
    twPrinter = twClosure()
    print(twPrinter(obj))


def main():
    """
    Requirements: you need to have your proxy and proper x509 environment
    variables set.

    Receive a workflow name in order to fetch the following information:
     - from couchdb: dumps all the information regarding the WorkFlow
    """
    parser = argparse.ArgumentParser(description="Validate workflow input, output and config")
    group = parser.add_mutually_exclusive_group()
    group.add_argument('-w', '--workflow', help='A single workflow name')
    group.add_argument('-i', '--inputFile', help='Plain text file containing request names (one per line)')
    parser.add_argument('-c', '--cms', help='CMSWEB url to talk to DBS/PhEDEx. E.g: cmsweb-testbed.cern.ch')
    parser.add_argument('-r', '--reqmgr', help='Request Manager URL. Example: cmsweb-testbed.cern.ch')
    args = parser.parse_args()

    if args.workflow:
        listRequests = [args.workflow]
    elif args.inputFile:
        with open(args.inputFile, 'r') as f:
            listRequests = [req.rstrip('\n') for req in f.readlines()]
    else:
        parser.error("You must provide either a workflow name or an input file name.")
        sys.exit(3)

    cmswebUrl = "https://" + args.cms if args.cms else "https://cmsweb.cern.ch"
    reqmgrUrl = "https://" + args.reqmgr if args.reqmgr else "https://cmsweb.cern.ch"

    for reqName in listRequests:
        couchdbOut = handleCoucdb(reqName, reqmgrUrl)
        print("-----------------------------")
        twPrint(couchdbOut)
        print("-----------------------------")

    sys.exit(0)


if __name__ == "__main__":
    sys.exit(main())
