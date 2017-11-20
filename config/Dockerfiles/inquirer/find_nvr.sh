#!/bin/bash

# Parameters:
# package - Package name to get NVR of
# rpm_repo - Pointer to repo we want to query
# Returns:
# package.props with expected=$rpm_nvr

set -ex

base_dir="$( pwd )"
rm -rf ${base_dir}/logs
mkdir -p ${base_dir}/logs

# Get NVR
rpm_nvr=$(repoquery --disablerepo=\* --enablerepo=${package} --repofrompath=${package},${rpm_repo} --nvr ${package})
echo "expected=$rpm_nvr" > ${base_dir}/logs/package.props
