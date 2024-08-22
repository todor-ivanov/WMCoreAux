#!/bin/bash

# A simple Utilitarian script to be used for patching all Running backends in
# a WMCore central services K8 cluster with a patch based on an upstream PR
# usage: ./patchCluster.sh 12077

patchNum=$1
[[ -z $patchNum ]] && { echo ERROR: No patchNum provided; exit ;}

currentCluster=`kubectl config get-clusters |grep -v NAME`

echo ========================================================
echo CLUSTER: $currentCluster
echo --------------------------------------------------------

echo WARNING: We are about to patch any running backend at k8 cluster: $currentCluster with patchNum: $patchNum
echo WARNING: Are you sure you want to continue?
echo -n "[y/n](Default n): "
read x && [[ $x =~ (y|yes|Yes|YES) ]] || { echo WARNING: Exit on user request!; exit 101 ;}

nameSapace=dmwm
podCmd="wget https://raw.githubusercontent.com/dmwm/WMCore/master/bin/patchComponent.sh -O /data/patchComponent.sh && chmod 755 /data/patchComponent.sh && sudo /data/patchComponent.sh $patchNum "
restartCmd="/data/manage restart && sleep 1 && /data/manage status"

runningPods=`kubectl get pods --no-headers -o custom-columns=":metadata.name" -n $nameSapace  --field-selector=status.phase=Running`

for pod in $runningPods
do
    echo
    echo --------------------------------------------------------
    echo $pod:
    echo Executing: kubectl exec -it $pod -n $nameSapace -- /bin/bash -c \"$podCmd\"
    kubectl exec -it $pod -n $nameSapace -- /bin/bash -c "$podCmd"
    echo
    echo Executing: kubectl exec $pod -n $nameSapace -- /bin/bash -c \"$restartCmd\"
    kubectl exec $pod -n $nameSapace -- /bin/bash -c "$restartCmd"
done
