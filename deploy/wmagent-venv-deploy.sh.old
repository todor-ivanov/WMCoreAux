#!/usr/bin/env bash

help(){
    echo -e $1
    cat <<EOF
    Usage: wmagent-venv-deploy.sh [-s] [-n] [-v] [-y]
                                  [-r <wmcore_source_repository>] [-b <wmcore_source_branch>] [-t <wmcore_tag>]
                                  [-g <wmcore_config_repository>] [-d <wmcore_config_branch>]
                                  [-d wmcore_path] [-p <patches>] [-m <security string>]
                                  [-l <service_list>] [-i <pypi_index>]
                                  [-h <help>]

      -s  <run_from_source>          Bool flag to setup run from source [Default: false]
      -n  <no_venv_cleanup>          Bool flag to skip virtual environment space cleanup before deployment [Default: false - ALWAYS cleanup before deployment]
      -v  <verbose_mode>             Bool flag to set verbose mode [Default: false]
      -y  <assume yes>               Bool flag to assume 'Yes' to all deployment questions.
      -r  <wmcore_source_repository> WMCore source repository [Default: git://github.com/dmwm/wmcore.git"]
      -b  <wmcore_source_branch>     WMCore source branch [Default: master]
      -t  <wmcore_tag>               WMCore tag to be used for this deployment [Default: None]
      -d  <wmagent_path>             WMAgent virtual environment target path to be used for this deployment [Default: ./WMAgent.venv3]
      -h <help>                      Provides help to the current script

    # Example: Deploy WMAgent version 2.0.3rc1 from 'test' pypi index
    #          at destination /data/tmp/WMAgent.venv3/ and using 'Some security string' as a security string for operationss at runtime:
    # ./wmagent-venv-deploy.sh -i test -l wmcore==2.0.3rc1 -d /data/tmp/WMAgent.venv3/ -m "Some security string"

    # Example: Same as above, but do not cleanup deployment area and reuse it from previous installtion - usefull for testing behaviour
    #          of different versions during development or mix running from source and from pypi installed packages.
    #          NOTE: The 'current' link must point to the proper deployment area e.g. either to 'srv/master' for running from source
    #                or to 'srv/2.0.3rc1' for running from pypi installed package):
    # ./wmagent-venv-deploy.sh -n -i test -l wmcore==2.0.3rc1 -d /data/tmp/WMAgent.venv3/ -m "Some security string"

    # Example: Deploy WMAgent from source repository, use tag 2.0.0.pre3,
    #          at destination /data/tmp/WMAgent.venv3/ and using 'Some security string' as a security string for operationss at runtime:
    # ./wmagent-venv-deploy.sh -s -t 2.0.0.pre3 -d /data/tmp/WMAgent.venv3/ -m "Some security string"

    # Example: Same as above, but assume 'Yes' to all questions. To be used in order to chose the default flow and rely only
    #          on the pameters set for configuring the deployment steps. This will avoid human intervention during deployment:
    # ./wmagent-venv-deploy.sh -y -s -t 2.0.0.pre3 -d /data/tmp/WMAgent.venv3/ -m "Some security string"

    # Example: Deploy WMAgent from source repository, use tag 2.0.0.pre3, linked with a frontend defined from service_config files
    #          at destination /data/tmp/WMAgent.venv3/ and using 'Some security string' as a security string for operationss at runtime:
    # ./wmagent-venv-deploy.sh -s -t 2.0.0.pre3 -d /data/tmp/WMAgent.venv3/ -m "Some security string"

    # DEPENDENCIES: All WMCore packages have OS or external libraries/packages dependencies, which are not having a pypi equivalent.
    #               So far those has been resolved through the set of *.spec files maintained at: https://github.com/cms-sw/cmsdist/tree/comp_gcc630
    #               Here follows the list of all direct (first level) dependencies per service generated from those spec files:

    #               wmagent           : [python3, MariaDB, CouchDB]

    #               The above list is generated from the 'cmsdist' repository by:
    #               git clone https://github.com/cms-sw/cmsdist/tree/comp_gcc630
    #               python WMCore/bin/adhoc-scripts/ParseSpecCmsswdist.py -a -d cmsdist/ -f <service.spec, e.g. reqmgr2ms.spec>

EOF
}

usage(){
    echo -e $1
    help
    exit 1
}

_realPath(){
    # A function to find the absolute path of a given entity (directory or file)
    # It also expands and follows soft links e.g. if we have the following link:
    #
    # $ ll ~/WMCoreDev.d
    # lrwxrwxrwx 1 user user 21 Apr 15  2020 /home/user/WMCoreDev.d -> Projects/WMCoreDev.d/
    #
    # An entity from inside the linked path will be expanded as:
    # $ _realPath ~/WMCoreDev.d/DBS
    # /home/user/Projects/WMCoreDev.d/DBS
    #
    # It uses only bash internals for compatibility with any Unix-like OS capable of running bash.
    # For simplicity reasons, it does not support shell path expansions like:
    # /home/*/WMCoreDev.d, but can be used with single paths solely.
    #
    # :param $1: The path to be followed to the / (root) base
    # :return:   Echos the absolute path of the entity

    [[ -z $1 ]] &&  return
    pathExpChars="\? \* \+ \@ \! \{ \} \[ \]"
    for i in $pathExpChars
    do
        # Path name expansion not supported
        [[ $1 =~ .*${i}.* ]] &&  return 38
    done
    sufix="$(basename $1)"
    prefix=$(dirname $1)
    until cd $prefix
    do
        sufix="$(basename $prefix)/$sufix"
        prefix=$(dirname $prefix)
    done  2>/dev/null
    realPath=$(pwd -P)
    userPath=$sufix
    if [[ $realPath == "/" ]]
    then
        echo ${realPath}${userPath}
    else
        echo ${realPath}/${userPath}
    fi
    cd - 2>&1 >/dev/null
}


# _realPath(){
#     $( cd "$(dirname "$0")" ; pwd -P )
# }


FULL_SCRIPT_PATH="$(_realPath "${0}")"

# Setting default values for all input parameters.
# Command line options overwrite the default values.
# All of the lists from bellow are interval separated.
# e.g. serviceList="admin reqmgr2 reqmgr2ms workqueue reqmon acdcserver"

serviceList="wmagent"                                                     # default is the WMCore meta package
venvPath=$(_realPath "./WMAgent.venv3")                                    # WMCore virtual environment target path
wmSrcRepo="https://github.com/dmwm/WMCore.git"                            # WMCore source Repo
wmSrcBranch="master"                                                      # WMCore source branch
wmCfgRepo="https://:@gitlab.cern.ch:8443/cmsweb-k8s/services_config.git"  # WMCore config Repo
wmCfgBranch="test"                                                        # WMCore config branch
wmTag=""                                                                  # wmcore tag Default: no tag
serPatch=""                                                               # a list of service patches to be applied
runFromSource=false                                                       # a bool flag indicating run from source
pipIndex="prod"                                                           # pypi Index to use
verboseMode=false
assumeYes=false
noVenvCleanup=false                                                       # a Bool flag to state if the virtual env is to be cleaned before deployment
secString=""                                                              # The security string to be used during deployment.
                                                                          # This one will be needed later to start the services.

# NOTE: We are about to stick to Python3 solely from now on. So if the default
#       python executable for the system we are working on (outside the virtual
#       environment) is linked to Python2, then we should try creating the environment
#       with `python3' instead of `python`. If this link is not present, we simply
#       fail during virtual environment creation. Once we are inside the virtual
#       environment the default link should always point to e Python3 executable
#       so the `pythonCmd' variable shouldn't be needed any more.

pythonCmd=python
[[ $(python -V 2>&1) =~ Python[[:blank:]]+2.* ]] && pythonCmd=python3


### Searching for the mandatory and optional arguments:
# export OPTIND=1
while getopts ":t:r:b:g:j:d:p:m:l:i:snvyh" opt; do
    case ${opt} in
        d)
            venvPath=$OPTARG
            venvPath=$(_realPath $venvPath) ;;
        t)
            wmTag=$OPTARG ;;
        r)
            wmSrcRepo=$OPTARG ;;
        b)
            wmSrcBranch=$OPTARG ;;
        g)
            wmCfgRepo=$OPTARG ;;
        j)
            wmCfgBranch=$OPTARG ;;
        p)
            serPatch=$OPTARG ;;
        m)
            secString=$OPTARG ;;
        l)
            serviceList=$OPTARG ;;
        i)
            pipIndex=$OPTARG ;;
        s)
            runFromSource=true ;;
        n)
            noVenvCleanup=true ;;
        v)
            verboseMode=true ;;
        y)
            assumeYes=true ;;
        h)
            help
            exit 0 ;;
        \? )
            msg="Invalid Option: -$OPTARG"
            usage "$msg" ;;
        : )
            msg="Invalid Option: -$OPTARG requires an argument"
            usage "$msg" ;;
    esac
