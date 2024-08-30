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
    request = Request(app, couchDBMgr, config.views.data, appName)
