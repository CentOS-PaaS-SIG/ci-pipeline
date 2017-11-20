#!/bin/bash

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

oc create -f fedmsg-relay-buildconfig-template.yaml
oc new-app fedmsg-relay ${REPO_URL_PARAM} ${REPO_REF_PARAM}
