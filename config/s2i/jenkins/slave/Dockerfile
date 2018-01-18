FROM openshift/jenkins-slave-base-centos7:v3.6
##
## ------------------------------------->  ^^ this is needed
## since the centosCI openshift cluster
## is running 3.6 and the slave needs the
## correct 'oc' binary to work properly
## This should be updated when the cluster
## is upgraded.
##
RUN yum install -y epel-release
# add ruby for ghi
RUN yum install -y ansible jq ruby
