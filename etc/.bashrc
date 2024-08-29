# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

k8init(){
    workPath=~/WMCoreDev.d/deploy/deploymentK8
    [[ -d $workPath ]] || mkdir -p $workPath
    cd $workPath || { echo "ERROR: Missing working directory"; return ;}
    unset OS_TOKEN
    export OS_TOKEN=$(openstack token issue -c id -f value)
    case $1 in
        'prod')
            # config=config.cmsweb-k8s-services-prod
            # [[ -f $config ]] && rm $config
            # [[ -f config.cmsweb-k8s-services-prod ]] || wget https://cernbox.cern.ch/index.php/s/cg373hUAglJ2mwI/download -O $config
            # [[ -f config.cmsweb-k8s-services-prod ]] || wget https://cernbox.cern.ch/index.php/s/gLNiHYaGF8QbPrO/download -O config.cmsweb-k8s-services-prod -O config.cmsweb-k8s-services-prod
            # export KUBECONFIG=$workPath/config.cmsweb-k8s-services-prod
            # export KUBECONFIG=$workPath/users_config/config.prod/config.cmsweb-k8s-services-prod
            export KUBECONFIG=$workPath/users_config/config.prod/config.k8s-prodsrv2
            # export KUBECONFIG=$workPath/users_config/config.prod/config
            ;;
        'prod-old')
            export KUBECONFIG=$workPath/users_config/config.prod/config.cmsweb-k8s-services-prod
            ;;

        'preprod')
            # [[ -f config.cmsweb-testbed ]] || wget https://cernbox.cern.ch/index.php/s/o4pP0BKhNdbPhCv/download -O config.cmsweb-testbed
            # export KUBECONFIG=$workPath/config.cmsweb-testbed
            export KUBECONFIG=$workPath/users_config/config.preprod/config.cmsweb-testbed
            # export KUBECONFIG=$workPath/users_config/config.preprod/config.testbed2
            ;;
        'dev')
            export OS_PROJECT_NAME="CMS Webtools Mig"
            export KUBECONFIG=$workPath/users_config/config.test1/config.cmsweb-test1
            ;;
        'dev1'|'test1')
            export OS_PROJECT_NAME="CMS Webtools Mig"
            export KUBECONFIG=$workPath/users_config/config.test1/config.cmsweb-test1
            ;;
        'dev5'|'test5')
            export OS_PROJECT_NAME="CMS Webtools Mig"
            export KUBECONFIG=$workPath/users_config/config.test5/config.cmsweb-test5
            ;;
        'dev8'|'test8')
            export OS_PROJECT_NAME="CMS Webtools Mig"
            export KUBECONFIG=$workPath/users_config/config.test8/config.cmsweb-test8
            ;;
        'dev9'|'test9')
            export OS_PROJECT_NAME="CMS Webtools Mig"
            export KUBECONFIG=$workPath/users_config/config.test9/config.cmsweb-test9
            ;;
        'dev10'|'test10')
            export OS_PROJECT_NAME="CMS Webtools Mig"
            export KUBECONFIG=$workPath/users_config/config.test10/config.cmsweb-test10
            ;;
        'mongo-prod')
            export OS_PROJECT_NAME="CMS Webtools Mig"
            export KUBECONFIG=$workPath/users_config/config.mongo/config.mongodb-prod
            ;;
        'mongo-preprod')
            export OS_PROJECT_NAME="CMS Webtools Mig"
            export KUBECONFIG=$workPath/users_config/config.mongo/config.mongodb-preprod
            ;;
        'mongo-test')
            export OS_PROJECT_NAME="CMS Webtools Mig"
            export KUBECONFIG=$workPath/users_config/config.mongo/config.mongodb-test
            ;;
        'mongo-dev')
            export OS_PROJECT_NAME="CMS Webtools Mig"
            export KUBECONFIG=$workPath/users_config/config.mongo/config.mongodb.dev
            ;;
        'dbs-prod')
            export OS_PROJECT_NAME="CMS Webtools Mig"
            export KUBECONFIG=$workPath/users_config/config.prod/config.dbs-prod
            ;;
        'dbs-prod2')
            export OS_PROJECT_NAME="CMS Webtools Mig"
            export KUBECONFIG=$workPath/users_config/config.prod/config.dbs-prod2
            ;;
        *)
            echo "Unsupported K8 cluster instance: $1"
            echo "You may chose between: [ prod[-old] | preprod | dev[1,5,8,9,10]* | mongo-[prod, preprod, test, dev] | dbs-prod[2] ]"
            return 1
            ;;
    esac
    echo
    echo ======================= CURRENT CLUSTER: `kubectl config get-clusters |grep -v NAME` =======================
    echo
}

