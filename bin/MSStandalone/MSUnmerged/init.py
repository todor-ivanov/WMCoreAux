import sys
import os
import time
import logging
import resource
import stat
import errno
import json
import random

from pprint import pformat, pprint
# from itertools import izip

from WMCore.Services.Rucio.Rucio import  Rucio
from rucio.client import Client

import gfal2

from WMCore.Configuration import loadConfigurationFile
from WMCore.MicroService.MSCore.MSCore import MSCore
from WMCore.MicroService.MSCore.MSManager import MSManager
from WMCore.MicroService.MSUnmerged.MSUnmerged import MSUnmerged, createGfal2Context
from WMCore.MicroService.MSUnmerged.MSUnmergedRSE import MSUnmergedRSE
from WMCore.Services.RucioConMon.RucioConMon import RucioConMon
from WMCore.Services.WMStatsServer.WMStatsServer import WMStatsServer
from WMCore.Database.MongoDB import MongoDB
from WMCore.WMException import WMException
from Utils.Pipeline import Pipeline, Functor
from Utils.TwPrint import twFormat
from Utils.IteratorTools import grouper



def resCons(mark, logger=None):
    """
    A simple function for measuring resources consumption at a given marker
    point in the script
    :param mark:   A string identifying the marker point
    :param logger: A logger to use for the output
    :return:       The message as constructed for the logger
    """
    usage = resource.getrusage(resource.RUSAGE_SELF)
    msg = "%s: \nusertime=%s \nsystime=%s \nmem=%s mb"
    msg = msg % (mark, usage[0], usage[1], usage[2]/1024.0)
    logger.debug(msg)
    return msg


def reset_logging():
    manager = logging.root.manager
    manager.disabled = logging.NOTSET
    for logger in manager.loggerDict.values():
        if isinstance(logger, logging.Logger):
            logger.setLevel(logging.NOTSET)
            logger.propagate = True
            logger.disabled = False
            logger.filters.clear()
            handlers = logger.handlers.copy()
            for handler in handlers:
                # Copied from `logging.shutdown`.
                try:
                    handler.acquire()
                    handler.flush()
                    handler.close()
                except (OSError, ValueError):
                    pass
                finally:
                    handler.release()
                logger.removeHandler(handler)

def _lsTree(ctx, baseDirPfn, haltAtBottom=False):
    """
    Rrecursively traverse the tree under baseDirPfn and return the resulted list of directories and files
    return: List of all directories and files found.
    """
    dirList = []
    # First test if baseDirPfn is actually a directory entry:
    try:
        entryStat = ctx.stat(baseDirPfn)
        if not stat.S_ISDIR(entryStat.st_mode):
            dirList.append(baseDirPfn)
            logger.info("_lsTree called with a fileEntry: %s" % baseDirPfn)
            return dirList
    except gfal2.GError as gfalExc:
        if gfalExc.code == errno.ENOENT:
            logger.warning("MISSING baseDir: %s", baseDirPfn)
            return dirList
        else:
            logger.error("FAILED to open baseDir: %s: gfalException: %s", baseDirPfn, str(gfalExc))
            return dirList

    if baseDirPfn[-1] != '/':
        baseDirPfn += '/'

    # Second recursively iterate down the tree:
    try:
        dirEntryList = ctx.listdir(baseDirPfn)
    except gfal2.GError as gfalExc:
        logger.error("gfal Exception raised while listing %s. GError: %s" % (baseDirPfn, str(gfalExc)))
        raise gfalExc

    for dirEntry in dirEntryList:
        if dirEntry in ['.', '..']:
            continue
        dirEntryPfn = baseDirPfn + dirEntry
        # logger.info(dirEntryPfn)
        try:
            entryStat = ctx.stat(dirEntryPfn)
        except gfal2.GError as gfalExc:
            if gfalExc.code == errno.ENOENT:
                logger.warning("MISSING dirEntry: %s", dirEntryPfn)
                continue
            else:
                logger.error("FAILED to open dirEntry: %s: gfalException: %s", dirEntryPfn, str(gfalExc))
                continue

        if stat.S_ISDIR(entryStat.st_mode):
            dirList.append(dirEntryPfn)
            dirList.extend(_lsTree(ctx, dirEntryPfn))
        else:
            dirList.append(dirEntryPfn)
            logger.info("Found a file: %s" % dirEntry)
            if haltAtBottom:
                return dirList
    return dirList


