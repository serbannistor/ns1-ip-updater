#!/bin/bash

#TODO: Check whether NS1_ZONE and NS1_RECORD match domain name RegEx
#TODO: Validate input IP address with RegEx
#TODO: Better error handling in update_ns1 function

SCRIPT_NAME="$(basename $0)"

NS1_ZONE=
NS1_RECORD=
NS1_RECORD_TYPE=
NS1_API_KEY=
LAST_IP=
CURRENT_IP=
FORCE=false
CONFIG_FILE=
LOG_LEVEL="error"

function log_level_to_numeric() {
    local LOG_LEVEL_STRING="$1"
    local LOG_LEVEL_NUMERIC=0

    case "${LOG_LEVEL_STRING^^}" in
        "DEBUG") LOG_LEVEL_NUMERIC=0 ;;
        "INFO") LOG_LEVEL_NUMERIC=1 ;;
        "WARN") LOG_LEVEL_NUMERIC=2 ;;
        "ERROR") LOG_LEVEL_NUMERIC=3 ;;
        *) LOG_LEVEL_NUMERIC=0; break ;;
    esac

    return ${LOG_LEVEL_NUMERIC}
}

function log() {
    local MESSAGE_LOG_LEVEL="$1"
    local LOG_MESSAGE="$2"
    local CURRENT_MICROTIME="$(date '+%Y-%m-%d %H:%M:%S.%N')"

    log_level_to_numeric "${MESSAGE_LOG_LEVEL}"
    local MESSAGE_LOG_LEVEL_NUMERIC=$?

    if [ ${MESSAGE_LOG_LEVEL_NUMERIC} -ge ${LOG_LEVEL_NUMERIC} ]; then
        echo "${CURRENT_MICROTIME} [${MESSAGE_LOG_LEVEL}] ${LOG_MESSAGE}"
    fi
}

function log_debug() {
    log "DEBUG" "$1"
}

function log_info() {
    log "INFO" "$1"
}

function log_warn() {
    log "WARN" "$1"
}

function log_error() {
    log "ERROR" "$1"
}

function usage() {
    echo "Usage: ${SCRIPT_NAME} [OPTION [OPTION [...]]]"
    echo "Update a given NS1 (ns1.com) zone with the current WAN IP address of the host it runs on, or with a manually given IP address"
    echo ""
    echo "[OPTION] can be either one of the following:"
    echo "  -i, --ip=IP_ADDRESS         Do not attempt to determine the current WAN IP address, but use the one provided"
    echo "  -f, --force                 Force updating the NS1 zone even if the current IP address seems to match the previously updated one (cached locally)"
    echo "  -a, --api-key=API_KEY       NS1 API key to be used for authentication"
    echo "  -c, --config=CONFIG_FILE    Use a config file instead of command line arguments. Command line parameters override the ones in the config file, if present"
    echo "  -z, --zone=ZONE             NS1 zone to be updated. Must be used together with the -r or --record and -t or --record-type parameters, otherwise ignored"
    echo "  -r, --record=RECORD         NS1 record to be updated. Must be used together with the -z or --zone and -t or --record-type parameters, otherwise ignored"
    echo "  -t, --record-type=TYPE      NS1 record type to be updated. Must be used together with the -z or --zone and -r or --record parameters, otherwise ignored"
    echo "                              Record type can only be A for now"
    echo "  -l, --log-level=LEVEL       Log level to be used by the program. Can be either one of: debug, info, warn, error"
    echo "  -h, --help                  Display this help and exit gracefully" 
}

function check_ns1_zone() {
    if [ "${NS1_ZONE}" == "" ]; then
        log_error "NS1_ZONE cannot be empty"
        exit 1
    else
        log_debug "NS1_ZONE is not empty"
    fi
}

function check_ns1_record() {
    if [ "${NS1_RECORD}" == "" ]; then
        log_error "NS1_RECORD cannot be empty"
        exit 1
    else
        log_debug "NS1_RECORD is not empty"
    fi
}

function check_ns1_record_type() {
    if [ "${NS1_RECORD_TYPE}" != "A" ]; then
        log_error "NS1_RECORD_TYPE is incorrect. Currently only A DNS record types are supported"
        exit 1
    else
        log_debug "NS1_RECORD_TYPE is correct"
    fi
}

