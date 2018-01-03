FROM openshift/jenkins-slave-base-centos7

# Set home to root directory for caching purposes
# Set kerberos cache location env variable
# Disable host key checking explicitly - see https://github.com/ansible/ansible/issues/30720
ENV HOME=/root \
    ANSIBLE_HOST_KEY_CHECKING=False \
    KRB5CCNAME=FILE:/tmp/krb5cc_1000060000

# Copy over configuration files
COPY beaker/client.conf /etc/beaker/client.conf
COPY krb5/krb5.conf /etc/krb5.conf

# Set WORKDIR to HOME
WORKDIR /root

# Install all dependencies from yum
RUN yum-config-manager --add-repo=http://download.lab.eng.bos.redhat.com/beakerrepos/client/CentOS7/ && \
yum upgrade -y --skip-broken && \
yum install -y epel-release && \
yum install -y python python-devel python-pip && \
yum install -y beaker-common beakerlib beaker-client beaker-redhat python-beaker --nogpgcheck && \
yum install -y krb5-workstation libvirt-devel libyaml-devel openssl-devel libffi-devel gcc && \
yum install -y ansible jq ruby && \
yum clean all

# Install all pip dependencies
RUN pip install -U pip setuptools && \
    pip install -U beaker-common beaker-client
    # next RUN is to install latest linchpin from source
    #pip install -U linchpin cinch


RUN git clone https://github.com/herlo/linchpin.git && \
    cd linchpin && git checkout beaker_fixes && \
    pip install -U . && pip install -U cinch

#RUN git clone https://github.com/CentOS-PaaS-SIG/linchpin.git && \
#    cd linchpin && git checkout release1.5 && pip install -U . && pip install -U cinch

#    cd linchpin && \
#    git fetch origin pull/437/head:PR437 && \
#    git checkout PR437 && pip install -U . && pip install -U cinch

#    cd linchpin && git checkout release1.5 && pip install -U . && pip install -U cinch

# Setup certificates for RedHat
RUN cd /etc/pki/ca-trust/source/anchors && \
    curl -o RedHat_CA.crt --insecure -L https://password.corp.redhat.com/cacert.crt && \
    curl -o PnTDevOps_CA.crt --insecure -L https://engineering.redhat.com/Eng-CA.crt && \
    curl -o RH-IT-Root-CA.crt --insecure -L https://password.corp.redhat.com/RH-IT-Root-CA.crt && \
    update-ca-trust extract

# Configure beaker
RUN cp /etc/pki/ca-trust/source/anchors/RH-IT-Root-CA.crt /etc/beaker/RH-IT-Root-CA.crt

# Set home dir and env HOME var for SSH
WORKDIR /home/jenkins
ENV HOME=/home/jenkins
