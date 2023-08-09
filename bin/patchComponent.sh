#!/bin/bash

usage()
{
    echo -ne "\nA simple script to facilitate component patching\n"
    echo -ne "and to decrease the development && testing turnaround time.\n"
    echo -ne "Usage: \n"
    echo -ne "\t sudo ./patchComponent.sh (wmagent | reqmon | reqmgr2 | reqmgr2ms...) 11270\n"
    echo -ne "\t git diff --no-color | sudo ./patchComponent.sh (wmagent | reqmon | reqmgr2 | reqmgr2ms...)\n or:\n"
    echo -ne "\t curl https://patch-diff.githubusercontent.com/raw/dmwm/WMCore/pull/11270.patch | sudo ./patchComponent.sh (wmagent | reqmon | reqmgr2 | reqmgr2ms...)\n"
    exit 1
}

# if fd 0 (stdin) is open and refers to a terminal - then we are running the script directly, without a pipe
# if fd 0 (stdin) is open but does not refer to the terminal - then we are running the script through a pipe
if [ -t 0 ] ; then pipe=false; else pipe=true ; fi

# TODO: To check against a list of components
component=$1
shift
patchNum=$1
shift

[[ -z $component ]] && usage
[[ -z $patchNum ]] && patchNum=temp

echo "Patching component: $component"

if [[ $component == "wmagent" ]]
then
    rootDir=/data/srv/$component/current/apps.sw/$component/lib/python*/site-packages
    rootBase=/data/srv/$component/current
else
    rootDir=/data/srv/current/apps.sw/$component/lib/python*/site-packages/
    rootBase=/data/srv/current
fi

stripLevel=3
patchFile=/tmp/$patchNum.patch
currTag=$(basename $(realpath $rootBase))
currTag=${currTag##v}

patchCmd="patch -t --verbose -b --version-control=numbered -d $rootDir -p$stripLevel"


if $pipe
then
    # if we run through a pipeline create the temporary patch file for later parsing
    echo "Creating a temporary patchFile at: $patchFile"
    cat <&0 > $patchFile
else
    echo "Downloading a temporary patchFile at: $patchFile"
    curl https://patch-diff.githubusercontent.com/raw/dmwm/WMCore/pull/$patchNum.patch -o $patchFile
fi


echo "Refreshing all files which are to be patched from the origin"
for file in `grep diff $patchFile |grep "a/src/python" |awk '{print $3}' |sort |uniq`
do
    file=${file#a\/src\/python\/}
    echo orig: https://raw.githubusercontent.com/dmwm/WMCore/$currTag/src/python/$file
    echo dest: $rootDir/$file
    curl  https://raw.githubusercontent.com/dmwm/WMCore/$currTag/src/python/$file  -o $rootDir/$file
done

echo "Patching all files starting from the original version"
cat $patchFile | $patchCmd