def measureTime(ctx, rse, baseDirLfn='/store/unmerged/'):
    startTime = {}
    endTime = {}
    for proto in rse['pfnPrefixes']:
        baseDirPfn = rse['pfnPrefixes'][proto] + baseDirLfn
        print("Start _lsTree with protocol: %s" % proto)
        print("Base dir pfn: %s" % baseDirPfn)
        startTime[proto] = time.time()
        dirContent = _lsTree(ctx, baseDirPfn)
        endTime[proto] = time.time()
        print("Elapsed Time Seconds = %s" % (endTime[proto] - startTime[proto]))
        print("")
    return dirContent


def findPfnPrefix(rseName, proto):
    logger.info("searching for Pfn Prefix for protocol: %s" % proto)
    pfnPrefix = None
    storageConfigPath = '/cvmfs/cms.cern.ch/SITECONF/' + rseName + '/storage.json'
    try:
        with open(storageConfigPath, 'r') as storageConfigFile:
            storageConfig = json.load(storageConfigFile)
            for protoConfig in storageConfig[0]['protocols']:
                if protoConfig['protocol'] == proto:
                    # pprint(protoConfig)
                    if 'prefix' in protoConfig:
                        pfnPrefix = protoConfig['prefix']
        storageConfigFile.close()
    except Exception as ex:
        logger.error('Could not open Storage Config File for site: %s' % rseName)
    return pfnPrefix

def findUnprotectdLfn(ctx, rse):
    """
    A simple function to find a random unprotected file suitable for deletion
    """
    unprotectedLfn = None
    # find the proper pfnPrefix for the site:
    if rse['pfnPrefixes']['SRMv2']:
        pfnPrefix = rse['pfnPrefixes']['SRMv2']
    else:
        pfnPrefix = rse['pfnPrefixes']['WebDAV']
    logger.info("Using PfnPrefix: %s" % pfnPrefix)

    if not msUnmerged.protectedLFNs:
        logger.error( "Could not fetch the protectedLFNs list from Production WMStatServer. ")
        return None
    unmergedCont = ctx.listdir(rse['pfnPrefixes']['WebDAV'] + '/store/unmerged/')
    if not unmergedCont:
        logger.error("Empty unmerged content")
        return None

    while not unprotectedLfn:
        dirEntry = random.choice(unmergedCont)
        logger.info("Searching for an unprotected Lfn at: %s in: /store/unmerged/%s " % (rse['name'], dirEntry))
        dirEntryPfn = pfnPrefix + '/store/unmerged/' + dirEntry
        dirTreePfn = _lsTree(ctx, dirEntryPfn, haltAtBottom=True)
        filePfn = None
        for dirEntry in dirTreePfn:
            if dirEntry.endswith(".root"):
                filePfn = dirEntry
        if not filePfn:
            continue
        logger.info("filePfn: %s" % filePfn)
        fileLfn =  filePfn.split(pfnPrefix)[1]
        if not fileLfn.startswith('/store/unmerged/'):
            logger.warning("Badly constructed fileLfn: %s" % fileLfn)
            continue
        fileBaseLfn = msUnmerged._cutPath(fileLfn)
        if not fileBaseLfn in msUnmerged.protectedLFNs:
            logger.info("Found an unprotected fileLfn %s with fileBaseLfn: %s"  % (fileLfn, fileBaseLfn))
            unprotectedLfn = fileLfn
    return unprotectedLfn


