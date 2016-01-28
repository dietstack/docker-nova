#!/bin/bash
# Integration test for glance service
# Test runs mysql,memcached,keystone and glance container and checks whether glance is running on public and admin ports

GIT_REPO=172.27.10.10
RELEASE_REPO=172.27.9.130

. lib/functions.sh

cleanup() {
    echo "Clean up ..."
    docker stop galera
    docker stop memcached
    docker stop rabbitmq
    docker stop keystone
    docker stop glance
    docker stop nova-controller

    docker rm galera
    docker rm memcached
    docker rm rabbitmq
    docker rm keystone
    docker rm glance
    docker rm nova-controller
}

cleanup

##### Download/Build containers

# pull galera docker image
get_docker_image_from_release galera http://${RELEASE_REPO}/docker-galera latest

# pull rabbitmq docker image
get_docker_image_from_release rabbitmq http://${RELEASE_REPO}/docker-rabbitmq latest

# pull osmaster docker image
get_docker_image_from_release osmaster http://${RELEASE_REPO}/docker-osmaster latest

# pull keystone image
get_docker_image_from_release keystone http://${RELEASE_REPO}/docker-keystone latest

# pull glance image
get_docker_image_from_release glance http://${RELEASE_REPO}/docker-glance latest

# pull osadmin docker image
get_docker_image_from_release osadmin http://${RELEASE_REPO}/docker-osadmin latest

##### Start Containers

echo "Starting galera container ..."
GALERA_TAG=$(docker images | grep -w galera | head -n 1 | awk '{print $2}')
docker run -d --net=host -e INITIALIZE_CLUSTER=1 -e MYSQL_ROOT_PASS=veryS3cr3t -e WSREP_USER=wsrepuser -e WSREP_PASS=wsreppass -e DEBUG= --name galera galera:$GALERA_TAG

echo "Wait till galera is running ."
wait_for_port 3306 30

echo "Starting Memcached node (tokens caching) ..."
docker run -d --net=host -e DEBUG= --name memcached memcached

echo "Starting RabbitMQ container ..."
docker run -d --net=host -e DEBUG= --name rabbitmq rabbitmq

# build nova container from local sources
./build.sh

sleep 10

# create databases
create_keystone_db
create_glance_db
create_nova_db

echo "Starting keystone container"
KEYSTONE_TAG=$(docker images | grep -w keystone | head -n 1 | awk '{print $2}')
docker run -d --net=host -e DEBUG="true" -e DB_SYNC="true" --name keystone keystone:$KEYSTONE_TAG

echo "Wait till keystone is running ."

wait_for_port 5000 30
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 5000 (Keystone) not bounded!"
    exit $ret
fi

wait_for_port 35357 30
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 35357 (Keystone Admin) not bounded!"
    exit $ret
fi

echo "Starting glance container"
GLANCE_TAG=$(docker images | grep -w glance | head -n 1 | awk '{print $2}')
docker run -d --net=host -e DEBUG="true" -e DB_SYNC="true" --name glance glance:$GLANCE_TAG

echo "Starting nova-controller container"
docker run -d --net=host --privileged \
           -e DEBUG="true" \
           -e DB_SYNC="true" \
           -e NOVA_CONTROLLER="true" \
           --name nova-controller \
           nova:latest

##### Wait till underlying services are ready #####

wait_for_port 9191 30
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 9191 (Glance Registry) not bounded!"
    exit $ret
fi

wait_for_port 9292 30
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 9292 (Glance API) not bounded!"
    exit $ret
fi

# bootstrap openstack settings and upload image to glance
docker run --net=host osadmin /bin/bash -c ". /app/adminrc; bash /app/bootstrap.sh"
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Keystone bootstrap error ${ret}!"
    exit $ret
fi

docker run --net=host osadmin /bin/bash -c ". /app/userrc; openstack image create --container-format bare --disk-format qcow2 --file /app/cirros.img --public cirros"
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Cirros image import error ${ret}!"
    exit $ret
fi

# TESTS

wait_for_port 8774 30
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 8774 (Nova-Api) not bounded!"
    exit $ret
fi

wait_for_port 8775 30
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 8775 (Metadata) not bounded!"
    exit $ret
fi

wait_for_port 6082 30
ret=$?
if [ $ret -ne 0 ]; then
    echo "Error: Port 6082 (spice html5proxy) not bounded!"
    exit $ret
fi

echo "======== Success :) ========="

if [[ "$1" != "noclean" ]]; then
    cleanup
fi
