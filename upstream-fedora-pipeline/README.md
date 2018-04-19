## What are these?

The pipelines defined in https://github.com/CentOS-PaaS-SIG/upstream-fedora-pipeline depend on containers that are defined in this pipeline. Some of these containers are not part of the Atomic CI Pipeline (e.g. cloud-image-compose). Thus, this directory holds definitions for a stage trigger and merge job for changes to the containers of interest to the upstream-fedora-pipeline. The jobs will ensure that any changes to these containers do not break those pipelines.

Note that if something changes in the CI Pipeline shared library, this workflow will not validate it against the upstream-fedora-pipeline repos.
