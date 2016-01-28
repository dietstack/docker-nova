## Nova docker

### Using

```
git clone git@172.27.10.10:openstack/docker-nova.git
cd docker-nova
./build.sh
```
Result will be nova image in a local image registry.

### Services
This image can be run in two roles. Either as controller or as compute. This two roles differs in a services which are exectuted by supervisor.

### Controller role
Following services are exectuted when variable `NOVA_CONTROLLER` is set to `true` (default):

  * nova-api
  * nova-cert
  * nova-conductor
  * nova-consoleauth
  * nova-scheduler
  * nova-spicehtml5proxy

### Compute role
When `NOVA_CONTROLLER` set to `false` only one service is executed:

  * nova-compute

### Communication with Libvirt

Nova communicates with hypervisors via libvirt library either over socket or over tcp connection on port 16509. Uri is currently hard-coded in `nova.conf`:
```
connection_uri = qemu+tcp://127.0.0.1:16509/system
```

We need to configure libvirt on host system as follow:

edit /etc/libvirt/libvirtd.conf:

```
auth_unix_ro = "none"
listen_tls = 0
listen_tcp = 1
```

add LIBVIRTD_ARGS="-l" in /lib/systemd/system/libvirt-bin.service

restart libvirt:

```
systemctl restart libvirt-bin.service
```

