#!/bin/bash
set -x
##
oc project continuous-infra
oc create -f rpmbuild/rpmbuild-buildconfig-template.yaml
oc create -f rsync/rsync-buildconfig-template.yaml
oc create -f ostree_compose/ostree_compose-buildconfig-template.yaml
oc create -f ostree-image-compose/ostree-image-compose-buildconfig-template.yaml
oc create -f ostree-boot-image/ostree-boot-image-buildconfig-template.yaml
oc create -f singlehost-test/singlehost-test-buildconfig-template.yaml
oc create -f linchpin_libvirt/linchpin_libvirt-buildconfig-template.yml 
##
if [ -z "${REPO_URL}" ] ; then
  REPO_URL_PARAM=""
else
  REPO_URL_PARAM="-p REPO_URL=${REPO_URL}"
fi
##
if [ -z "${REPO_REF}" ] ; then
  REPO_REF_PARAM=""
else
  REPO_REF_PARAM="-p REPO_REF=${REPO_REF}"
fi
oc new-app rpmbuild-builder ${REPO_URL_PARAM} ${REPO_REF_PARAM}
oc new-app rsync-builder ${REPO_URL_PARAM} ${REPO_REF_PARAM}
oc new-app ostree-compose-builder ${REPO_URL_PARAM} ${REPO_REF_PARAM}
oc new-app ostree-image-compose-builder ${REPO_URL_PARAM} ${REPO_REF_PARAM}
oc new-app ostree-boot-image-builder ${REPO_URL_PARAM} ${REPO_REF_PARAM}
oc new-app singlehost-test-builder ${REPO_URL_PARAM} ${REPO_REF_PARAM}
oc new-app linchpin-libvirt-builder ${REPO_URL_PARAM} ${REPO_REF_PARAM}
##
