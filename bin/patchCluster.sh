#!/bin/bash

usage()
{
    echo -ne "A simple script to be used for patching all Running backends in"
    echo -ne "a WMCore central services K8 cluster with a patch based on an upstream PR"
    echo -ne "Usage: \n ./patchCluster.sh [-p <"SpaceSepListOfPods">] 12077"
    echo -ne "        -p - Space separated list of pods to be patched (Mind the quotation marks)"
}

currPod=""
zeroOnly=false
while getopts ":p:zh" opt; do
    case ${opt} in
        p)
            currPod=$OPTARG
            ;;
        z)
            zeroOnly=true
            ;;
        h)
            usage
            exit 0 ;;
        \? )
            echo "\nERROR: Invalid Option: -$OPTARG\n"
            ;;
        : )
            echo "\nERROR: Invalid Option: -$OPTARG requires an argument\n"
            ;;
    esac
done

# shift to the last  parsed option, so we can consume the patchNum with a regular shift
shift $(expr $OPTIND - 1 )

patchNum=$1
if $zeroOnly; then
    echo "Only Zeroing the code base No patches will be applied"
elif [[ -z $patchNum ]]; then
    echo ERROR: No patchNum provided; exit
else
    echo "Applying patch: $patchNum"
fi

currentCluster=`kubectl config get-clusters |grep -v NAME`

echo ========================================================
echo CLUSTER: $currentCluster
echo --------------------------------------------------------

if [[ -n $currPod ]] ; then
    echo WARNING: We are about to patch backend pods: $currPod at k8 cluster: $currentCluster with patchNum: $patchNum
else
    echo WARNING: We are about to patch any running backend at k8 cluster: $currentCluster with patchNum: $patchNum
fi

echo WARNING: Are you sure you want to continue?
echo -n "[y/n](Default n): "
read x && [[ $x =~ (y|yes|Yes|YES) ]] || { echo WARNING: Exit on user request!; exit 101 ;}

nameSapace=dmwm
# podCmd="wget https://raw.githubusercontent.com/dmwm/WMCore/master/bin/patchComponent.sh -O /data/patchComponent.sh && chmod 755 /data/patchComponent.sh && sudo /data/patchComponent.sh $patchNum "
if $zeroOnly; then
    podCmd="wget https://raw.githubusercontent.com/todor-ivanov/WMCoreAux/master/bin/patchComponent.sh -O /data/patchComponent.sh && chmod 755 /data/patchComponent.sh && sudo /data/patchComponent.sh -z $patchNum "
else
    podCmd="wget https://raw.githubusercontent.com/todor-ivanov/WMCoreAux/master/bin/patchComponent.sh -O /data/patchComponent.sh && chmod 755 /data/patchComponent.sh && sudo /data/patchComponent.sh $patchNum "
fi

restartCmd="/data/manage restart && sleep 1 && /data/manage status"

if [[ -n $currPod ]] ; then
    runningPods=$currPod
else
    runningPods=`kubectl get pods --no-headers -o custom-columns=":metadata.name" -n $nameSapace  --field-selector=status.phase=Running`
fi

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
