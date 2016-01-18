#!/bin/bash
set -e

# set debug
DEBUG_OPT=false
if [[ $DEBUG ]]; then
        set -x
        DEBUG_OPT=true
fi

# define variable defaults

CPU_NUM=$(grep -c ^processor /proc/cpuinfo)

DB_HOST=${DB_HOST:-127.0.0.1}
DB_PORT=${DB_PORT:-3306}
DB_PASSWORD=${DB_PASSWORD:-veryS3cr3t}

MY_IP=${MY_IP:-127.0.0.1}
OSAPI_LISTEN_IP=${OSAPI_LISTEN_IP:-0.0.0.0}
OSAPI_LISTEN_PORT=${OSAPI_LISTEN_PORT:-5}
OSAPI_COMPUTE_WORKERS=${CPU_NUM}
METADATA_LISTEN_IP=${METADATA_LISTEN_IP:-0.0.0.0}
METADATA_LISTEN_PORT=${METADATA_LISTEN_PORT:-8775}
METADATA_WORKERS=${CPU_NUM}
ADMIN_TENANT_NAME=${ADMIN_TENANT_NAME:-service}
ADMIN_USER=${ADMIN_USER:-nova}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-veryS3cr3t}

LOG_MESSAGE="Docker start script:"
OVERRIDE=0
CONF_DIR="/etc/nova"
OVERRIDE_DIR="/nova-override"
CONF_FILES=(`find $CONF_DIR -maxdepth 1 -type f -printf "%f\n"`)


# check if external configs are provided
echo "$LOG_MESSAGE Checking if external config is provided.."
if [[ -f "$OVERRIDE_DIR/${CONF_FILES[0]}" ]]; then
        echo "$LOG_MESSAGE  ==> external config found!. Using it."
        OVERRIDE=1
        for CONF in ${CONF_FILES[*]}; do
                rm -f "$CONF_DIR/$CONF"
                ln -s "$OVERRIDE_DIR/$CONF" "$CONF_DIR/$CONF"
        done
fi

if [[ $OVERRIDE -eq 0 ]]; then
        for CONF in ${CONF_FILES[*]}; do
                echo "$LOG_MESSAGE generating $CONF file ..."

                sed -i "s/_DB_HOST_/$DB_HOST/" $CONF_DIR/$CONF
                sed -i "s/_DB_PORT_/$DB_PORT/" $CONF_DIR/$CONF
                sed -i "s/_DB_PASSWORD_/$DB_PASSWORD/" $CONF_DIR/$CONF
                sed -i "s/_MY_IP_/$MY_IP/" $CONF_DIR/$CONF
                sed -i "s/_OSAPI_LISTEN_IP_/$OSAPI_LISTEN_IP/" $CONF_DIR/$CONF
                sed -i "s/_OSAPI_LISTEN_PORT_/$OSAPI_LISTEN_PORT/" $CONF_DIR/$CONF
                sed -i "s/_OSAPI_COMPUTE_WORKERS_/$OSAPI_COMPUTE_WORKERS/" $CONF_DIR/$CONF
                sed -i "s/_METADATA_LISTEN_IP_/$METADATA_LISTEN_IP/" $CONF_DIR/$CONF
                sed -i "s/_METADATA_LISTEN_PORT_/$METADATA_LISTEN_PORT/" $CONF_DIR/$CONF
                sed -i "s/_METADATA_WORKERS_/$METADATA_WORKERS/" $CONF_DIR/$CONF
                sed -i "s/_ADMIN_TENANT_NAME_/$ADMIN_TENANT_NAME/" $CONF_DIR/$CONF
                sed -i "s/_ADMIN_USER_/$ADMIN_USER/" $CONF_DIR/$CONF
                sed -i "s/_ADMIN_PASSWORD_/$ADMIN_PASSWORD/" $CONF_DIR/$CONF
                sed -i "s/_DEBUG_OPT_/$DEBUG_OPT/" $CONF_DIR/$CONF
        done
        echo "$LOG_MESSAGE  ==> done"
fi

#[[ $DB_SYNC ]] && echo "Running db_sync ..." && nova-manage db sync

echo "$LOG_MESSAGE starting nova"
exec "$@"