done

$verboseMode && set -x

# Swap noVenvCleanup flag with venvCleanup to avoid double negation and confusion:
venvCleanup=true && $noVenvCleanup && venvCleanup=false

# Calculate the security string md5 sum;
secString=$(echo $secString | md5sum | awk '{print $1}')

# expand the enabled services list
# TODO: Find a proper way to include the `acdcserver' in the list bellow (its config is missing from service_configs).
if [[ ${serviceList} =~ ^wmcore.* ]]; then
    _enabledListTmp="reqmgr2 reqmgr2ms workqueue reqmon t0_reqmon"
else
    _enabledListTmp=$serviceList
fi

# NOTE: The following extra expansion won't be needed once we have the set of
#       python packages we build to be identical with the set of services we run
#       Meaning we need to split them as:
#       reqmgr2ms -> [reqmgr2ms-transferor, reqmgr2ms-monitor, reqmgr2ms-output,
#                     reqmgr2ms-ruleCleaner, reqmgr2ms-unmerged]
#       reqmgr2   -> [reqmgr, reqmgr2-tasks]
#       reqmon    -> [reqmon, reqmon-tasks]
#       t0_reqmon -> [t0_reqmon, t0_reqmon-tasks]
enabledList=""
for service in $_enabledListTmp
do
    # First cut all pypi packaging version suffixes
    service=${service%%=*}
    service=${service%%~*}
    service=${service%%!*}
    service=${service%%>*}
    service=${service%%<*}

    # Then expand the final enabled list
    if [[ $service == "reqmgr2ms" ]]; then
        enabledList="$enabledList reqmgr2ms-transferor"
        enabledList="$enabledList reqmgr2ms-monitor"
        enabledList="$enabledList reqmgr2ms-output"
        enabledList="$enabledList reqmgr2ms-rulecleaner"
        enabledList="$enabledList reqmgr2ms-unmerged"
        enabledList="$enabledList reqmgr2ms-pileup"
    elif [[ $service == "reqmgr2" ]]; then
        enabledList="$enabledList reqmgr2"
        enabledList="$enabledList reqmgr2-tasks"
    elif [[ $service == "reqmon" ]]; then
        enabledList="$enabledList reqmon"
        enabledList="$enabledList reqmon-tasks"
    elif [[ $service == "t0_reqmon" ]] ; then
        enabledList="$enabledList t0_reqmon"
        enabledList="$enabledList t0_reqmon-tasks"
    else
        enabledList="$enabledList $service"
    fi
