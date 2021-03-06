#!/bin/bash
# Integration test for glance service
# Test runs mysql,memcached,keystone and glance container and checks whether glance is running on public and admin ports

DOCKER_PROJ_NAME=${DOCKER_PROJ_NAME:-''}
CONT_PREFIX=test

. lib/functions.sh

http_proxy_args="-e http_proxy=${http_proxy:-} -e https_proxy=${https_proxy:-} -e no_proxy=${no_proxy:-}"

cleanup() {
    echo "Clean up ..."
    docker stop ${CONT_PREFIX}_mariadb
    docker stop ${CONT_PREFIX}_memcached
    docker stop ${CONT_PREFIX}_rabbitmq
    docker stop ${CONT_PREFIX}_keystone
    docker stop ${CONT_PREFIX}_nova-controller
    docker stop ${CONT_PREFIX}_nova-compute

    docker rm ${CONT_PREFIX}_mariadb
    docker rm ${CONT_PREFIX}_memcached
    docker rm ${CONT_PREFIX}_rabbitmq
    docker rm ${CONT_PREFIX}_keystone
    docker rm ${CONT_PREFIX}_nova-controller
    docker rm ${CONT_PREFIX}_nova-compute
}

cleanup

##### Start Containers

echo "Starting mariadb container ..."
docker run  --net=host -d -e MYSQL_ROOT_PASSWORD=veryS3cr3t --name ${CONT_PREFIX}_mariadb \
       mariadb:10.1

echo "Wait till mariadb is running ."
wait_for_port 3306 30

echo "Starting Memcached node (tokens caching) ..."
docker run -d --net=host -e DEBUG= --name ${CONT_PREFIX}_memcached memcached

echo "Wait till Memcached is running ."
wait_for_port 11211 30

echo "Starting RabbitMQ container ..."
docker run -d --net=host -e DEBUG= --name ${CONT_PREFIX}_rabbitmq rabbitmq

wait_for_port 5672 120

# create openstack user in rabbitmq
if [[ ! `docker exec ${CONT_PREFIX}_rabbitmq rabbitmqctl list_users | grep openstack` ]]; then
    docker exec ${CONT_PREFIX}_rabbitmq rabbitmqctl add_user openstack veryS3cr3t
    docker exec ${CONT_PREFIX}_rabbitmq rabbitmqctl set_permissions openstack '.*' '.*' '.*'
fi

# build nova container from local sources
./build.sh

# create databases
create_db_osadmin keystone keystone veryS3cr3t veryS3cr3t
create_db_osadmin nova nova veryS3cr3t veryS3cr3t
create_db_osadmin nova_cell0 nova veryS3cr3t veryS3cr3t
create_db_osadmin nova_api nova veryS3cr3t veryS3cr3t

echo "Starting keystone container"
docker run -d --net=host \
           -e DEBUG="true" \
           -e DB_SYNC="true" \
           $http_proxy_args \
           --name ${CONT_PREFIX}_keystone ${DOCKER_PROJ_NAME}keystone:latest

echo "Wait till keystone is running ."

wait_for_port 5000 360
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 5000 (Keystone) not bounded!"
    exit $ret
fi

wait_for_port 35357 360
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 35357 (Keystone Admin) not bounded!"
    exit $ret
fi
 
# bootstrap openstack settings
set +e

echo "Bootstrapping keystone"                                                                       
docker run --rm --net=host -e DEBUG="true" --name bootstrap_keystone \
           ${DOCKER_PROJ_NAME}keystone:latest \
           bash -c "keystone-manage bootstrap --bootstrap-password veryS3cr3t \
                   --bootstrap-username admin \
                   --bootstrap-project-name admin \
                   --bootstrap-role-name admin \
                   --bootstrap-service-name keystone \
                   --bootstrap-region-id RegionOne \
                   --bootstrap-admin-url http://127.0.0.1:35357 \
                   --bootstrap-public-url http://127.0.0.1:5000 \
                   --bootstrap-internal-url http://127.0.0.1:5000 "

ret=$?                                                                                              
if [ $ret -ne 0 ]; then                                                                             
    echo "Bootstrapping error!"                                                                     
    exit $ret                                                                                       
fi

docker run --net=host --rm $http_proxy_args ${DOCKER_PROJ_NAME}osadmin:latest \
           /bin/bash -c ". /app/adminrc; bash -x /app/bootstrap.sh"
ret=$?
if [ $ret -ne 0 ] && [ $ret -ne 128 ]; then
    echo "Error: Keystone bootstrap error ${ret}!"
    exit $ret
fi
set -e

echo "Starting nova-controller container"
docker run -d --net=host --privileged \
           -e DEBUG="true" \
           -e DB_SYNC="true" \
           -e SETUP_CELL="true" \
           -e NOVA_CONTROLLER="true" \
           $http_proxy_args \
           --name ${CONT_PREFIX}_nova-controller \
           ${DOCKER_PROJ_NAME}nova:latest


echo "Starting nova-compute container"
docker run -d --net=host  --privileged \
           -e DEBUG="true" \
           -e NOVA_CONTROLLER="false" \
           -v /sys/fs/cgroup:/sys/fs/cgroup \
           -v /var/lib/nova:/var/lib/nova \
           -v /var/lib/libvirt:/var/lib/libvirt \
           -v /run:/run \
           $http_proxy_args \
           --name ${CONT_PREFIX}_nova-compute \
           ${DOCKER_PROJ_NAME}nova:latest

# TESTS

wait_for_port 8774 360
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 8774 (Nova-Api) not bounded!"
    exit $ret
fi

wait_for_port 8775 360
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 8775 (Metadata) not bounded!"
    exit $ret
fi

wait_for_port 6082 360
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 6082 (spice html5proxy) not bounded!"
    exit $ret
fi

echo "======== Success :) ========="

if [[ "$1" != "noclean" ]]; then
    cleanup
fi
