#!/bin/bash
set -e

# set debug
DEBUG_OPT=false
if [[ $DEBUG ]]; then
        set -x
        DEBUG_OPT=true
fi

# same image can be used in controller and compute node as well
# if true, CONTROL_SRVCS will be activated, if false, COMUPTE_SRVCS will be activated
NOVA_CONTROLLER=${NOVA_CONTROLLER:-true}

# define variable defaults

CPU_NUM=$(grep -c ^processor /proc/cpuinfo)

DB_HOST=${DB_HOST:-127.0.0.1}
DB_PORT=${DB_PORT:-3306}
DB_PASSWORD=${DB_PASSWORD:-veryS3cr3t}
RABBITMQ_HOST=${RABBITMQ_HOST:-127.0.0.1}
RABBITMQ_PORT=${RABBITMQ_PORT:-5672}
RABBITMQ_USER=${RABBITMQ_USER:-openstack}
RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD:-veryS3cr3t}

MY_IP=${MY_IP:-127.0.0.1}
# SPICE_HOST should be contro node public ip
SPICE_HOST=${SPICE_HOST:-127.0.0.1}
# SPICE_PROXY_HOST is management IP of compute node
SPICE_PROXY_HOST=${SPICE_PROXY_HOST:-127.0.0.1}

OSAPI_LISTEN_IP=${OSAPI_LISTEN_IP:-0.0.0.0}
OSAPI_LISTEN_PORT=${OSAPI_LISTEN_PORT:-8774}
OSAPI_COMPUTE_WORKERS=${CPU_NUM}
METADATA_LISTEN_IP=${METADATA_LISTEN_IP:-0.0.0.0}
METADATA_LISTEN_PORT=${METADATA_LISTEN_PORT:-8775}
METADATA_WORKERS=${CPU_NUM}
GLANCE_HOST=${GLANCE_HOST:-127.0.0.1}
NEUTRON_HOST=${NEUTRON_HOST:-127.0.0.1}
KEYSTONE_HOST=${KEYSTONE_HOST:-127.0.0.1}
MEMCACHED_SERVERS=${MEMCACHED_SERVERS:-127.0.0.1:11211}
SERVICE_TENANT_NAME=${SERVICE_TENANT_NAME:-service}
SERVICE_USER=${SERVICE_USER:-nova}
SERVICE_PASSWORD=${SERVICE_PASSWORD:-veryS3cr3t}
PLACEMENT_SERVICE_USER=${PLACEMENT_SERVICE_USER:-placement}
PLACEMENT_SERVICE_PASSWORD=${PLACEMENT_SERVICE_PASSWORD:-veryS3cr3t}
NEUTRON_SERVICE_PASSWORD=${NEUTRON_SERVICE_PASSWORD:-veryS3cr3t}
NEUTRON_SERVICE_USER=${NEUTRON_SERVICE_USER:-neutron}
NEUTRON_METADATA_SECRET=${NEUTRON_METADATA_SECRET:-veryS3cr3tmetadata}

LOG_MESSAGE="Docker start script:"
OVERRIDE=0
CONF_DIR="/etc/nova"
SUPERVISOR_CONF_DIR="/etc/supervisor.d"
OVERRIDE_DIR="/nova-override"
CONF_FILES=(`find $CONF_DIR -maxdepth 1 -type f -printf "%f\n"`)
OVERRIDE_CONF_FILES=(`find $OVERRIDE_DIR -maxdepth 1 -type f -printf "%f\n"`)
CONTROL_SRVCS="nginx uwsgi nova-api nova-cert nova-conductor nova-consoleauth nova-scheduler nova-spicehtml5proxy nova-placement-api"
COMPUTE_SRVCS="nova-compute"
INSECURE=${INSECURE:-true}

VIRT_TYPE=${VIRT_TYPE:-kvm}

# set qemu virtualization type if necessary
if [[ `egrep -c '(vmx|svm)' /proc/cpuinfo` == 0 && $VIRT_TYPE == "kvm" ]]; then
    VIRT_TYPE=qemu
fi


# check if external configs are provided
echo "$LOG_MESSAGE Checking if external config is provided.."
if [[ "$(ls -A $OVERRIDE_DIR)" ]]; then
        echo "$LOG_MESSAGE  ==> external config found!. Using it."
        OVERRIDE=1
        for CONF in ${OVERRIDE_CONF_FILES[*]}; do
                rm -f "$CONF_DIR/$CONF"
                ln -s "$OVERRIDE_DIR/$CONF" "$CONF_DIR/$CONF"
        done
fi

