#/bin/bash
set -e

function LOG_ERROR()
{
    local content=${1}
    echo -e "\033[31m"${content}"\033[0m"
}

function LOG_INFO()
{
    local content=${1}
    echo -e "\033[34m"${content}"\033[0m"
}

function execute_cmd()
{
    local command="${1}"
    eval ${command}
    local ret=$?
    if [ $ret -ne 0 ];then
        LOG_ERROR "execute command ${command} FAILED"
        exit 1
    else
        LOG_INFO "execute command ${command} SUCCESS"
    fi
}

yes_go_other_exit()
{
    read -r -p "[Y/n]: " input
    case $input in
        [yY][eE][sS]|[yY])
            ;;

        [nN][oO]|[nN])
            exit 1
                ;;

        *)
        exit 1
        ;;
    esac    
}

output_dir=
name=
listenip=127.0.0.1
rpcport=
p2pport=
channelPort=
peers=

this_script=$0
help() {
    LOG_ERROR "${1}"
    LOG_INFO "Usage:"
    LOG_INFO "    -o  <output dir>        Where node files generate "
    LOG_INFO "    -n  <node name>         Name of node"
    LOG_INFO "    -l  <listen ip>         Node's listen IP"
    LOG_INFO "    -r  <RPC port>          Node's RPC port"
    LOG_INFO "    -p  <P2P port>          Node's P2P port"
    LOG_INFO "    -c  <channel port>      Node's channel port"
    LOG_INFO "    -a  <agency name>       The agency name that the node belongs to"
    LOG_INFO "    -d  <agency dir>        The agency cert dir that the node belongs to"
    LOG_INFO "    -r  <GM shell path>     The path of GM shell scripts directory"
    LOG_INFO "    -s  <sdk name>          The sdk name to connect with the node "
    LOG_INFO "    -g 			          Generate guomi cert"
    LOG_INFO "    -m                      Input agency information manually"
    LOG_INFO "    -h                      This help"
    LOG_INFO "Example:"
    LOG_INFO "    bash $this_script -o /mydata -n node0 -l 127.0.0.1 -r 8545 -p 30303 -c 8891 -e 127.0.0.1:30303,127.0.0.1:30304"

exit -1
}

while getopts "o:n:l:r:p:c:e:h" option;do
	case $option in
	o) output_dir=$OPTARG;;
    n) name=$OPTARG;;
    l) listenip=$OPTARG;;
    r) rpcport=$OPTARG;;
    p) p2pport=$OPTARG;;
    c) channelPort=$OPTARG;;
	h) help;;
	esac
done

[ -z $output_dir ] && help 'Error! Please specify <output dir> using -o'
[ -z $name ] && help 'Error! Please specify <node name> using -z'
[ -z $listenip ] && help 'Error! Please specify <listen ip> using -l'
[ -z $rpcport ] && help 'Error! Please specify <RPC port> using -r'
[ -z $p2pport ] && help 'Error! Please specify <P2P port> using -p'
[ -z $channelPort ] && help 'Error! Please specify <channel port> using -c'





node_dir=$output_dir/$name/
peers=$listenip:$p2pport

generate_nodedir() {
    out=$1
    mkdir -p $out
    mkdir -p $out/data/
    mkdir -p $out/log/
    mkdir -p $out/keystore/

    LOG_INFO "`readlink -f $out/data ` is generated"
    LOG_INFO "`readlink -f $out/log` is generated"
    LOG_INFO "`readlink -f $out/keystore` is generated"
}

generate_node_script() {
    out=$1
    cp start.sh stop.sh $out
    chmod +x $out/start.sh
    chmod +x $out/stop.sh

    LOG_INFO "`readlink -f $out/start.sh` is generated"
    LOG_INFO "`readlink -f $out/stop.sh` is generated"
}

