#!/bin/bash

usage()
{
    echo -e "\nA simple script to facilitate component patching\n"
    echo -e "and to decrease the development && testing turnaround time.\n"
    echo -e "Usage: \n ./patchComponent [-z] <patchNum> <patchNum> ..."
    echo -e "      -z  - only zero the code base to the currently deployed tag for the files changed in the patch - no actual patches will be applied\n"
    echo -e "Examples: \n"
    echo -e "\t sudo ./patchComponent.sh 11270 12120 \n"
    echo -e "\t git diff --no-color | sudo ./patchComponent.sh \n or:\n"
    echo -e "\t curl https://patch-diff.githubusercontent.com/raw/dmwm/WMCore/pull/11270.patch | sudo ./patchComponent.sh \n"
}



# Add default value for zeroOnly option
zeroOnly=false

while getopts ":zh" opt; do
    case ${opt} in
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


# if fd 0 (stdin) is open and refers to a terminal - then we are running the script directly, without a pipe
# if fd 0 (stdin) is open but does not refer to the terminal - then we are running the script through a pipe
if [ -t 0 ] ; then pipe=false; else pipe=true ; fi

patchList=$*
[[ -z $patchList ]] && patchList="temp"

echo "INFO: Patching WMCore code with PRs: $patchList"

currTag=$(python -c "from WMCore import __version__ as WMCoreVersion; print(WMCoreVersion)")
echo "INFO: Current WMCoreTag: $currTag"


# Find all possible locations for the component source
# NOTE: We always consider PYTHONPATH first
pythonLibPaths=$(echo $PYTHONPATH |sed -e "s/\:/ /g")
pythonLibPaths="$pythonLibPaths $(python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())")"

for path in $pythonLibPaths
do
    [[ -d $path/WMCore ]] && { pythonLibPath=$path; echo "Source code found at: $path"; break ;}
done

[[ -z $pythonLibPath  ]] && { echo "ERROR: Could not find WMCore source to patch"; exit  1 ;}
echo "INFO: Current PythonLibPath: $pythonLibPath"

# Set patch command parameters
stripLevel=3
patchCmd="patch -t --verbose -b --version-control=numbered -d $pythonLibPath -p$stripLevel"

# Define Auxiliary functions
_createTestFilesDst() {
    # A simple function to create test files destination for not breaking the patches
    # because of a missing destination:
    # :param $1:   The source branch to be used for checking the files: could be TAG or Master
    # :param $2-*: The list of files to be checked out
    local srcBranch=$1
    shift
    local testFileList=$*
    for file in $testFileList
    do
        # file=${file#a\/test\/python\/}
        fileName=`basename $file`
        fileDir=`dirname $file`
        # Create the file path if missing
        mkdir -p $pythonLibPath/$fileDir
        echo INFO: orig: https://raw.githubusercontent.com/dmwm/WMCore/$srcBranch/test/python/$file
        echo INFO: dest: $pythonLibPath/$file
        curl -f https://raw.githubusercontent.com/dmwm/WMCore/$srcBranch/test/python/$file  -o $pythonLibPath/$file || {
            echo INFO: file: $file missing at the origin.
            echo INFO: Seems to be a new file for the curren patch.
            echo INFO: Removing it from the destination as well!
            rm -f $pythonLibPath/$file
        }
    done
}

_zeroCodeBase() {
    # A simple function to zero the code base for a set of files starting from
    # a given tag or branch at the origin
    # :param $1:   The source branch to be used for checking the files: could be TAG or Master
    # :param $2-*: The list of files to be checked out
    local srcBranch=$1
    shift
    local srcFileList=$*
    for file in $srcFileList
    do
        # file=${file#a\/src\/python\/}
        fileName=`basename $file`
        fileDir=`dirname $file`
        # Create the file path if missing
        mkdir -p $pythonLibPath/$fileDir
        echo INFO: orig: https://raw.githubusercontent.com/dmwm/WMCore/$srcBranch/src/python/$file
        echo INFO: dest: $pythonLibPath/$file
        curl -f https://raw.githubusercontent.com/dmwm/WMCore/$srcBranch/src/python/$file  -o $pythonLibPath/$file || {
            echo INFO: file: $file missing at the origin.
            echo INFO: Seems to be a new file for the curren patch.
            echo INFO: Removing it from the destination as well!
            rm -f $pythonLibPath/$file
        }
    done
}