unpkl() {
  python3 -c 'import pickle,sys,pprint;d=pickle.load(open(sys.argv[1],"rb"));print(d);pprint.pprint(d)' "$1"
}

cernregpass(){
    openssl aes-256-cbc -d -iter 1000 -in ~/WMCoreDev.d/release/.cern.registry.enc
}

alias llh='ls -lah'
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
emacs27(){
    local emacs27_afs='~/emacs/bin/emacs-27.2'
    local emacs27_os='/usr/bin/emacs'
    if [[ $(cat /etc/redhat-release) =~ .*CentOS.*7.* ]] ; then
        $emacs27_afs -nw $*
    else
        $emacs27_os -nw $*
    fi
}
alias cmst1='sudo -u cmst1 /bin/bash --init-file ~cmst1/.bashrc'
alias cmst0='sudo -u cmst0 /bin/bash --init-file ~cmst0/.bashrc'
# alias emacs27-afs='~/emacs/bin/emacs-27.2'
# alias emacs='~/emacs/bin/emacs-27.2'
alias emacs=emacs27

alias scurl='curl -k --cert $USER_X509_PROXY --key $USER_X509_PROXY'
alias kctl='kubectl'

alias dasafs='~/WMCoreDev.d/go/bin/dasgoclient'
alias dasgoclient='/cvmfs/cms.cern.ch/common/dasgoclient'
# #export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
# #source $VO_CMS_SW_DIR/cmsset_default.sh
# #source /cvmfs/cms.cern.ch/crab3/crab.sh

# # export PATH=~/bin/pssh/usr/bin/:~/bin/screen/usr/bin/:$PATH
# export PATH=~/bin/pssh/usr/bin/:$PATH

# if [[ -z "${PYTHONPATH}" ]]; then
#   export PYTHONPATH=~/bin/pssh/usr/lib/python2.7/site-packages/
# else
#   export PYTHONPATH=${PYTHONPATH}:~/bin/pssh/usr/lib/python2.7/site-packages/
# fi



# # cd ~/work/private/cmscompops.d
# # cd ~/work/private/WMCoreDev.d
# cd ~/private/WMCoreDev.d
cd ~/WMCoreDev.d

# # ------------------------------------------------------------------------------
# # golang env setup:

# # Point to the local installation of golang.
# # export GOROOT=/opt/go

# # Point to the location beneath which source and binaries are installed.
# # export GOPATH=$HOME/go
# export GOPATH=$HOME/DBSDev.d/go

# # Ensure that the binary-release is on your PATH.
# # export PATH=${PATH}:${GOROOT}/bin

# # Ensure that compiled binaries are also on your PATH.
# export PATH=${PATH}:${GOPATH}/bin

# # Setting up Go packages  config dir:
export PKG_CONFIG_PATH=~/DBSDev.d/go/pkg.pc.d


# # ------------------------------------------------------------------------------

# # # Add pip local install path to bash
# # export PATH=${PATH}:~/.local/bin

epoch(){
    local dateVal=`date`
    local dateVal=${1:-$dateVal}
    if [[ $dateVal =~ ^[0-9]*$ ]]; then
        day=`date --date="@$dateVal" +%d`
        month=`date --date="@$dateVal" +%m`
        year=`date --date="@$dateVal" +%Y`
        cal $day $month $year
        echo -ne "Sofia: "; TZ="Europe/Sofia" date --date="@$dateVal"
        echo -ne "CERN:  "; TZ="Europe/Zurich" date --date="@$dateVal"
        echo -ne "GMT:   "; TZ="GMT" date --date="@$dateVal"
        echo -ne "UTC:   "; TZ="UTC" date --date="@$dateVal"
        echo -ne "ND:    "; TZ="America/Indiana/Indianapolis" date --date="@$dateVal"
        echo -ne "FNAL:  "; TZ="America/Chicago" date --date="@$dateVal"
    else
        day=`date --date="$dateVal" +%d`
        month=`date --date="$dateVal" +%m`
        year=`date --date="$dateVal" +%Y`
        cal $day $month $year
        echo
        echo -ne "Seconds since start of Epoch: "
        date --date="$dateVal" +%s
    fi
}


export HISTSIZE=10000000
export HISTFILESIZE=10000000