generate_confg() {
    out=$1
    mkdir -p $out
    out_file=$out/config.json
    echo '{
        "sealEngine": "PBFT",
        "systemproxyaddress":"0x0",
        "listenip":"'$listenip'",
        "cryptomod":"0",
        "rpcport": "'$rpcport'",
        "p2pport": "'$p2pport'",
        "channelPort": "'$channelPort'",
        "wallet":"./data/keys.info",
        "keystoredir":"./data/keystore/",
        "datadir":"./data/",
        "vm":"interpreter",
        "networkid":"12345",
        "logverbosity":"4",
        "coverlog":"OFF",
        "eventlog":"ON",
        "statlog":"OFF",
        "logconf":"./log.conf"
}' > $out_file
    LOG_INFO "`readlink -f $out_file` is generated"
}

generate_logconf() {
    out=$1
    mkdir -p $out
    out_file=$out/log.conf    
    echo '* GLOBAL:  
    ENABLED                 =   true  
    TO_FILE                 =   true  
    TO_STANDARD_OUTPUT      =   false  
    FORMAT                  =   "%level|%datetime{%Y-%M-%d %H:%m:%s:%g}|%msg"   
    FILENAME                =   "./log/log_%datetime{%Y%M%d%H}.log"  
    MILLISECONDS_WIDTH      =   3  
    PERFORMANCE_TRACKING    =   false  
    MAX_LOG_FILE_SIZE       =   209715200 ## 200MB - Comment starts with two hashes (##)
    LOG_FLUSH_THRESHOLD     =   100  ## Flush after every 100 logs
      
* TRACE:  
    ENABLED                 =   true
    FILENAME                =   "./log/trace_log_%datetime{%Y%M%d%H}.log"  
      
* DEBUG:  
    ENABLED                 =   true
    FILENAME                =   "./log/debug_log_%datetime{%Y%M%d%H}.log"  

* FATAL:  
    ENABLED                 =   true  
    FILENAME                =   "./log/fatal_log_%datetime{%Y%M%d%H}.log"
      
* ERROR:  
    ENABLED                 =   true
    FILENAME                =   "./log/error_log_%datetime{%Y%M%d%H}.log"  
      
* WARNING: 
     ENABLED                 =   true
     FILENAME                =   "./log/warn_log_%datetime{%Y%M%d%H}.log"
 
* INFO: 
    ENABLED                 =   true
    FILENAME                =   "./log/info_log_%datetime{%Y%M%d%H}.log"  
      
* VERBOSE:  
    ENABLED                 =   true
    FILENAME                =   "./log/verbose_log_%datetime{%Y%M%d%H}.log"
' > $out_file
    LOG_INFO "`readlink -f $out_file` is generated"
}

generate_bootstrapnodes() {
    out=$1/data
    mkdir -p $out 
    out_file=$out/bootstrapnodes.json
    rm -f $out_file 

    not_first=
    bootstrapnodes={\"nodes\":[
    #foreach peers
    IFS=',' read -ra PEERS <<< "$peers"
    for PEER in "${PEERS[@]}"; do
        IFS=':' read -ra URL <<< "$PEER"
        ip=${URL[0]}
        port=${URL[1]}
        if [ -z $not_first ]; then
            bootstrapnodes=$bootstrapnodes\{\"host\":\"$ip\",\"p2pport\":\"$port\"\}
            not_first="yes"
        else
            bootstrapnodes=$bootstrapnodes\,\{\"host\":\"$ip\",\"p2pport\":\"$port\"\}
        fi
    done
    bootstrapnodes=$bootstrapnodes\]\}
    echo $bootstrapnodes > $out_file
    LOG_INFO "`readlink -f $out_file` is generated"
}

if [ -d "$node_dir" ]; then
    echo "Attention! Duplicate generation of \"$node_dir\". Overwrite?"
    yes_go_other_exit
fi

generate_nodedir $node_dir
generate_node_script $node_dir
generate_confg $node_dir
generate_logconf $node_dir
generate_bootstrapnodes $node_dir

LOG_INFO "Generate success!"