done

# setting the default pypi options
pipIndexTestUrl="https://test.pypi.org/simple/"
pipIndexProdUrl="https://pypi.org/simple"

pipOpt="--no-cache-dir"
[[ $pipIndex == "test" ]] && {
    pipOpt="$pipOpt --index-url $pipIndexTestUrl --extra-index $pipIndexProdUrl" ;}

[[ $pipIndex == "prod" ]] && {
    pipOpt="$pipOpt --index-url $pipIndexProdUrl" ;}

# declaring the initial WMCoreVenvVars as an associative array in the global scope
declare -A WMCoreVenvVars

_addWMCoreVenvVar(){
    # Adding a WMCore virtual environment variable to the WMCoreVenvVars array
    # and to the current virtual environment itself
    # :param $1: The variable name
    # :param $2: The actual export value to be used
    local varName=$1
    local exportVal=$2
    WMCoreVenvVars[$varName]=$exportVal
    eval "export $varName=$exportVal"
}

handleReturn(){
    # Handling script interruption based on last exit code
    # Return codes:
    # 0     - Success - CONTINUE
    # 100   - Success - skip step, consider it recoverable
    # 101   - Success - skip step based on user choice
    # 102   - Failure - interrupt execution based on user choice
    # 1-255 - Failure - interrupt all posix return codes

    # TODO: to test return codes compatibility to avoid system error codes overlaps

    case $1 in
        0)
            return 0
            ;;
        100)
            echo "Skipping step due to execution errors. Continue script execution."
            return 0
            ;;
        101)
            echo "Skipping step due to user choice. Continue script execution."
            return 0
            ;;
        102)
            echo "Interrupt execution due to user choice."
            exit 102
            ;;
        *)
            echo "Interrupt execution due to step failure: "
            echo "ERRORNO: $1"
            exit $1
            ;;
    esac
}