if [[ $OVERRIDE -eq 0 ]]; then
        for CONF in ${CONF_FILES[*]}; do
                echo "$LOG_MESSAGE generating $CONF file ..."

                sed -i "s/\b_DB_HOST_\b/$DB_HOST/" $CONF_DIR/$CONF
                sed -i "s/\b_DB_PORT_\b/$DB_PORT/" $CONF_DIR/$CONF
                sed -i "s/\b_DB_PASSWORD_\b/$DB_PASSWORD/" $CONF_DIR/$CONF
                sed -i "s/\b_RABBITMQ_HOST_\b/$RABBITMQ_HOST/" $CONF_DIR/$CONF
                sed -i "s/\b_RABBITMQ_PORT_\b/$RABBITMQ_PORT/" $CONF_DIR/$CONF
                sed -i "s/\b_RABBITMQ_USER_\b/$RABBITMQ_USER/" $CONF_DIR/$CONF
                sed -i "s/\b_RABBITMQ_PASSWORD_\b/$RABBITMQ_PASSWORD/" $CONF_DIR/$CONF
                sed -i "s/\b_MY_IP_\b/$MY_IP/" $CONF_DIR/$CONF
                sed -i "s/\b_OSAPI_LISTEN_IP_\b/$OSAPI_LISTEN_IP/" $CONF_DIR/$CONF
                sed -i "s/\b_OSAPI_LISTEN_PORT_\b/$OSAPI_LISTEN_PORT/" $CONF_DIR/$CONF
                sed -i "s/\b_OSAPI_COMPUTE_WORKERS_\b/$OSAPI_COMPUTE_WORKERS/" $CONF_DIR/$CONF
                sed -i "s/\b_METADATA_LISTEN_IP_\b/$METADATA_LISTEN_IP/" $CONF_DIR/$CONF
                sed -i "s/\b_METADATA_LISTEN_PORT_\b/$METADATA_LISTEN_PORT/" $CONF_DIR/$CONF
                sed -i "s/\b_METADATA_WORKERS_\b/$METADATA_WORKERS/" $CONF_DIR/$CONF
                sed -i "s/\b_SERVICE_TENANT_NAME_\b/$SERVICE_TENANT_NAME/" $CONF_DIR/$CONF
                sed -i "s/\b_SERVICE_USER_\b/$SERVICE_USER/" $CONF_DIR/$CONF
                sed -i "s/\b_SERVICE_PASSWORD_\b/$SERVICE_PASSWORD/" $CONF_DIR/$CONF
                sed -i "s/\b_PLACEMENT_SERVICE_USER_\b/$PLACEMENT_SERVICE_USER/" $CONF_DIR/$CONF
                sed -i "s/\b_PLACEMENT_SERVICE_PASSWORD_\b/$PLACEMENT_SERVICE_PASSWORD/" $CONF_DIR/$CONF
                sed -i "s/\b_DEBUG_OPT_\b/$DEBUG_OPT/" $CONF_DIR/$CONF
                sed -i "s/\b_NEUTRON_SERVICE_PASSWORD_\b/$NEUTRON_SERVICE_PASSWORD/" $CONF_DIR/$CONF
                sed -i "s/\b_NEUTRON_SERVICE_USER_\b/$NEUTRON_SERVICE_USER/" $CONF_DIR/$CONF
                sed -i "s/\b_NEUTRON_METADATA_SECRET_\b/$NEUTRON_METADATA_SECRET/" $CONF_DIR/$CONF
                sed -i "s/\b_GLANCE_HOST_\b/$GLANCE_HOST/" $CONF_DIR/$CONF
                sed -i "s/\b_NEUTRON_HOST_\b/$NEUTRON_HOST/" $CONF_DIR/$CONF
                sed -i "s/\b_KEYSTONE_HOST_\b/$KEYSTONE_HOST/" $CONF_DIR/$CONF
                sed -i "s/\b_MEMCACHED_SERVERS_\b/$MEMCACHED_SERVERS/" $CONF_DIR/$CONF
                sed -i "s/\b_VIRT_TYPE_\b/$VIRT_TYPE/" $CONF_DIR/$CONF
                sed -i "s/\b_INSECURE_\b/$INSECURE/" $CONF_DIR/$CONF
                sed -i "s/\b_SPICE_HOST_\b/$SPICE_HOST/" $CONF_DIR/$CONF
                sed -i "s/\b_SPICE_PROXY_HOST_\b/$SPICE_PROXY_HOST/" $CONF_DIR/$CONF
        done
        echo "$LOG_MESSAGE  ==> done"
fi


if [[ $NOVA_CONTROLLER == "true" ]]; then
        for SRVC in $COMPUTE_SRVCS; do
            if [[ -f ${SUPERVISOR_CONF_DIR}/${SRVC}.ini ]]; then
                mv ${SUPERVISOR_CONF_DIR}/${SRVC}.ini ${SUPERVISOR_CONF_DIR}/${SRVC}.disabled
            fi
        done
else
        for SRVC in $CONTROL_SRVCS; do
            if [[ -f ${SUPERVISOR_CONF_DIR}/${SRVC}.ini ]]; then
                mv ${SUPERVISOR_CONF_DIR}/${SRVC}.ini ${SUPERVISOR_CONF_DIR}/${SRVC}.disabled
            fi
        done
fi

mkdir -p /var/log/nova /var/lib/nova /var/lib/nova/lock /var/lib/nova/instances

#[[ $DB_SYNC ]] && echo "Running db_sync ..." && nova-manage api_db sync && nova-manage db sync

# cell_v2 setup for ocata
[[ $DB_SYNC ]] && echo "Setting up cells" && nova-manage api_db sync && nova-manage cell_v2 map_cell0 && nova-manage cell_v2 create_cell --name cell1 && nova-manage db sync

echo "$LOG_MESSAGE starting nova"
exec "$@"
