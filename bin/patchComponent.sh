#!/bin/bash

usage()
{
    echo -ne "\nA simple script to facilitate component patching\n"
    echo -ne "and to decrease the development && testing turnaround time.\n"
    echo -ne "Usage: \n"
    echo -ne "\t sudo ./patchComponent.sh 11270\n"
    echo -ne "\t git diff --no-color | sudo ./patchComponent.sh \n or:\n"
    echo -ne "\t curl https://patch-diff.githubusercontent.com/raw/dmwm/WMCore/pull/11270.patch | sudo ./patchComponent.sh \n"
    exit 1
}

while getopts ":zh" opt; do
    echo opt: $opt
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
        *)
            echo "We are Here: OPTARG=$OPTARG"
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

fileList=`grep diff $patchFile |grep "a/src/python" |awk '{print $3}' |sort |uniq`

echo "Refreshing all files which are to be patched from the origin and TAG: $currTag"
for file in $fileList
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
cat $patchFile | $patchCmd && exit
err=$?


echo
echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo First patch attempt exit status: $err
echo
echo
echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# If we are here it means something went wrong while patching some of the files.
# Most probably some of the files are having changes between the current PR and the tag deployed.
# What we can do in such cases is to try to fetch and zero the code base for those files
# to be patched from master and hope there are no conflicts in the PR.

echo "Refreshing all files which are to be patched from origin/master branch:"
for file in $fileList
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

echo "Patching all files starting from origin/master branch"
echo "cat $patchFile | $patchCmd"
cat $patchFile | $patchCmd && exit
err=$?

echo
echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo Second patch attempt exit status: $err
echo
echo
echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