startSetupVenv(){
    # A function used for Initial setup parameters visualisation. It waits for 5 sec.
    # before continuing, to give the option for canceling in case of wrong parameter set.
    # :param: None

    echo "======================================================="
    echo "Deployment parameters:"
    echo "-------------------------------------------------------"
    echo "serviceList          : $serviceList"
    echo "enabledList          : $enabledList"
    echo "venvPath             : $venvPath"
    echo "wmCfgRepo            : $wmCfgRepo"
    echo "wmCfgBranch          : $wmCfgBranch"
    echo "wmSrcRepo            : $wmSrcRepo"
    echo "wmSrcBranch          : $wmSrcBranch"
    echo "wmTag                : $wmTag"
    echo "serPatch             : $serPatch"
    echo "pypi Index           : $pipIndex"
    echo "runFromSource        : $runFromSource"
    echo "Cleanup Virtual Env  : $venvCleanup"
    echo "verboseMode          : $verboseMode"
    echo "assumeYes            : $assumeYes"
    echo "secSring             : $secString"
    echo "pythonCmd            : $pythonCmd and `which $pythonCmd`"
    echo "======================================================="
    echo -n "Continue? [y]: "
    $assumeYes || read x && [[ $x =~ (n|no|nO|N|No|NO) ]] && return 102
    echo "..."
    echo "You still have 5 sec. to cancel before we proceed."
    sleep 5
}

createVenv(){
    # Function for creating minimal virtual environment. It uses global
    # $venvCleanup to check if to clean the venv space before deployment.
    # :param: None
    echo
    echo "======================================================="
    echo "Creating minimal virtual environment:"
    echo -n "Continue? [y]: "
    $assumeYes || read x && [[ $x =~ (n|no|nO|N|No|NO) ]] && return 102
    echo "..."

    [[ -d $venvPath ]] || mkdir -p $venvPath || return $?
    if $venvCleanup ; then
        $pythonCmd -m venv --clear $venvPath || return $?
    else
        $pythonCmd -m venv $venvPath || return $?
    fi
}

cloneWMCore(){
    # Function for cloning WMCore source code and checkout to the proper branch
    # or tag based on the script's runtime prameters.
    # :param: None
    echo
    echo "======================================================="
    echo "Cloning WMCore source code:"
    echo -n "Continue? [y]: "
    $assumeYes || read x && [[ $x =~ (n|no|nO|N|No|NO) ]] && return 101
    echo "..."

    wmSrcPath=${venvPath}/srv/WMCore           # WMCore source code target path

    # NOTE: If the Virtual Environment is not to be cleaned during the current
    #       deployment and we already have either a source directory synced from
    #       previous deployments or a link at $wmSrcPath pointing to a source
    #       directory outside the virtual env. we simply skip git actions to protect
    #       developer's previous work.
    if $noVenvCleanup && ( [[ -d $wmSrcPath ]] || [[ -h $wmSrcPath ]] ); then
        echo "WMCore source has already been cloned and the NO Virtual Environment Cleanup is True."
        return 101
    else
        [[ -d $wmSrcPath ]] ||  mkdir -p $wmSrcPath || return $?
        cd $wmSrcPath
        git clone $wmSrcRepo $wmSrcPath && git checkout $wmSrcBranch && [[ -n $wmTag ]] && git reset --hard $wmTag
        cd -
    fi
}

_pipUpgradeVenv(){
    # Helper function used only for pip Upgrade for the current virtual env
    # :param: None
    cd $venvPath
    # pip install $pipOpt wheel
    # pip install $pipOpt --upgrade pip
    pip install wheel
    pip install --upgrade pip
}

activateVenv(){
    # Function for activating the virtual environment
    # :param: None
    echo
    echo "======================================================="
    echo "Activate WMCore virtual env:"
    echo -n "Continue? [y]: "
    $assumeYes || read x && [[ $x =~ (n|no|nO|N|No|NO) ]] && return 102
    echo "..."
    source ${venvPath}/bin/activate
    _pipUpgradeVenv
}

_pkgInstall(){
    # Helper function to follow default procedure in trying to install a package
    # through pip and eventually resolve package dependency issues.
    # :param $*: A string including a space separated list of all packages to be installed

    pkgList=$*
    pkgFail=""
    for pkg in $pkgList
    do
        pip install $pipOpt $pkg || pkgFail="$pkgFail $pkg"
    done

    [[ -z $pkgFail ]] || {
        echo
        echo "======================================================="
        echo "There were some package dependencies that couldn't be satisfied."
        echo "List of packages failed to install: $pkgFail"
        echo -n "Should we try to reinstall them while releasing version constraint? [y]: "
        $assumeYes || read x && [[ $x =~ (n|no|nO|N|No|NO) ]] && return 101
        echo "..."
        echo "Retrying to satisfy dependency releasing version constraint:"
        # NOTE: by releasing the package constrains here and installing from `test'
        #       pypi index but also using the `prod' index for resolving dependency issues)
        #       we may actually downgrade a broken new package uploaded at `test'
        #       with an older but working version from `prod'. We may consider
        #       skipping the step in the default flaw and keep it only for manual
        #       setup and debugging purposes
        for pkg in $pkgFail
        do
            pkg=${pkg%%=*}
            pkg=${pkg%%~*}
            pkg=${pkg%%!*}
            pkg=${pkg%%>*}
            pkg=${pkg%%<*}
            pip install $pipOpt $pkg
        done ;}
}

