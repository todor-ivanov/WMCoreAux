import sys
import os
import time
import logging
import resource
import stat
import errno
import json
import random
import re
import queue
import threading
import cherrypy

from argparse import ArgumentParser
from pprint import pformat, pprint

from WMCore.Services.Rucio.Rucio import  Rucio
from rucio.client import Client


from WMCore.Configuration import loadConfigurationFile
from WMCore.MicroService.MSCore.MSCore import MSCore
from WMCore.MicroService.MSCore.MSManager import MSManager
# from WMCore.MicroService.MSUnmerged.MSUnmerged import MSUnmerged, createGfal2Context
# from WMCore.MicroService.MSUnmerged.MSUnmergedRSE import MSUnmergedRSE
from WMCore.Services.RucioConMon.RucioConMon import RucioConMon
from WMCore.Services.WMStatsServer.WMStatsServer import WMStatsServer
# from WMCore.Database.MongoDB import MongoDB
from WMCore.WMException import WMException
# from Utils.Pipeline import Pipeline, Functor
from Utils.TwPrint import twFormat
from Utils.IteratorTools import grouper
from WMCore.ReqMgr.Service.RestApiHub import IndividualCouchManager
from WMCore.REST.Main import RESTMain
from WMCore.ReqMgr.Service.Request import Request
from WMCore.ReqMgr.Service.Auxiliary import Info
from WMCore.WMSpec.WMWorkload import WMWorkload, WMWorkloadHelper
from Utils.CertTools import getKeyCertFromEnv
from Utils.CertTools import cert as getCert
from Utils.CertTools import ckey as getKey
from cryptography import x509
from cryptography.hazmat.backends import default_backend
from WMCore.REST.Server import RESTArgs


