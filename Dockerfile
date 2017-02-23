FROM osmaster

MAINTAINER Kamil Madac (kamil.madac@t-systems.sk)

ENV http_proxy="http://172.27.10.114:3128"
ENV https_proxy="http://172.27.10.114:3128"
ENV no_proxy="locahost,127.0.0.1"

# Source codes to download
ENV nova_repo="https://github.com/openstack/nova"
ENV nova_branch="stable/newton"
ENV nova_commit=""

# some cleanup
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download nova source codes
RUN git clone $nova_repo --single-branch --depth=1 --branch $nova_branch;

# Checkout commit, if it was defined above
RUN if [ ! -z $nova_commit ]; then cd nova && git checkout $nova_commit; fi

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
    qemu-utils; \
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

# Define workdir
WORKDIR /app
RUN chmod +x /app/*

ENTRYPOINT ["/app/entrypoint.sh"]

# Define default command.
CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisord.conf"]