setupDependencies(){
    # Function to install all WMCore python dependencies inside the virtual environment
    # based on the default WMCore/requirements.txt file. It will be found only if we
    # are deploying from source, otherwise the dependencies will be resolved by the
    # pypi package requirements and the step will be skipped. If not all dependencies
    # are satisfied a WARNING message is printed and the setup continues.
    # :param: None
    echo
    echo "======================================================="
    echo "Install all WMCore python dependencies inside the virtual env:"
    echo -n "Continue? [y]: "
    $assumeYes || read x && [[ $x =~ (n|no|nO|N|No|NO) ]] && return 101
    echo "..."

    reqList=""
    reqFile=${wmSrcPath}/"requirements.txt"
    [[ -d $wmSrcPath ]] || { echo "Could not find WMCore source at: $wmSrcPath"; return 100 ;}
    [[ -f $reqFile ]] || { echo "Could not find requirements.txt file at: $reqFile"; return 100 ;}

    # first try to install the whole requirement list as it is from the global/prod pypi index
    pip install -r $reqFile && { echo "Dependencies successfully installed"; return 0 ;}

    # only then try to parse the list a package at a time and install from the pypi index used for the current run
    for pkg in `grep -v ^# $reqFile|awk '{print $1}'`
    do
        reqList="$reqList $pkg"
    done
    _pkgInstall $reqList || { echo "We did the best we could to deploy all needed packages but there are still unresolved dependencies. Consider fixing them manually! "; return 100 ;}

}

setupRucio(){
    # Function to create a minimal setup for the Rucio package inside the virtual
    # environment. It uses rucio integration as default server to avoid interference
    # with production installations.
    # :param: None

    # NOTE: This configuration files will be used mostly during operations and
    #       development or running from source. The different services usually rely
    #       on their own configuration service_config script for defining the Rucio
    #       instance, but we still my consider adding an extra parameter to the script

    echo
    echo "======================================================="
    echo "Create minimal Rucio client setup inside the virtual env:"
    echo -n "Continue? [y]: "
    $assumeYes || read x && [[ $x =~ (n|no|nO|N|No|NO) ]] && return 101
    echo "..."

    _pkgInstall rucio-clients
    # _addWMCoreVenvVar "RUCIO_HOME" "$venvPath/"
    _addWMCoreVenvVar RUCIO_HOME $wmCurrPath

    cat <<EOF > $RUCIO_HOME/etc/rucio.cfg
[common]
[client]
rucio_host = http://cmsrucio-int.cern.ch
auth_host = https://cmsrucio-auth-int.cern.ch
auth_type = x509
ca_cert = /etc/grid-security/certificates/
client_cert = \$X509_USER_CERT
client_key = \$X509_USER_KEY
client_x509_proxy = \$X509_USER_PROXY
request_retries = 3
EOF
}

setupIpython(){
    # Helper function to install Ipython during manual installation, it is skipped by default.
    # :param: None
    echo
    echo "======================================================="
    echo "If the current environment is about to be used for deployment Ipython would be a good recomemndation, but is not mandatory."
    echo -n "Install Ipython? [y]: "
    $assumeYes || read x && [[ $x =~ (n|no|nO|N|No|NO) ]] && return 101
    echo "Installing ipython..."
    pip install ipython
}

