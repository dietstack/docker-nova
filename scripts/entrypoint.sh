#!/bin/bash
set -e

exit 0

# set debug
DEBUG_OPT=false
if [[ $DEBUG ]]; then
        set -x
        DEBUG_OPT=true
fi

# if glance is not installed, quit
which glance-control &>/dev/null || exit 1

# define variable defaults

DB_HOST=${DB_HOST:-127.0.0.1}
DB_PORT=${DB_PORT:-3306}
DB_PASSWORD=${DB_PASSWORD:-veryS3cr3t}

BIND_HOST=${BIND_HOST:-0.0.0.0}
GLANCE_API_PORT=${GLANCE_API_PORT:-9292}
NUM_OF_API_WORKERS=${NUM_OF_API_WORKERS:-5}
PUBLISHER_ID=${PUBLISHER_ID:-None}
GLANCE_REGISTRY_PORT=${GLANCE_REGISTRY_PORT:-9191}
GLANCE_DATA_DIR=${GLANCE_DATA_DIR:-"\/var\/lib\/glance\/images"}
NUM_OF_REGISTRY_WORKERS=${NUM_OF_REGISTRY_WORKERS:-5}
ADMIN_TENANT_NAME=${ADMIN_TENANT_NAME:-service}
ADMIN_USER=${ADMIN_USER:-nova}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-veryS3cr3t}

LOG_MESSAGE="Docker start script:"
OVERRIDE=0
CONF_DIR="/etc/glance"
OVERRIDE_DIR="/glance-override"
#CONF_FILES=("glance-api.conf" "glance-registry.conf")
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
                sed -i "s/_BIND_HOST_/$BIND_HOST/" $CONF_DIR/$CONF
                sed -i "s/_GLANCE_API_PORT_/$GLANCE_API_PORT/" $CONF_DIR/$CONF
                sed -i "s/_NUM_OF_API_WORKERS_/$NUM_OF_API_WORKERS/" $CONF_DIR/$CONF
                sed -i "s/_NUM_OF_REGISTRY_WORKERS_/$NUM_OF_REGISTRY_WORKERS/" $CONF_DIR/$CONF
                sed -i "s/_PUBLISHER_ID_/$PUBLISHER_ID/" $CONF_DIR/$CONF
                sed -i "s/_GLANCE_REGISTRY_PORT_/$GLANCE_REGISTRY_PORT/" $CONF_DIR/$CONF
                sed -i "s/_GLANCE_DATA_DIR_/$GLANCE_DATA_DIR/" $CONF_DIR/$CONF
                sed -i "s/_ADMIN_TENANT_NAME_/$ADMIN_TENANT_NAME/" $CONF_DIR/$CONF
                sed -i "s/_ADMIN_USER_/$ADMIN_USER/" $CONF_DIR/$CONF
                sed -i "s/_ADMIN_PASSWORD_/$ADMIN_PASSWORD/" $CONF_DIR/$CONF
                sed -i "s/_DEBUG_OPT_/$DEBUG_OPT/" $CONF_DIR/$CONF
        done
        echo "$LOG_MESSAGE  ==> done"
fi

[[ $DB_SYNC ]] && echo "Running db_sync ..." && glance-manage db sync

echo "$LOG_MESSAGE starting glance"
exec "$@"