if __name__ == '__main__':

    """
    __WMCStandalone__

    usage:
       ipython -i /data/WMCoreAux/bin/WMCStandalone/init.py -- -c $WMCORE_SERVICE_CONFIG/reqmgr2/config.py
    """

    FORMAT = "%(asctime)s:%(levelname)s:%(module)s:%(funcName)s(): %(message)s"
    logging.basicConfig(stream=sys.stdout, format=FORMAT, level=logging.INFO)
    logger = logging.getLogger(__name__)
    # reset_logging()

    logger.info("We are here")
    opt = ArgumentParser(usage=__doc__)
    opt.add_argument("-c", "--config", dest="config", required=True,
                     help="Service configuration file.")
    opts, args = opt.parse_known_args()

    logger.info("########### Central services Standalone run.                                             ###########")
    logger.info(f"########### Config: {opts.config} ###########")



    # configPath=os.getenv('WMCORE_SERVICE_CONFIG') + '/reqmgr2ms-unmerged-standalone/config-unmerged.py'
    config = loadConfigurationFile(opts.config)
    configDict = config.section_('views').section_('data').dictionary_()

    # Reduce config object to data section only:
    # config = config.views.data

    # Creating the Appication instance (e.g. reqmgr2, reqmon, etc...)
    appName = config.main.application.lower()
    stateDir = os.environ['WMCORE_SERVICE_STATE'] + appName
    app = RESTMain(config, stateDir)

    # creating couchDBManager:
    couchDBMgr = IndividualCouchManager(config.views.data)

    # creating request service instance:
    reqApi = Request(app, couchDBMgr, config.views.data, appName)

    # creating reqInfo instance:
    reqInfo = Info(app, couchDBMgr, config.views.data, appName)
    info = list(reqInfo.get())[0]
    # pprint(info)

    reqName = 'user_SC_LumiMask_Rules_SiteListsTest_v4_240830_135942_6572'
    # create a wmworkload spec and load a workflow from couch:
    workload = WMWorkloadHelper()
    couchUrl = reqApi.config.couch_host + '/' + reqApi.config.couch_reqmgr_db
    workload.loadSpecFromCouch(couchUrl, reqName)

    # read/load certificate data:
    with open(getCert(), 'rb') as certFile:
        certCont = certFile.read()
    cert = x509.load_pem_x509_certificate(certCont)
    userDN = "/" + cert.subject.rfc4514_string().replace(',','/')
    # NOTE: The resultant DN is reversed in order compared to what we get with `voms-proxy-utils` - TODO

    # Add user parameters to cherrypy:
    cherrypy.request.user = {'dn': userDN}

    # get reqCfonfig:

    # change request arguments No - state transition:
    reqArgs = {'SiteWhitelist': ['T2_CERN_CH','T1_US_FNAL'],
               'SiteBlacklist': ['T1_US_FNAL'],
               'RequestPriority': 3 }
    reqApi._updateRequest(workload, reqArgs)

    # making a proper REST call to the change the request parameeters:
    qParams = RESTArgs(reqName, reqArgs)
    safe = RESTArgs(None,{})

    workLoadPair = reqApi.validate(reqApi, 'PUT', appName, qParams, safe)
    # TODO: The above call is broken. The first parameter is wrong - to be fixed.
    #       The original call:
    #       [05/Sep/2024:11:54:41]  DEBUG: Request: validate: method PUT
    #       [05/Sep/2024:11:54:41]  DEBUG: Request: validate: apiobj {'args': ['workload_pair_list'], 'validation': [<bound method Request.validate of <WMCore.ReqMgr.Service.Request.Request object at 0x7f38df37be80>>, <bound method RESTApi._enter of <WMCore.ReqMgr.Service.RestApiHub.RestApiHub object at 0x7f38e05ae190>>], 'call': <bound method Request.put of <WMCore.ReqMgr.Service.Request.Request object at 0x7f38df37be80>>, 'entity': <WMCore.ReqMgr.Service.Request.Request object at 0x7f38df37be80>, 'formats': [('application/json', <WMCore.REST.Format.JSONFormat object at 0x7f38e04358b0>)], 'generate': 'result'}
    #       [05/Sep/2024:11:54:41]  DEBUG: Request: validate: api request
    #       [05/Sep/2024:11:54:41]  DEBUG: Request: validate: safe: <class 'WMCore.REST.Server.RESTArgs'>
    #       [05/Sep/2024:11:54:41]  DEBUG: Request: validate: safe[args]: []
    #       [05/Sep/2024:11:54:41]  DEBUG: Request: validate: safe[kwargs]: {}
    #       [05/Sep/2024:11:54:41]  DEBUG: Request: validate: param: <class 'WMCore.REST.Server.RESTArgs'>
    #       [05/Sep/2024:11:54:41]  DEBUG: Request: validate: param[args]: ['user_SC_LumiMask_Rules_SiteListsTest_v4_240830_135942_6572']
    #       [05/Sep/2024:11:54:41]  DEBUG: Request: validate: param[kwargs]: {}
    #       [05/Sep/2024:11:54:41]  DEBUG: Request: _validateRequestBase: data (b'{"RequestPriority":3,"SiteWhitelist":["T2_CERN_CH","T1_US_FNAL"],"SiteBlackl'
    #        b'ist":["T2_CERN_CH","T1_US_FNAL"]}')
    #       [05/Sep/2024:11:54:41]  Updating request "user_SC_LumiMask_Rules_SiteListsTest_v4_240830_135942_6572" with these user-provided args: {'RequestPriority': 3, 'SiteWhitelist': ['T2_CERN_CH', 'T1_US_FNAL'], 'SiteBlacklist': ['T2_CERN_CH', 'T1_US_FNAL']}
    #       [05/Sep/2024:11:54:41]  DEBUG: Request: _validateRequestBase: request_args [{'RequestName': 'user_SC_LumiMask_Rules_SiteListsTest_v4_240830_135942_6572',
    #         'RequestPriority': 3,
    #         'SiteBlacklist': ['T2_CERN_CH', 'T1_US_FNAL'],
    #         'SiteWhitelist': ['T2_CERN_CH', 'T1_US_FNAL']}]
    #       [05/Sep/2024:11:54:41]  DEBUG: Request: _validateRequestBase: args {'RequestName': 'user_SC_LumiMask_Rules_SiteListsTest_v4_240830_135942_6572',
    #        'RequestPriority': 3,
    #        'SiteBlacklist': ['T2_CERN_CH', 'T1_US_FNAL'],
    #        'SiteWhitelist': ['T2_CERN_CH', 'T1_US_FNAL']}
    #       [05/Sep/2024:11:54:41]  DEBUG: Request: _validateRequestBase: r_args {'RequestPriority': 3,
    #        'SiteBlacklist': ['T2_CERN_CH', 'T1_US_FNAL'],
    #        'SiteWhitelist': ['T2_CERN_CH', 'T1_US_FNAL']}
    #       [05/Sep/2024:11:54:41]  DEBUG: Request: _validateRequestBase: workload <WMCore.WMSpec.WMWorkload.WMWorkloadHelper object at 0x7f38de6c0910>
    #       [05/Sep/2024:11:54:41]  DEBUG: ReqMgr.Service.Request.Request: validate: We are here
    #       [05/Sep/2024:11:54:41]  DEBUG: Request: _handleNoStatusUpdate: reqArgsDiff {'RequestPriority': 3,
    #        'SiteBlacklist': ['T2_CERN_CH', 'T1_US_FNAL'],
    #        'SiteWhitelist': ['T2_CERN_CH', 'T1_US_FNAL']}
    #       [05/Sep/2024:11:54:42]  Updated priority of "user_SC_LumiMask_Rules_SiteListsTest_v4_240830_135942_6572" to: 3
    #       [05/Sep/2024:11:54:42]  Updated SiteWhitelist of "user_SC_LumiMask_Rules_SiteListsTest_v4_240830_135942_6572", with:  ['T2_CERN_CH', 'T1_US_FNAL']
    #       [05/Sep/2024:11:54:42]  Updated SiteBlacklist of "user_SC_LumiMask_Rules_SiteListsTest_v4_240830_135942_6572", with:  ['T2_CERN_CH', 'T1_US_FNAL']
