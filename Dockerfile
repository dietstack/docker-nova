FROM debian:stretch-slim
MAINTAINER Kamil Madac (kamil.madac@gmail.com)

# Apply source code patches
RUN mkdir -p /patches
COPY patches/* /patches/

RUN echo 'APT::Install-Recommends "false";' >> /etc/apt/apt.conf && \
    echo 'APT::Get::Install-Suggests "false";' >> /etc/apt/apt.conf && \
    apt update; apt install -y ca-certificates wget python libpython2.7 libxml2-dev iptables \
      dnsmasq bridge-utils python-libvirt openvswitch-switch ebtables spice-html5 qemu-utils \
      sudo nginx iproute2 nfs-common netbase && \
    update-ca-certificates; \
    wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py; \
    python get-pip.py; \
    rm get-pip.py; \
    wget https://raw.githubusercontent.com/openstack/requirements/stable/pike/upper-constraints.txt -P /app && \
    /patches/stretch-crypto.sh && \
    apt-get clean && apt autoremove && \
    rm -rf /var/lib/apt/lists/*; rm -rf /root/.cache

# Source codes to download
ENV SVC_NAME=nova
ENV REPO="https://github.com/openstack/$SVC_NAME" BRANCH="stable/pike"
#COMMIT="d8b30c377"

# Install nova with dependencies
ENV BUILD_PACKAGES="git build-essential libssl-dev libffi-dev python-dev"

RUN apt update; apt install -y $BUILD_PACKAGES && \
    if [ -z $REPO ]; then \
      echo "Sources fetching from releases $RELEASE_URL"; \
      wget $RELEASE_URL && tar xvfz $SVC_VERSION.tar.gz -C / && mv $(ls -1d $SVC_NAME*) $SVC_NAME && \
      cd /$SVC_NAME && pip install -r requirements.txt -c /app/upper-constraints.txt && PBR_VERSION=$SVC_VERSION python setup.py install; \
    else \
      if [ -n $COMMIT ]; then \
        cd /; git clone $REPO --single-branch --branch $BRANCH; \
        cd /$SVC_NAME && git checkout $COMMIT; \
      else \
        git clone $REPO --single-branch --depth=1 --branch $BRANCH; \
      fi; \
      cd /$SVC_NAME; pip install -r requirements.txt -c /app/upper-constraints.txt && python setup.py install && \
      rm -rf /$SVC_NAME/.git; \
    fi; \
    pip install uwsgi supervisor PyMySQL python-memcached && \
    apt remove -y --auto-remove $BUILD_PACKAGES &&  \
    apt-get clean && apt autoremove && \
    rm -rf /var/lib/apt/lists/* && rm -rf /root/.cache

# prepare directories for supervisor
RUN mkdir -p /etc/supervisor.d /var/log/supervisord

# prepare necessary stuff
RUN rm /etc/nginx/sites-enabled/default; \
    mkdir -p /var/log/nginx/nova-placement-api && \
    useradd -M -s /sbin/nologin nova && \
    usermod -G www-data nova && \
    mkdir -p /run/uwsgi/ && chown nova:nova /run/uwsgi && chmod 775 /run/uwsgi

# copy nova configs
COPY configs/nova/* /etc/nova/
COPY configs/nova/rootwrap.d /etc/nova/rootwrap.d

# copy supervisor configs
COPY configs/supervisord/supervisord.conf /etc
COPY configs/supervisord/supervisor.d/* /etc/supervisor.d/

# copy uwsgi ini files
RUN mkdir -p /etc/uwsgi
COPY configs/uwsgi/nova-placement-api.ini /etc/uwsgi/nova-placement-api.ini

# prepare nginx configs
RUN sed -i '1idaemon off;' /etc/nginx/nginx.conf
COPY configs/nginx/nova-placement-api.conf /etc/nginx/sites-enabled/nova-placement-api.conf

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
