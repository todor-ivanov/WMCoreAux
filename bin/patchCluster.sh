#!/bin/bash

usage()
{
    echo -e "\nA simple script to be used for patching all Running backends in"
    echo -e "a WMCore central services K8 cluster with a patch based on an upstream PR"
    echo -e "Usage: \n ./patchCluster.sh [-p <\"SpaceSepListOfPods\">] [-s <serviceName>] [-z] 12077 12120 ..."
    echo -e "        -p - Space separated list of pods to be patched (Mind the quotation marks)"
    echo -e "        -s - Service name whose pods to be patched (if found)"
    echo -e "        -z - only zero the code base to the currently deployed tag for the files changed in the patch - no actual patches will be applied"
}

# Set defaults
currPods=""
currService=""
zeroOnly=false
while getopts ":p:s:zh" opt; do
    case ${opt} in
        p)
            currPods=$OPTARG
            ;;
        s)
            currService=$OPTARG
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

patchNum=$*
if $zeroOnly; then
    echo ========================================================
    echo "INFO: Only Zeroing the code base No patches will be applied"
elif [[ -z $patchNum ]]; then
    echo ========================================================
    echo ERROR: No patchNum provided; exit
else
    echo ========================================================
    echo "INFO: Applying patch: $patchNum"
fi

currCluster=`kubectl config get-clusters |grep -v NAME`
nameSpace=dmwm

echo ========================================================
echo INFO: CLUSTER: $currCluster
echo --------------------------------------------------------

# First try to find any pod from the service name provided and then extend the list in currPods:
if [[ -n $currService ]]; then
    servicePods=`kubectl -n $nameSpace  get ep $currService -o=jsonpath='{.subsets[*].addresses[*].ip}' | tr ' ' '\n' | xargs -I % kubectl -n $nameSpace get pods  -o=name --field-selector=status.podIP=%`
    [[ $? -eq 0 ]] || { echo "WARNING: could not find service: $currService at cluster: $currCluster"; exit ;}
    if [[ -n $servicePods ]] ; then
        currPods="$currPods $servicePods"
        echo "INFO: Found the following pods for service: $currService: "
        echo "$servicePods "
    else
        echo "WARNING: No pods found for service: $currService"
        exit
    fi
fi

if [[ -n $currPods ]] ; then
    echo ========================================================
    echo WARNING: We are about to patch backend pods: $currPods
    echo WARNING: at k8 cluster: $currCluster with patchNum: $patchNum
else
    echo ========================================================
    echo WARNING: We are about to patch ANY running backend pod
    echo WARNING: at k8 cluster: $currCluster with patchNum: $patchNum
fi

echo WARNING: Are you sure you want to continue?
echo -n "[y/n](Default n): "
read x && [[ $x =~ (y|yes|Yes|YES) ]] || { echo WARNING: Exit on user request!; exit 101 ;}
echo ========================================================

# podCmd="wget https://raw.githubusercontent.com/dmwm/WMCore/master/bin/patchComponent.sh -O /data/patchComponent.sh && chmod 755 /data/patchComponent.sh && sudo /data/patchComponent.sh $patchNum "
if $zeroOnly; then
    podCmd="wget https://raw.githubusercontent.com/todor-ivanov/WMCoreAux/master/bin/patchComponent.sh -O /data/patchComponent.sh && chmod 755 /data/patchComponent.sh && sudo /data/patchComponent.sh -z $patchNum "
else
    podCmd="wget https://raw.githubusercontent.com/todor-ivanov/WMCoreAux/master/bin/patchComponent.sh -O /data/patchComponent.sh && chmod 755 /data/patchComponent.sh && sudo /data/patchComponent.sh $patchNum "
fi

restartCmd="/data/manage restart && sleep 1 && /data/manage status"

if [[ -n $currPods ]] ; then
    runningPods=$currPods
else
    # # check if any service name was actually provided at the command line and if not only then search for all running pods for the whole cluster:
    # if [[ -n $currService ]] ; then
    #     echo "WARNING: Requested to patch: $currService at: $currCluster but NO pods were found."
    #     echo "WARNING: Will not patch the whole cluster. Nothing to do here, giving up now."
    #     exit
    # else
    runningPods=`kubectl get pods --no-headers -o custom-columns=":metadata.name" -n $nameSpace  --field-selector=status.phase=Running`
    # fi
fi

for pod in $runningPods
do
    echo
    echo --------------------------------------------------------
    echo INFO: $pod:
    echo INFO: Executing: kubectl exec -it $pod -n $nameSpace -- /bin/bash -c \"$podCmd\"
    kubectl exec -it $pod -n $nameSpace -- /bin/bash -c "$podCmd"
    echo
    echo INFO: Executing: kubectl exec $pod -n $nameSpace -- /bin/bash -c \"$restartCmd\"
    kubectl exec $pod -n $nameSpace -- /bin/bash -c "$restartCmd"
done
