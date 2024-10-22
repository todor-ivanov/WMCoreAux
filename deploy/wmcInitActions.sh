#!/bin/bash

cd $WMA_ROOT_DIR/

# upload Unified config:
python $WMA_DEPLOY_DIR/bin/adhoc-scripts/injectUnified.py -c cmsweb-test1.cern.ch

# upload unified campaigns
wget https://raw.githubusercontent.com/CMSCompOps/WmAgentScripts/refs/heads/master/campaigns.json
python3 $WMA_DEPLOY_DIR/bin/adhoc-scripts/parseUnifiedCampaigns.py --fin=campaigns.json --url=https://cmsweb-test1.cern.ch/reqmgr2 --verbose=10 --testcamp

# create and upload pileup objects:
# first download the dev pileup json:
wget https://raw.githubusercontent.com/dmwm/WMCore/refs/heads/master/test/data/WMCore/MicroService/DataStructs/pileups_dev.json
python $WMA_DEPLOY_DIR/bin/adhoc-scripts/createPileupObjects.py --url=https://cmsweb-test1.cern.ch --fin=pileups_dev.json --inject