if __name__ == '__main__':

    FORMAT = "%(asctime)s:%(levelname)s:%(module)s:%(funcName)s(): %(message)s"
    logging.basicConfig(stream=sys.stdout, format=FORMAT, level=logging.INFO)
    logger = logging.getLogger(__name__)
    # reset_logging()

    logger.info("########### MSUnmerged Standalone run ###########")
    preConfigMarker = resCons("PreConfig", logger=logger)

    msConfigPath=os.getenv('WMCORE_SERVICE_CONFIG') + '/reqmgr2ms-unmerged-standalone/config-unmerged.py'
    msConfigObj = loadConfigurationFile(msConfigPath)
    msConfig = msConfigObj.section_('views').section_('data').dictionary_()

    # with open(msConfigPath) as fd:
    #     exec(fd.read())
    # with open('config-ruleCleaner.py') as fd:
    #     exec(fd.read())

    # # Service config
    # msConfig = {"enableRealMode": False,
    #             "verbose": True,
    #             "interval": 1 *60,
    #             "services": ['unmerged'],
    #             "useRucio": True,
    #             "rucioAccount": "wmcore_transferor",
    #             "wmstatsUrl": "https://tivanov-unit02.cern.ch/wmstatsserver",
    #             "logDBUrl": "https://tivanov-unit02.cern.ch/couchdb/wmstats_logdb",
    #             'logDBReporter': 'reqmgr2ms_ruleCleaner',
    #             'reqmgr2Url': 'https://tivanov-unit02.cern.ch/reqmgr2',
    #             'msOutputUrl': 'https://tivanov-unit02.cern.ch/ms-output',
    #             'reqmgrCacheUrl': 'https://tivanov-unit02.cern.ch/couchdb/reqmgr_workload_cache',
    #             'dbsUrl': 'https://cmsweb-testbed.cern.ch/dbs/int/global/DBSReader',
    #             'couchDBUrl': 'https://cmsweb-testbed.cern.ch/couchdb',
    #             'rucioUrl': 'http://cms-rucio.cern.ch',
    #             'rucioAuthUrl': 'https://cms-rucio-auth.cern.ch'}
    #             # 'rucioUrl': 'http://cmsrucio-int.cern.ch',
    #             # 'rucioAuthUrl': 'https://cmsrucio-auth-int.cern.ch'}

    preInstanceMarker = resCons("PreInstance", logger=logger)

    # setup Rucio client
    rucio = Rucio(msConfig['rucioAccount'], configDict={"logger": logger})
    rcl = Client(account=msConfig['rucioAccount'])

    # logger.info("########### MSManager startup ###########")
    # msManager = MSManager(msConfig, logger)

    random.seed(time.time())
    msConfig['enableRealMode'] = False
    msUnmerged = MSUnmerged(msConfig)
    msUnmerged.resetServiceCounters()
    ctx = createGfal2Context(msConfig['gfalLogLevel'], msConfig['emulateGfal2'])
    msUnmerged.protectedLFNs = set(msUnmerged.wmstatsSvc.getProtectedLFNs())
    msUnmerged.rseConsStats = msUnmerged.rucioConMon.getRSEStats()

    preExecMarker = resCons("PreExec", logger=logger)

    mongoDBConfig = {
        'database': msConfig['mongoDB'],
        'server': msConfig['mongoDBServer'],
        'replicaSet': msConfig['mongoDBReplicaSet'],
        'port': msConfig['mongoDBPort'],
        'username': msConfig['mongoDBUser'],
        'password': msConfig['mongoDBPassword'],
        'connect': True,
        'directConnection': False,
        'logger': logger,
        'create': False,
        'mockMongoDB': msConfig['mockMongoDB']}

    # NOTE: We need to blur `username' and `password' keys before printing the configuration:
    msg = "Connecting to MongoDB using the following mongoDBConfig:\n%s"
    logger.info(msg, pformat({**mongoDBConfig, **{'username': '****', 'password': '****'}}))

    mongoDBObj = MongoDB(**mongoDBConfig)
    mongoDB = getattr(mongoDBObj, msConfig['mongoDB'])
    mongoClt = mongoDBObj.client
    # mongoColl = currDB[msConfig['collection']] if msConfig['collection'] else None

    # result = msUnmerged.execute()
    # logger.info('Execute result: %s', pformat(result))
    # postExecMarker = resCons("PostExec", logger=logger)
    # # reset_logging()

    rseNames = msUnmerged.getRSEList()
    rseList = {}
    protoList = ['SRMv2', 'XRootD', 'WebDAV']
    for rseName in rseNames:
        rse = MSUnmergedRSE(rseName)
        rse = msUnmerged.getRSEFromMongoDB(rse)
        # rse = msUnmerged.getUnmergedFiles(rse)
        rse = msUnmerged.getPfn(rse)
        rse['pfnPrefixes'] = {}
        for proto in protoList:
            rse['pfnPrefixes'][proto] = findPfnPrefix(rse['name'], proto)
        rseList[rse['name']] = rse


    # msUnmerged.execute()
    # msUnmerged.protectedLFNs
    # msUnmerged.rseConsStats
    # rse['pfnPrefixSrm'] = 'srm://srm.ciemat.es:8443/srm/managerv2?SFN=/pnfs/ciemat.es/data/cms/prod'
    # rse['pfnPrefixDavs'] = rse['pfnPrefix']
    # lfn = '/store/unmerged/GenericNoSmearGEN/InclusiveDileptonMinBias_TuneCP5Plus_13p6TeV_pythia8/GEN/124X_mcRun3_2022_realistic_v12-v2'
    # dirCont = _lsTree(ctx, rse['pfnPrefixDavs'] + lfn)
