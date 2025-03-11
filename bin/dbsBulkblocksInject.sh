#!/bin/bash

usage(){
    echo -e $*
    cat <<EOF
    Usage: dbsBulkblocksInject.sh [-s] [-f] [-a] [-h]

      -s         DBS server                  Default: https://cmsweb-testbed.cern.ch
      -f         Json file with data content Default: None
      -a         API                         Default: global/DBSWriter/bulkblocks"
      -h <help>  Provides help to the current script

EOF
}


#Set defaults
# default dbsWriter for global DBSWriter API server url https://cmsweb-testbed.cern.ch/dbs/int/global/DBSWriter
dbsServerDefault=https://cmsweb-testbed.cern.ch/dbs/int
apiDefault="global/DBSWriter/bulkblocks"
fileDefault="None"

curlArgs=""
export OPTIND=0
while getopts ":a:s:f:h" opt; do
    case ${opt} in
        a)
            api=$OPTARG;;
        s)
            dbsServer=$OPTARG
            [[ $dbsServer =~ .*cmsweb\-testbed\.cern\.ch.* ]] && \
                dbsServer=$dbsServer/dbs/int || dbsServer=$dbsServer/dbs/prod
            ;;
        f)
            file=$OPTARG
            file=$(realpath -m $file) ;;
        h)
            usage
            exit 0 ;;
        \? )
            curlArgs="$curlArgs -$OPTARG"
            echo "\nINFO: Adding extra curl arg: $curlArgs" ;;
        : )
            msg="\nERROR: Invalid Option: -$OPTARG requires an argument\n"
            usage "$msg" ;;
    esac
done

[[ -n $api ]]       || api=$apiDefault
[[ -n $file ]]      || file=$fileDefault
[[ -n $dbsServer ]] || dbsServer=$dbsServerDefault

url=$dbsServer/$api

scurl () {
    # curl -k --cert /data/certs/servicecert.pem --key /data/certs/servicekey.pem $@
    curl -k --cert $X509_USER_CERT --key $X509_USER_KEY $$
}


# execute:
echo  Executing: curl -k --cert $X509_USER_CERT --key $X509_USER_KEY -H \"Content-Type: application/json\" --data "@$file" $curlArgs $url
echo ===========================================================================
echo
echo

curl -k --cert $X509_USER_CERT --key $X509_USER_KEY -H "Content-Type: application/json" --data "@$file" $curlArgs $url | json_reformat