setupVenvHooks(){
    # Function used for setting up the WMCore virtual environment hooks
    # It uses the WMCoreVenvVars from the global scope. We also redefine the
    # deactivate function for the virtual environment such that we can restore
    # all WMCore related env. variables at deactivation time.
    # :param: None
    echo
    echo "======================================================="
    echo "Setup the WMCore hooks at the virtual environment activate script"
    echo -n "Continue? [y]: "
    $assumeYes || read x && [[ $x =~ (n|no|nO|N|No|NO) ]] && return 101
    echo "..."

    echo "############# WMCore env vars ################" >> ${VIRTUAL_ENV}/bin/activate
    echo "declare -A WMCoreVenvVars" >> ${VIRTUAL_ENV}/bin/activate
    for var in ${!WMCoreVenvVars[@]}
    do
        echo "WMCoreVenvVars[$var]=${WMCoreVenvVars[$var]}" >> ${VIRTUAL_ENV}/bin/activate
        # echo -e "WMCoreVenvVars[$var]\t:\t${WMCoreVenvVars[$var]}"
    done

    # NOTE: If we have the WMCore hooks setup at the current virtual environment
    #       from previous deployments, we only need to be sure we execute _WMCoreVenvSet
    #       the last, so we fetch the newly added environment values. This is
    #       an extra precaution, because `${VIRTUAL_ENV}/bin/activate' should be
    #       recreated from scratch for a fresh virtual environment anyway, but we
    #       need to take measures in case this behaviour changes in the future.

    if grep "#* WMCore hooks #*" ${VIRTUAL_ENV}/bin/activate
    then
        sed -i 's/_WMCoreVenvSet.*WMCoreVenvVars\[\@\].*//g' ${VIRTUAL_ENV}/bin/activate
        cat <<EOF>>${VIRTUAL_ENV}/bin/activate
_WMCoreVenvSet \${!WMCoreVenvVars[@]}

EOF
    else
        cat <<EOF>>${VIRTUAL_ENV}/bin/activate

############# WMCore hooks ################

_old_deactivate=\$(declare -f deactivate)
_old_deactivate=\${_old_deactivate#*()}
eval "_old_deactivate() \$_old_deactivate"

_WMCoreVenvRrestore(){
    echo "Restoring all WMCore related environment variables:"
    local WMCorePrefix=_OLD_WMCOREVIRTUAL
    for var in \$@
    do
        local oldVar=\${WMCorePrefix}_\${var}
        unset \$var
        [[ -n \${!oldVar} ]] && export \$var=\${!oldVar}
        unset \$oldVar
    done
}

_WMCoreVenvSet(){
    echo "Setting up WMCore related environment variables:"
    local WMCorePrefix=_OLD_WMCOREVIRTUAL
    for var in \$@
    do
        local oldVar=\${WMCorePrefix}_\${var}
        [[ -n \${!var} ]] && export \$oldVar=\${!var}
        export \$var=\${WMCoreVenvVars[\$var]}
    done
}

deactivate (){
    _WMCoreVenvRrestore \${!WMCoreVenvVars[@]}
    _old_deactivate
}

_WMCoreVenvSet \${!WMCoreVenvVars[@]}

EOF
    fi
}

checkNeeded(){
    # Function used to check the current script dependencies.
    # It uses hard coded list of tools required by the current script in order
    # to be able to complete the run.
    # :param: None

    # NOTE: First of all, check for minimal bash version required.
    #       Associative arrays are not supported for bash versions earlier than 4.*
    #       This causes issues on OS X systems with the following error:
    #       ./wmagent-venv-deploy.sh: line 280: declare: -A: invalid option
    #       declare: usage: declare [-afFirtx] [-p] [name[=value] ...]
    verString=$(bash --version)
    [[ $verString =~ ^GNU[[:blank:]]+bash,[[:blank:]]+version[[:blank:]]+[4-9]+\..* ]] || {
        error=$?;
        echo "The current setup script requires bash version: 4.* or later. Please install it and rerun.";
        return $error ;}

    local neededTools="git awk grep md5sum tree"
    for tool in $neededTools
    do
        command -v $tool 2>&1 > /dev/null || {
            error=$?;
            echo "The current setup script requires: $tool in order to continue. Please install it and rerun." ;
            return $error ;}
    done
}

_sort(){
    # Simple auxiliary sort function.
    # :param $*: All parameters need to be string values to be sorted
    # :return:   Prints the alphabetically sorted list of all input parameters
    local -a result
    i=0
    result[$i]=$1
    shift
    for key in $*
    do
        let i++
        x=$i
        y=$i
        result[$i]=$key
        while [[ $x -gt 0 ]]
        do
            let x--
            if [[ ${result[$x]} > ${result[$y]} ]]; then
                tmpKey=${result[$x]}
                result[$x]=${result[$y]}
                result[$y]=$tmpKey
            else
                break
            fi
            let y--
        done
    done
    echo ${result[*]}
}

printVenvSetup(){
    # Function to print the current virtual environment setup. And a basic
    # deployment area tree, no deeper than 3 levels relative to the deployment
    # root path.
    # :param:  None
    # :return: Dumps a formatted string with the information for the current setup

    echo "======================================================="
    echo "Printing the final WMCore virtual environment parameters and tree:"
    echo "-------------------------------------------------------"
    echo
    tree -d -L 3 $venvPath
    echo
    echo "-------------------------------------------------------"

    local prefix="WMCoreVenvVars[]: "
    local prefixLen=${#prefix}

    # NOTE: Here choosing the common alignment position for all variables printed
    #       the position count starts from the beginning of line + prefixLen.
    local valAllign=0
    for var in ${!WMCoreVenvVars[@]}
    do
        vLen=${#var}
        [[ $valAllign -lt $vLen ]] && valAllign=$vLen
    done

    for var in $(_sort ${!WMCoreVenvVars[@]})
    do
        vLen=${#var}
        spaceLen=$(($valAllign - $vLen))
        space=""
        for ((i=0; i<=$spaceLen; i++))
        do
            space="$space "
        done
        spaceNewLineLen=$(($spaceLen + $prefixLen +$vLen))
        spaceNewLine=""
        for ((i=0; i<=$spaceNewLineLen; i++))
        do
            spaceNewLine="$spaceNewLine "
        done
        echo -e "WMCoreVenvVars[$var]${space}: ${WMCoreVenvVars[$var]//:/\n$spaceNewLine}"

    done
}

wmaInstall() {
    # The main function to setup/add the WMAgent virtual environment variables
    # and call the install.sh script from: https://github.com/dmwm/CMSKubernetes/blob/master/docker/pypi/wmagent/install.sh

    venvPath=$(_realPath $venvPath)
    deployRepo=https://github.com/todor-ivanov/CMSKubernetes.git
    deployBranch=Fix_WMAgentPyPi_DcokerImage
    echo "Cloning $deployRepo at $venvPath"
    cd $venvPath
    git clone $deployRepo
    cd $venvPath/CMSKubernetes
    git checkout $deployBranch
    cd $venvPath/CMSKubernetes/docker/pypi/wmagent

    export WMA_TAG=$wmTag
    export WMA_USER=$(id -un)
    export WMA_GROUP=$(id -gn)
    export WMA_UID=$(id -u)
    export WMA_GID=$(id -g)
    export WMA_ROOT_DIR=$venvPath

    # Basic WMAgent directory structure passed to all scripts through env variables:
    # NOTE: Those should be static and depend only on $WMA_BASE_DIR
    export WMA_BASE_DIR=$WMA_ROOT_DIR/srv
    export WMA_ADMIN_DIR=$WMA_ROOT_DIR/admin/wmagent
    export WMA_CERTS_DIR=$WMA_ROOT_DIR/certs

    export WMA_HOSTADMIN_DIR=$WMA_ADMIN_DIR/hostadmin
    export WMA_CURRENT_DIR=$WMA_BASE_DIR/wmagent/current
    export WMA_INSTALL_DIR=$WMA_CURRENT_DIR/install
    export WMA_CONFIG_DIR=$WMA_CURRENT_DIR/config
    export WMA_MANAGE_DIR=$WMA_CONFIG_DIR/wmagent
    export WMA_DEPLOY_DIR=$venvPath
    export WMA_ENV_FILE=$WMA_DEPLOY_DIR/deploy/env.sh

    # Setting up users and previleges
    sudo groupadd -g ${WMA_GID} ${WMA_GROUP}
    sudo useradd -u ${WMA_UID} -g ${WMA_GID} -m ${WMA_USER}
    # sudo install -o ${WMA_USER} -g ${WMA_GID} -d ${WMA_ROOT_DIR}
    sudo usermod -aG mysql ${WMA_USER}

    # Add WMA_USER to sudoers
    # sudo echo "${WMA_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

    # Add all deployment needed directories
    cp -rv bin/* $WMA_DEPLOY_DIR/bin/
    cp -rv etc $WMA_DEPLOY_DIR/
    cp -rv install.sh ${WMA_ROOT_DIR}/install.sh

    # Add install script
    cp -rv  install.sh ${WMA_ROOT_DIR}/install.sh

    # Add wmagent run script
    cp -rv run.sh ${WMA_ROOT_DIR}/run.sh

    cd $WMA_ROOT_DIR

    # Remove the already unneeded CMKubernetes repository:
    rm -rf $venvPath/CMSKubernetes

    # Install the requested WMA_TAG.
    ${WMA_ROOT_DIR}/install.sh -v ${WMA_TAG}
    # chown -R ${WMA_USER}:${WMA_GID} ${WMA_ROOT_DIR}

    # Add all environment variables to the virtEnv hooks
    # _addWMCoreVenvVar X509_USER_CERT ${wmAuthPath}/dmwm-service-cert.pem
    # _addWMCoreVenvVar X509_USER_KEY ${wmAuthPath}/dmwm-service-key.pem
    _addWMCoreVenvVar WMA_TAG $WMA_TAG
    _addWMCoreVenvVar WMA_USER $WMA_USER
    _addWMCoreVenvVar WMA_GROUP $WMA_GROUP
    _addWMCoreVenvVar WMA_UID $WMA_UID
    _addWMCoreVenvVar WMA_GID $WMA_GID
    _addWMCoreVenvVar WMA_ROOT_DIR $WMA_ROOT_DIR
    _addWMCoreVenvVar WMA_BASE_DIR $WMA_BASE_DIR
    _addWMCoreVenvVar WMA_ADMIN_DIR $WMA_ADMIN_DIR
    _addWMCoreVenvVar WMA_CERTS_DIR $WMA_CERTS_DIR
    _addWMCoreVenvVar WMA_HOSTADMIN_DIR $WMA_HOSTADMIN_DIR
    _addWMCoreVenvVar WMA_CURRENT_DIR $WMA_CURRENT_DIR
    _addWMCoreVenvVar WMA_INSTALL_DIR $WMA_INSTALL_DIR
    _addWMCoreVenvVar WMA_CONFIG_DIR $WMA_CONFIG_DIR
    _addWMCoreVenvVar WMA_MANAGE_DIR $WMA_MANAGE_DIR
    _addWMCoreVenvVar WMA_DEPLOY_DIR $WMA_DEPLOY_DIR
    _addWMCoreVenvVar WMA_ENV_FILE $WMA_ENV_FILE

    # add $wmSrcPath in front of everything if we are running from source
    if $runFromSource; then
        _addWMCoreVenvVar PYTHONPATH ${wmSrcPath}/src/python/:$PYTHONPATH
        _addWMCoreVenvVar PATH ${wmSrcPath}/bin/:$PATH
    #     _addWMCoreVenvVar WMCORE_SERVICE_SRC ${wmSrcPath}
    fi

}

tweakVenv(){
    # A function to tweak some Virtual Environment specific things, which are
    # in general hard coded in the Docker image
    echo "-------------------------------------------------------"
    echo "Edit $WMA_DEPLOY_DIR/deploy/env.sh script to point to \$WMA_ROOT_DIR"
    sed -i "s|/data/|\$WMA_ROOT_DIR/|g" $WMA_DEPLOY_DIR/deploy/env.sh
    echo "Edit $WMA_DEPLOY_DIR/deploy/renew_proxy.sh script to point to \$WMA_ROOT_DIR"
    sed -i "s|/data/|\$WMA_ROOT_DIR/|g" $WMA_DEPLOY_DIR/deploy/renew_proxy.sh
    sed -i "s|source.*env\.sh|source \$WMA_ENV_FILE|g" $WMA_DEPLOY_DIR/deploy/renew_proxy.sh
    cat $WMA_DEPLOY_DIR/deploy/env.sh
    echo "-------------------------------------------------------"

    echo "Copy certificates and WMAgent.secrets file from an old current agent"
    cp -v /data/certs/servicekey.pem  $WMA_CERTS_DIR/
    cp -v /data/admin/wmagent/WMAgent.secrets $WMA_ROOT_DIR/admin/wmagent/hostadmin/
    cp -v /data/certs/servicecert.pem  $WMA_CERTS_DIR/
    echo "-------------------------------------------------------"

    echo "Eliminate mount points checks"
    sed -Ei "s/^_check_mounts.*().*\{.*$/_check_mounts() \{ return \$(true)/g" $WMA_ROOT_DIR/run.sh
}

main(){
    checkNeeded      || handleReturn $?
    startSetupVenv   || handleReturn $?
    createVenv       || handleReturn $?
    activateVenv     || handleReturn $?
    # setupDeplTree    || handleReturn $?
    if $runFromSource; then
        cloneWMCore  || handleReturn $?
        setupDependencies|| handleReturn $?
    fi
    wmaInstall       || handleReturn $?
    tweakVenv        || handleReturn $?
    # setupRucio       || handleReturn $?
    setupIpython     || handleReturn $?
    setupVenvHooks   || handleReturn $?
    printVenvSetup
}

startPath=$(pwd)
main
cd $startPath
