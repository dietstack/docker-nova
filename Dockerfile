FROM osmaster
MAINTAINER Kamil Madac (kamil.madac@t-systems.sk)

# Source codes to download
ENV srv_name=nova
ENV repo="https://github.com/openstack/$srv_name" branch="stable/newton" commit="d8b30c377"

# Download source codes
RUN if [ -n $commit ]; then \
       git clone $repo --single-branch --branch $branch; \
       cd $srv_name && git checkout $commit; \
    else \
       git clone $repo --single-branch --depth=1 --branch $branch; \
    fi

# Apply source code patches
RUN mkdir -p /patches
COPY patches/* /patches/
RUN /patches/patch.sh

# Install nova with dependencies
RUN cd nova; apt-get update; \
    apt-get install -y --no-install-recommends \
    libxml2-dev \
    libxslt1-dev \
    iptables \
    dnsmasq \
    bridge-utils \
    python-libvirt \
    openvswitch-switch \
    ebtables \
    spice-html5 \
    qemu-utils \
    sudo; \
    pip install -r requirements.txt -c /requirements/upper-constraints.txt; \
    pip install supervisor python-memcached; \
    python setup.py install

# prepare directories for supervisor
RUN mkdir -p /etc/supervisor.d /var/log/supervisord

# prepare necessary stuff
RUN useradd -M -s /sbin/nologin nova

# copy nova configs
COPY configs/nova/* /etc/nova/
COPY configs/nova/rootwrap.d /etc/nova/rootwrap.d

# copy supervisor configs
COPY configs/supervisord/supervisord.conf /etc
COPY configs/supervisord/supervisor.d/* /etc/supervisor.d/

# external volume
VOLUME /nova-override

# copy startup scripts
COPY scripts /app

# some cleanup
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Define workdir
WORKDIR /app
RUN chmod +x /app/*

ENTRYPOINT ["/app/entrypoint.sh"]

# Define default command.
CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisord.conf"]