function build_url() {
    check_ns1_zone
    check_ns1_record
    check_ns1_record_type
    URL="https://api.nsone.net/v1/zones/${NS1_ZONE}/${NS1_RECORD}/${NS1_RECORD_TYPE}"
}

function get_last_ip() {
    LAST_IP_FILE="${ROOT_DIR}/.last_ip"
    log_debug "Last IP file: ${LAST_IP_FILE}"

    LAST_IP=""
    if [ -f "${LAST_IP_FILE}" ]; then
        LAST_IP="$(cat ${LAST_IP_FILE})"
        log_info "Last WAN IP address: ${LAST_IP}"
    else
        log_warn "Last WAN IP address is unknown"
    fi
}

function get_current_ip() {
    if [ "${CURRENT_IP}" != "" ]; then
        log_info "IP address has already been set. Will not attempt to fetch it automatically"
        return 0
    fi

    CURRENT_IP="$(dig +short myip.opendns.com @resolver1.opendns.com)"
    if [ $? -eq 0 ]; then
        log_info "Current WAN IP address: ${CURRENT_IP}"
    else
        log_error "Could not determine the current IP address. You could try setting it up manually"
    fi
}

function update_ns1() {
    log_debug "Updating NS1 records"
    echo "${CURRENT_IP}" > ${LAST_IP_FILE}
    curl \
        --header "X-NSONE-Key: ${NS1_API_KEY}" \
        --header "Content-Type: application/json" \
        --request POST \
        --data '{"answers":[{"answer":["'${CURRENT_IP}'"]}]}' \
        ${URL}
    if [ $? -eq 0 ]; then
        log_info "Success!"
    else
        log_error "Could not update IP address"
        exit 1
    fi
}

ARGS=`getopt -o i:fa:c:z:r:t:l:h --long ip:,force,api-key:,config:,zone:,record:,record-type:,log-level:,help -n ${SCRIPT_NAME} -- "$@"`
if [ $? != 0 ]; then
    log_error "Could not parse command line arguments. Please check and fix the errors above!"
    exit 1
fi

eval set -- "$ARGS"

while true; do
    case "$1" in
        -h | --help ) usage; exit 0 ;;
        -c | --config ) CONFIG_FILE="$2"; if [ -f "${CONFIG_FILE}" ]; then source "${CONFIG_FILE}"; fi; shift 2 ;;
        -l | --log-level ) LOG_LEVEL="$2"; log_level_to_numeric "${LOG_LEVEL}"; LOG_LEVEL_NUMERIC=$?; shift 2 ;;
        -i | --ip ) CURRENT_IP="$2"; shift 2 ;; 
        -f | --force ) FORCE=true; shift ;;
        -z | --zone ) NS1_ZONE="$2"; shift 2 ;;
        -r | --record ) NS1_RECORD="$2"; shift 2 ;;
        -t | --record-type ) NS1_RECORD_TYPE="$2"; shift 2 ;;
        -a | --api-key ) NS1_API_KEY="$2"; shift 2 ;;
        -- ) shift; break ;;
        * ) break ;;
    esac
done

log_level_to_numeric "${LOG_LEVEL}"
LOG_LEVEL_NUMERIC=$?

#log_debug "This is a debug test message"
#log_info "This is an info test message"
#log_warn "This is a warn test message"
#log_error "This is an error test message"

log_debug "NS1_ZONE=${NS1_ZONE}"
log_debug "NS1_RECORD=${NS1_RECORD}"
log_debug "NS1_RECORD_TYPE=${NS1_RECORD_TYPE}"
log_debug "NS1_API_KEY=${NS1_API_KEY}"
log_debug "LAST_IP=${LAST_IP}"
log_debug "CURRENT_IP=${CURRENT_IP}"
log_debug "FORCE=${FORCE}"
log_debug "CONFIG_FILE=${CONFIG_FILE}"
log_debug "LOG_LEVEL=${LOG_LEVEL}"

build_url
log_debug "URL: ${URL}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
log_debug "Script root directory: ${ROOT_DIR}"

get_last_ip
get_current_ip

if [ "${LAST_IP}" != "${CURRENT_IP}" ]; then
    update_ns1
else
    log_info "IP address has not changed"
    if $FORCE ; then
        log_info "Force option used. Will update the NS1 record."
        update_ns1
    else
        log_info "No update necessary"
    fi
fi
