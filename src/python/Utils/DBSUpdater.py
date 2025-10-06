#!/usr/bin/env python

from dbs.apis.dbsClient import DbsApi
from WMCore.Lexicon import dataset as isDataset, block as isBlock , lfn as isLfn


class DBSUpdater(object):

    def __init__(self, dbsUrl=None):
        self.dbsUrl = dbsUrl
        self.dbsApi = DbsApi(dbsUrl)
        self.statusMap = {'valid': 1,
                          'invalid': 0,
                          '1':1,
                          1:1,
                          '0':0,
                          0:0}
    @staticmethod
    def _isDataset(candidate):
        try:
            return isDataset(candidate)
        except AssertionError:
            return False

    @staticmethod
    def _isBlock(candidate):
        try:
            return isBlock(candidate)
        except AssertionError:
            return False

    @staticmethod
    def _isLfn(candidate):
        try:
            return isLfn(candidate)
        except AssertionError:
            return False

    def getDatasetFiles(self, dataset=None, status=None):
        if status:
            status = self.statusMap[status]
            return [fileRec['logical_file_name'] for fileRec in  self.dbsApi.listFileArray(dataset=dataset, detail=True)
                    if  fileRec['is_file_valid'] == status]
        else:
            return [fileRec['logical_file_name'] for fileRec in  self.dbsApi.listFileArray(dataset=dataset, detail=False)]

    def filterFilesByStatus(self, files=None, status=None):
        status = self.statusMap[status]
        if isinstance(files, str) and self._isDataset(files):
            return self.filterFilesByStatus(self.getDatasetFiles(files), status)
        return [fileRec['logical_file_name'] for fileRec in  self.dbsApi.listFileArray(logical_file_name=files, detail=True)
            if  fileRec['is_file_valid'] == status]

    def getFilesChildren(self, files):
        """
        :param files: list of lfns
        """
        if isinstance(files, str) and self._isDataset(files):
            return self.getFilesChildren(self.getDatasetFiles(files))
        else:
            return [fileRec['child_logical_file_name'] for fileRec in  self.dbsApi.listFileChildren(logical_file_name=files)]

    def updateFilesStatus(self, entries, status=None, recursive=False):
        """
        :param entries: list of lfns or a datasetName
        """
        kwargs={}
        if isinstance(entries, str) and self._isDataset(entries):
            kwargs['dataset'] = entries
        elif isinstance(entries, str) and self._isLfn(entries):
            kwargs['logical_file_name'] = entries
        elif isinstance(entries, list):
            kwargs['logical_file_name'] = entries
        else:
            print("bad entries")
            return False

        kwargs['is_file_valid'] = self.statusMap[status]

        # print(f"kwargs: {kwargs}")
        if recursive and kwargs.get('dataset', None):
            print(f"self.updateFilesStatus({kwargs['dataset']}, status={status}, recursive=False)")
            self.updateFilesStatus(kwargs['dataset'], status=status, recursive=False)
            newEntries = self.getFilesChildren(kwargs['dataset'])
            while newEntries:
                print(f"Updating Children files for dataset {kwargs['dataset']} recursively:")
                print(f"self.updateFilesStatus({len(newEntries)} entries, status={status}, recursive=True)")
                self.updateFilesStatus(newEntries, status=status, recursive=recursive)
                return
        elif recursive and kwargs.get('logical_file_name', None):
            print(f"self.updateFilesStatus({len(entries)} entries, status={status}, recursive=False)")
            # NOTE: Updates on bulk/file lists does not work in dbs integration.
            #       Needs to be tested in production as well
            #  # self.updateFilesStatus(entries, status=status, recursive=False)
            for entry in entries:
                self.updateFilesStatus(entry, status=status, recursive=False)
            children = self.getFilesChildren(entries)
            while children:
                print(f"Updating filelist with {len(children)} members recursively:")
                print(f"self.updateFilesStatus({len(children)} entries, status={status}, recursive=True)")
                self.updateFilesStatus(children, status=status, recursive=True)
                return
                # self.updateFilesStatus(children, status=status, recursive=recursive)
        else:
            return self.dbsApi.updateFileStatus(**kwargs)

    def updateDatasetStatus(self, dataset, status):
        kwargs = {}
        kwargs['dataset'] =  dataset
        kwargs['dataset_access_type'] = status
        self.dbsApi.updateDatasetType(**kwargs)

    def getDatasetInfo(self, dataset):
        return self.dbsApi.listDatasets(dataset=dataset, detail=True)