#TODO: ....HERE TO START ITERATING THROUGH THE PATCH LIST

# Download/Create all needed patch files:

srcFileList=""
testFileList=""

for patchNum in $patchList
do
    patchFile=/tmp/$patchNum.patch

    if $pipe
    then
        # if we run through a pipeline create the temporary patch file for later parsing
        echo "INFO: Creating a temporary patchFile at: $patchFile"
        cat <&0 > $patchFile
    else
        echo "INFO: Downloading a temporary patchFile at: $patchFile"
        curl https://patch-diff.githubusercontent.com/raw/dmwm/WMCore/pull/$patchNum.patch -o $patchFile
    fi

    # Parse a list of files changed only by the current patch
    srcFileListTemp=`grep diff $patchFile |grep "a/src/python" |awk '{print $3}' |sort |uniq`
    testFileListTemp=`grep diff $patchFile |grep "a/test/python" |awk '{print $3}' |sort |uniq`

    # Reduce paths for both src and test file lists to the path depth known to
    # the WMCore modules/packages and add them to the global scope file lists
    for file in $srcFileListTemp
    do
        file=${file#a\/src\/python\/} && srcFileList="$srcFileList $file"
    done

    for file in $testFileListTemp
    do
        file=${file#a\/test\/python\/} && testFileList="$srcFileList $file"
    done

done

echo
echo "INFO: Refreshing all files which are to be patched from the origin and TAG: $currTag"
echo

# First create destination for test files from currTag if missing
_createTestFilesDst $currTag $testFileList


# Then zero code base for source files from currTag
_zeroCodeBase $currTag $srcFileList


# exit if the user has requested to only zero the code base
$zeroOnly && exit

err=0
echo
echo
echo "INFO: Patching all files starting from the original version of TAG: $currTag"
for patchNum in $patchList
do
    patchFile=/tmp/$patchNum.patch
    echo
    echo
    echo "INFO: ----------------- Currently applying patch: $patchNum -----------------"
    echo "INFO: cat $patchFile | $patchCmd"
    cat $patchFile | $patchCmd
    let err+=$?
done

echo
echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo
if [[ $err -eq 0 ]]; then
    echo INFO: First patch attempt exit status: $err
    echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    exit
else
    echo WARNING: First patch attempt exit status: $err
    echo
    echo
    echo WARNING: There were errors while patching from TAG: $currTag
    echo WARNING: Most probably some of the files from the current patch were having changes
    echo WARNING: between the current PR and the tag deployed at the host/container.
    echo
    echo
    echo WARNING: TRYING TO START FROM ORIGIN/MASTER BRANCH INSTEAD:
    echo
    echo
fi


# If we are here it means something went wrong while patching some of the files.
# Most probably some of the files are having changes between the current PR and the tag deployed.
# What we can do in such cases is to try to fetch and zero the code base for those files
# to be patched from master and hope there are no conflicts in the PR.

echo
echo "WARNING: Refreshing all files which are to be patched from origin/master branch:"
echo

# First create destination for test files from master if missing
_createTestFilesDst "master" $testFileList

# Then zero code base for source files from master
_zeroCodeBase "master" $srcFileList

err=0
echo
echo
echo "WARNING: Patching all files starting from origin/master branch"
for patchNum in $patchList
do
    patchFile=/tmp/$patchNum.patch
    echo
    echo
    echo "WARNING: --------------- Currently applying patch: $patchNum ---------------"
    echo "WARNING: cat $patchFile | $patchCmd"
    cat $patchFile | $patchCmd
    let err+=$?
done


echo
echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo WARNING: Second patch attempt exit status: $err
echo
echo

[[ $err -eq 0 ]] || {

    _createTestFilesDst $currTag $testFileList
    _zeroCodeBase $currTag $srcFileList

    echo
    echo WARNING: There were errors while patching from master branch as well
    echo WARNING: All files have been rolled back to their original version at TAG: $currTag
    echo
    echo
    echo WARNING: Please consider checking the follwoing list of files for eventual remnants of code conflicts:
    for file in $srcFileList $testFileList
    do
        echo WARNING: $pythonLibPath/$file
    done
}
echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
exit $err
