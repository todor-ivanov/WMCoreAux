#!/bin/bash

usage()
{
    echo -ne "\nA simple script to facilitate component patching\n"
    echo -ne "and to decrease the development && testing turnaround time.\n"
    echo -ne "Usage: \n ./patchComponent [-z] <patchNum>"
    echo -ne "      -z  - only zero code base to the currently deployed tag - no patches will be applied"
    echo -ne "Examples: "
    echo -ne "\t sudo ./patchComponent.sh 11270\n"
    echo -ne "\t git diff --no-color | sudo ./patchComponent.sh \n or:\n"
    echo -ne "\t curl https://patch-diff.githubusercontent.com/raw/dmwm/WMCore/pull/11270.patch | sudo ./patchComponent.sh \n"
    exit 1
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


patchNum=$1
shift

[[ -z $patchNum ]] && patchNum=temp
echo "Patching WMCore code with PR: $pathcNum"

currTag=$(python -c "from WMCore import __version__ as WMCoreVersion; print(WMCoreVersion)")
echo "Current WMCoreTag: $currTag"


# Find all possible locations for the component source
# NOTE: We always consider PYTHONPATH first
pythonLibPaths=$(echo $PYTHONPATH |sed -e "s/\:/ /g")
pythonLibPaths="$pythonLibPaths $(python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())")"

for path in $pythonLibPaths
do
    [[ -d $path/WMCore ]] && { pythonLibPath=$path; echo "Source code found at: $path"; break ;}
done

[[ -z $pythonLibPath  ]] && { echo "ERROR: Could not find WMCore source to patch"; exit  1 ;}
echo "Current PythonLibPath: $pythonLibPath"

stripLevel=3
patchFile=/tmp/$patchNum.patch

patchCmd="patch -t --verbose -b --version-control=numbered -d $pythonLibPath -p$stripLevel"


if $pipe
then
    # if we run through a pipeline create the temporary patch file for later parsing
    echo "Creating a temporary patchFile at: $patchFile"
    cat <&0 > $patchFile
else
    echo "Downloading a temporary patchFile at: $patchFile"
    curl https://patch-diff.githubusercontent.com/raw/dmwm/WMCore/pull/$patchNum.patch -o $patchFile
fi

srcFileList=`grep diff $patchFile |grep "a/src/python" |awk '{print $3}' |sort |uniq`
testFileList=`grep diff $patchFile |grep "a/test/python" |awk '{print $3}' |sort |uniq`

echo "Refreshing all files which are to be patched from the origin and TAG: $currTag"

# First create destination for test files if missing
for file in $testFileList
do
    file=${file#a\/test\/python\/}
    fileName=`basename $file`
    fileDir=`dirname $file`
    echo orig: https://raw.githubusercontent.com/dmwm/WMCore/$currTag/test/python/$file
    echo dest: $pythonLibPath/$file
    # Create  the path if missing
    mkdir -p $pythonLibPath/$fileDir
    curl -f https://raw.githubusercontent.com/dmwm/WMCore/$currTag/test/python/$file  -o $pythonLibPath/$file || { \
        echo file: $file missing at the origin.
        echo Seems to be a new file for the curren patch.
        echo Removing it from the destination as well!
        rm -f $pythonLibPath/$file
    }
done

# Then zero code base for source files
for file in $srcFileList
do
    file=${file#a\/src\/python\/}
    echo orig: https://raw.githubusercontent.com/dmwm/WMCore/$currTag/src/python/$file
    echo dest: $pythonLibPath/$file
    curl -f https://raw.githubusercontent.com/dmwm/WMCore/$currTag/src/python/$file  -o $pythonLibPath/$file || { \
        echo file: $file missing at the origin.
        echo Seems to be a new file for the curren patch.
        echo Removing it from the destination as well!
        rm -f $pythonLibPath/$file
    }
done

# exit if the user has requested to only zero the code base
$zeroOnly && exit

echo "Patching all files starting from the original version of TAG: $currTag"
echo "cat $patchFile | $patchCmd"
cat $patchFile | $patchCmd
err=$?


echo
echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo
if [[ $err -eq 0 ]]; then
    echo INFO: First patch attempt exit status: $err
    echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
else
    echo WARNING: First patch attempt exit status: $err
    echo
    echo
    echo WARNING: There were errors while patching from TAG: $currTag
    echo WARNING: Most probably some of the files from the current patch were having changes
    echo WARNING: between the current PR and the tag deployed at the host/container.
    echo WARNING: TRYING TO START FROM ORIGIN/MASTER BRANCH INSTEAD:
    echo
    echo
fi


# If we are here it means something went wrong while patching some of the files.
# Most probably some of the files are having changes between the current PR and the tag deployed.
# What we can do in such cases is to try to fetch and zero the code base for those files
# to be patched from master and hope there are no conflicts in the PR.

echo "WARNING:"
echo "WARNING: Refreshing all files which are to be patched from origin/master branch:"

# First create destination for test files if missing
for file in $testFileList
do
    file=${file#a\/test\/python\/}
    fileName=`basename $file`
    fileDir=`dirname $file`
    echo orig: https://raw.githubusercontent.com/dmwm/WMCore/master/test/python/$file
    echo dest: $pythonLibPath/$file
    # Create  the path if missing
    mkdir -p $pythonLibPath/$fileDir
    curl -f https://raw.githubusercontent.com/dmwm/WMCore/master/test/python/$file  -o $pythonLibPath/$file || { \
        echo file: $file missing at the origin.
        echo Seems to be a new file for the curren patch.
        echo Removing it from the destination as well!
        rm -f $pythonLibPath/$file
    }
done

# Then zero code base for source files
for file in $srcFileList
do
    file=${file#a\/src\/python\/}
    echo orig: https://raw.githubusercontent.com/dmwm/WMCore/master/src/python/$file
    echo dest: $pythonLibPath/$file
    curl -f https://raw.githubusercontent.com/dmwm/WMCore/master/src/python/$file  -o $pythonLibPath/$file || { \
        echo file: $file missing at the origin.
        echo Seems to be a new file for the curren patch.
        echo Removing it from the destination as well!
        rm -f $pythonLibPath/$file
    }
done

echo "WARNING: Patching all files starting from origin/master branch"
echo "WARNING: cat $patchFile | $patchCmd"
cat $patchFile | $patchCmd
err=$?

echo
echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo WARNING: Second patch attempt exit status: $err
echo
echo

[[ $err -eq 0 ]] || {
    echo WARNING: There were errors while patching from master branch as well
    echo WARNING: Please consider checking the follwoing list of files for eventual conflicts:
    for file in $srcFileList $testFileList:
    do
        echo WARNING: $pythonLibPath/$file
    done
}
echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
exit $err
