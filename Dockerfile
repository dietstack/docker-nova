FROM osmaster

MAINTAINER Kamil Madac (kamil.madac@t-systems.sk)

ENV http_proxy="http://172.27.10.114:3128"
ENV https_proxy="http://172.27.10.114:3128"

# Source codes to download
ENV nova_repo="https://github.com/openstack/nova"
ENV nova_branch="stable/liberty"
ENV nova_commit=""

# some cleanup
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download nova source codes
RUN git clone $nova_repo --single-branch --branch $nova_branch;

# Checkout commit, if it was defined above
RUN if [ ! -z $nova_commit ]; then cd nova && git checkout $nova_commit; fi

# Apply source code patches
RUN mkdir -p /patches
COPY patches/* /patches/
RUN /patches/patch.sh

# Install nova with dependencies
RUN cd nova; apt-get update; apt-get install -y libxml2-dev libxslt1-dev; pip install -r requirements.txt; pip install supervisor mysql-python; python setup.py install

# prepare directories for supervisor
RUN mkdir -p /etc/supervisord /var/log/supervisord

# prepare necessary stuff
RUN mkdir -p /var/log/nova && \
    useradd -M -s /sbin/nologin nova

# copy nova configs
COPY configs/nova/* /etc/nova/

# copy supervisor config
COPY configs/supervisord/supervisord.conf /etc

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
