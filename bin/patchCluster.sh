#!/bin/bash

usage()
{
    echo -e "\nA simple script to be used for patching all Running backends in"
    echo -e "a WMCore central services K8 cluster with a patch based on an upstream PR"
    echo -e "Usage: \n ./patchCluster.sh [-z] [-f <patchFile>] [-p <\"SpaceSepListOfPods\">] [-s <serviceName>] 12077 12120 ..."
    echo -e "        -p - Space separated list of pods to be patched (Mind the quotation marks)"
    echo -e "        -s - Service name whose pods to be patched (if found)"
    echo -e "        -z - only zero the code base to the currently deployed tag for the files changed in the patch - no actual patches will be applied"
    echo -e "        -f - apply the specified patch file. No multiple files supported. If opt is repeated only the last one will be considered."
    echo -e ""
    echo -e " NOTE: We do not support patching from file and patching from command line simultaneously"
    echo -e "       If both provided at the command line patching from command line takes precedence"
    echo -e ""
    echo -e "Examples: \n"
    echo -e "\t      ./patchCluster.sh -s reqmgr2 11270 12120 \n"
    echo -e "\t      ./patchCluster.sh -p pod/reqmgr2-bcdccd8c6-hsmlj -f /tmp/11270.patch \n"
    echo -e "\t      git diff --no-color | ./patchCluster.sh -s reqmgr2 \n"
    echo -e "\t      curl https://patch-diff.githubusercontent.com/raw/dmwm/WMCore/pull/11270.patch | ./patchCluster.sh -s reqmgr2 \n"

}

# Set defaults
currPods=""
currService=""
zeroOnly=false
extPatchFile=""
while getopts ":f:p:s:zh" opt; do
    case ${opt} in
        p)
            currPods=$OPTARG
            ;;
        s)
            currService=$OPTARG
            ;;
        f)
            extPatchFile=$OPTARG
            ;;
        z)
            zeroOnly=true
            ;;
        h)
            usage
            exit 0 ;;
        \? )
            echo -e "\nERROR: Invalid Option: -$OPTARG\n"
            usage
            exit 1 ;;
        : )
            echo -e "\nERROR: Invalid Option: -$OPTARG requires an argument\n"
            usage
            exit 1 ;;
    esac
done

# shift to the last  parsed option, so we can consume the patchNum with a regular shift
shift $(expr $OPTIND - 1 )


# if fd 0 (stdin) is open and refers to a terminal - then we are running the script directly, without a pipe
# if fd 0 (stdin) is open but does not refer to the terminal - then we are running the script through a pipe
if [ -t 0 ] ; then pipe=false; else pipe=true ; fi

patchNum=$*
if $zeroOnly; then
    echo ========================================================
    echo "INFO: Only Zeroing the code base No patches will be applied"
elif $pipe ;then
    echo ========================================================
    echo "INFO: Patching from StdIn"
elif [[ -z $patchNum ]] ; then
    echo ========================================================
    echo "ERROR: No patchNum provided and not patching from StdIn"
    exit
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

    # We need to trim the `pod/` prefix from every pod's name produced with the above command
    if [[ -n $servicePods ]] ; then
        for pod in $servicePods; do
            currPods="$currPods ${pod#pod/}"
        done
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


# Build patchComponent.sh script command to be executed at the pod:

# NOTE: We do not support patching from file and patching from command line simultaneously
#       If both provided at the command line patching from command line takes precedence

podCmdActions="wget https://raw.githubusercontent.com/todor-ivanov/WMCoreAux/master/bin/patchComponent.sh -O /data/patchComponent.sh && chmod 755 /data/patchComponent.sh "
podCmdOpts=""
patchFile=""
$zeroOnly && podCmdOpts="$podCmdOpts -z"
[[ -n $extPatchFile ]] && { patchFile="/tmp/`basename $extPatchFile`"
                            podCmdOpts="$podCmdOpts -f $patchFile" ;}
$pipe && { patchFile="/tmp/pipeTmp_$(id -u).patch"
           extPatchFile=$patchFile
           podCmdOpts="$podCmdOpts -f $patchFile"
           echo "INFO: Creating a temporary patchFile from stdin at: $patchFile"
           cat <&0 > $patchFile ;}

podCmd="$podCmdActions && sudo /data/patchComponent.sh $podCmdOpts $patchNum "
restartCmd="/data/manage restart && sleep 1 && /data/manage status"

echo
echo DEBUG: podCmd: $podCmd

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

    if $pipe || [[ -n $extPatchFile ]]; then
        echo INFO: Copy any external patchFiles provided:
        echo INFO: Executing: kubectl -n $nameSpace  cp $extPatchFile $pod:$patchFile
        kubectl -n $nameSpace  cp $extPatchFile $pod:$patchFile || {
            echo ERROR: While copying patch files to pod:$pod
            echo ERROR: Skipping it!
            continue
        }
    fi

    echo INFO: Patching the services at pod: $pod:
    echo INFO: Executing: kubectl exec -it $pod -n $nameSpace -- /bin/bash -c \"$podCmd\"
    kubectl exec -it $pod -n $nameSpace -- /bin/bash -c "$podCmd" || {
        echo ERROR: While patching the pod:$pod
        echo ERROR: Skipping it!
        continue
    }
    echo
    echo INFO: Restarting the services at pod: $pod:
    echo INFO: Executing: kubectl exec $pod -n $nameSpace -- /bin/bash -c \"$restartCmd\"
    kubectl exec $pod -n $nameSpace -- /bin/bash -c "$restartCmd" || {
        echo ERROR: While restarting the service at pod:$pod
        echo ERROR: Skipping it!
        continue
    }
done
