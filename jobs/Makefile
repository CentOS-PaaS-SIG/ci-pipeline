JJB_CONFIG ?= $(HOME)/.jjb/centos-config.ini

all:
	test -d centos-ci-skeleton || git clone https://github.com/cgwalters/centos-ci-skeleton
	cd centos-ci-skeleton && make CENTOSCIPROJECTNAME=ci-pipeline CENTOSCINODE=fedora-atomic

update: all
	jenkins-jobs --conf $(JJB_CONFIG) update centos-ci-skeleton/jjb:.
