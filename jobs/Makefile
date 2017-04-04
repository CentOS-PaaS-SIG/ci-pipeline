all:
	test -d centos-ci-skeleton || git clone https://github.com/cgwalters/centos-ci-skeleton
	cd centos-ci-skeleton && make CENTOSCIPROJECTNAME=ci-pipeline CENTOSCINODE=fedora-atomic

update:
	jenkins-jobs --conf jenkins.ini update centos-ci-skeleton/jjb:.
