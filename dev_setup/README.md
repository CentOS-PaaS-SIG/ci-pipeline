# Development Setup - minishift + pipeline
![CI-Pipeline](../continuous-infra-logo.png)

## What Does CI/CD Mean in the Context of the Continuous-infra Pipeline Project?

This is the method for setting up minishift + pipeline to do local development.
This will help in validating containers, shared pipeline libraries, and general code

## Getting Started

You need to have some sort of inventory file just as you do for running any ansible inventory.
This can be a static file, dynamic inventory, or a comma separated list of machines.

### Ansible Inventory

- "10.10.10.1,10.10.10.2,"
- [ansible inventory](http://docs.ansible.com/ansible/intro_inventory.html)
- [ansible dynamic inventory](http://docs.ansible.com/ansible/intro_dynamic_inventory.html)

### Generic Example

```
ansible-playbook -i <inventory> --private-key=</full/path/to/private/ssh/key> \
ci-pipeline/dev_setup/playbooks/setup.yml
```

## Ansible Playbook Role Structure
````
├── dev_setup
│   ├── playbooks
│   │   ├── group_vars
│   │   │   └── all
│   │   │       └── global.yml
│   │   ├── roles
│   │   │   ├── minishift
│   │   │   │   ├── defaults
│   │   │   │   │   └── main.yml
│   │   │   │   └── tasks
│   │   │   │       ├── init_minishift.yml
│   │   │   │       ├── install_minishift.yml
│   │   │   │       ├── main.yml
│   │   │   │       └── set_minishift_path.yml
│   │   │   ├── pipeline
│   │   │   │   ├── defaults
│   │   │   │   │   └── main.yml
│   │   │   │   ├── files
│   │   │   │   │   └── pipeline-scc.yaml
│   │   │   │   └── tasks
│   │   │   │       ├── add_scc.yml
│   │   │   │       ├── clone_pipeline.yml
│   │   │   │       ├── get_set_project.yml
│   │   │   │       ├── login_to_cluster.yml
│   │   │   │       ├── main.yml
│   │   │   │       ├── query_setup_cluster.yml
│   │   │   │       ├── set_oc_client.yml
│   │   │   │       ├── setup_containers.yml
│   │   │   │       ├── setup_fedmsg_relay.yml
│   │   │   │       ├── setup_jenkins_infra.yml
│   │   │   │       └── start_mcluster.yml
│   │   │   └── prereqs
│   │   │       └── tasks
│   │   │           ├── install_kvm_plugin.yml
│   │   │           ├── install_virtual_reqs.yml
│   │   │           ├── main.yml
│   │   │           └── nested_virt.yml
│   │   └── setup.yml
│   └── README.md
````

### Example

```
ansible-playbook -i "10.8.170.204," --private-key=/home/test-user/.ssh/ci-factory \
ci-pipeline/dev_setup/playbooks/setup.yml

```

### Playbooks

####  setup.yml

This will setup the minishift + pipeline development environment.  It can setup the entire environment
or only certain components.  ex. minishift, jenkins infra, pipeline containers, and fed-msg relay

##### default variables
```
ci-pipeline/dev_setup/playbooks/group_vars/all/global.yml

```

##### Key options
_______


* skip_prereqs: Skip setting up virtualization and kvm-driver : default=false
* force_minishift_install: Override an existing install of minishift : default=false
* setup_minishift: Setup a minishift cluster : default=true
* start_minishift: Start existing minishift cluster : default=true
* setup_jenkins: Setup Jenkins infrastructure master/slaves : default=true
* setup_fedmsg: Setup Fedmsg relay : default=true
* setup_containers: Setup pipeline containers : default=true
* modify_tags: Modify tags of containers : default=true
* tag: Add a tag besides latest : default=stable
* modify_scc: Create/update the security context constraints : default=true

_______



##### All Variables


| Variable Name                  | Description                                                             | Example                                            | Default                                   | Required |
|:------------------------------:|:-----------------------------------------------------------------------:|:--------------------------------------------------:|:-----------------------------------------:|:--------:|
| skip_prereqs                   |     Skip setting up virtualization and kvm-driver                       | skip_prereqs=true                                  |   false                                   | No       |
| force_minishift_install        |     Setup a minishift cluster                                           | force_minishift_install=true                       |   false                                   | No       |
| setup_minishift                |     Setup a minishift cluster                                           | setup_minishift=false                              |   true                                    | No       |
| start_minishift                |     Start existing minishift cluster                                    | start_minishift=false                              |   true                                    | No       |
| setup_jenkins                  |     Setup Jenkins infrastructure master/slaves                          | setup_jenkins=true                                 |   true                                    | No       |
| setup_fedmsg                   |     Setup Fedmsg relay                                                  | setup_fedmsg=true                                  |   true                                    | No       |
| setup_containers               |     Setup pipeline containers                                           | setup_containers=true                              |   true                                    | No       |
| modify_tags                    |     Modify tags of containers                                           | modify_tags=true                                   |   true                                    | No       |
| tag                            |     Add a tag besides latest                                            | tag=dev                                            |   "stable"                                | No       |
| modify_scc                     |     Create/update the security context constraints                      | modify_scc=false                                   |   true                                    | No       |
| minishift_dest_dir             |     Directory to store minishift binary                                 | minishift_dest_dir=/home/cloud-user/test           |   "{{ ansible_env.HOME }}/minishift"      | No       |
| profile                        |     Minishift cluster profile name                                      | profile=contra-cp                                  |   "minishift"                             | No       |
| disk_size                      |     Disk size for minishift                                             | disk_size=25gb                                     |   "40gb"                                  | No       |
| memory                         |     Memory for minishift                                                | memory=4000mb                                      |   "6400mb"                                | No       |
| basedevice_size                |     Base device size for pods in minishift                              | basedevice_size=30G                                |   "20G"                                   | No       |
| minishift_iso                  |     Minishift ISO url location                                          | minishift_iso=[url]                                |   "[ci-pipeline-minishift-iso-url]"       | No       |
| force_repo_clone               |     Force the clone of the pipeline git repo                            | force_repo_clone=true                              |   true                                    | No       |
| pipeline_repo                  |     Repo to clone for the pipeline                                      | pipeline_repo=https://github.com/cip               |   This repo ci-pipeline                   | No       |
| pipeline_dir                   |     Directory to clone repo to                                          | pipeline_dir=/path_to_pipeline                     |   "{{ ansible_env.HOME }}/minishift/cip"  | No       |
| pipeline_refspec               |     Repo refpec to checkout                                             | pipeline_refspec=refs/heads/*                      |  "+refs/pull/*:refs/heads/*"              | No       |
| pipeline_branch                |     Branch or SHA to checkout                                           | pipeline_branch=[SHA]                              |  "+master"                                | No       |
| username                       |     Cluster username                                                    | username=me                                        |   "developer"                             | No       |
| password                       |     Cluster password                                                    | password=password                                  |   "developer"                             | No       |  
| admin_username                 |     Admin cluster username                                              | username=me                                        |   "system"                                | No       |
| admin_password                 |     Admin cluster password                                              | password=password                                  |   "admin"                                 | No       |
| project                        |     Openshift project/namespace                                         | project=cvEngine                                   |   "continuous-infra"                      | No       |
| jenkins_bc_templates           |     Jenkins infrastrcuture container templates master/slaves            | List of Jenkins templates from the repo            |   check global.yaml                       | No       |
| fedmsg_bc_templates            |     Fedmsg relay container templates                                    | List of fedmsg templates from the repo             |   check global.yaml                       | No       |
| pipeline_bc_templates          |     Pipeline container templates                                        | List of container templates from the repo          |   check global.yaml                       | No       |
| enable_sample_pipeline         |     Enable a sample pipeline with all stage containers                  | enable_sample_pipeline=true                        |   true                                    | No       |
| sample_pipeline_bc_templates   |     Sample pipeline job templates                                       | List of sample pipeline job templates in the repo  |   check global.yaml                       | No       |
| sample_pipelines               |     Sample templates src temp, dest, and jenkins_file location          | List of key/value pairs                            |   check global.yml                        | No       | 
| PARAMS                         |     Parameters that are passed when setting up a new app in Openshift   | List of key/value pairs                            |   check global.yml                        | No       |


##### Sample pipeline project with running a VM inside a container

###### Overview

The sample pipeline project uses the following files to demonstrate a basic pipeline.<br>
There is an option to enable running a VM inside a container as part of pipeline stage.

##### Sample Pipeline Variables and Options

###### enable_sample_pipeline

This is set to true by default and will allow the setup of the sample pipeline jobs

###### Example 

```
enable_sample_pipeline: true
```

###### sample_pipeline_bc_templates

These are the build config templates that are setup inside Openshift for sample pipeline containers

###### Example 

```
sample_pipeline_bc_templates:
  - pipeline-sample-container/pipeline-sample-container
```

###### sample_pipelines

This containers the following:<br>
1. The 'src_loc' of where the templates live to create the sample pipeline jobs
2. The 'dest_loc' of where the sample pipeline job will get generated
3. The 'jenkins_file' which gets replaced in the job of where to find the Jenkinsfile that will be used

###### Example

```
sample_pipelines:
 - src_loc: "{{ pipeline_dir }}/dev_setup/playbooks/roles/pipeline/templates/contra-sample-pipeline1.xml.j2"
    dest_loc: "/tmp/contra-sample-pipeline1/config.xml"
    jenkins_file: "dev_setup/playbooks/roles/pipeline/files/JenkinsfileContraSample1"
```

###### PARAMS

These are the parameters when building the new-apps/containers.  Most recognized REPO_URL and REPO_REF of where to pull<br>
the Dockerfiles from and then the added ENABLE_VM and VM_IMG_URL which is for setting up running a VM inside a container<br>
and the location of where to get the cloud image.

###### Example

```
PARAMS:
  - key: REPO_URL
    val: "{{ pipeline_repo }}"
  - key: REPO_REF
    val: "{{ pipeline_branch }}"
  - key: ENABLE_VM
    val: false
  - key: VM_IMG_URL
    val: http://artifacts.ci.centos.org/artifacts/fedora-atomic/f26/images/latest-atomic.qcow2
```

##### Sample Pipeline Project Files
```
├── config
|   ├── Dockerfiles
│   │   ├── pipeline-sample-container
│   │   │   ├── default.xml
│   │   │   ├── Dockerfile
│   │   │   └── execute.sh
│   └── s2i
│       ├── pipeline-sample-container
│       │   └── pipeline-sample-container-buildconfig-template.yaml
├── dev_setup
│   ├── playbooks
│   │   ├── group_vars
│   │   │   └── all
│   │   │       └── global.yml
│   │   ├── roles
│   │   │   ├── pipeline
│   │   │   │   ├── defaults
│   │   │   │   │   └── main.yml
│   │   │   │   ├── files
│   │   │   │   │   ├── JenkinsfileContraSample1
│   │   │   │   │   └── pipeline-scc.yaml
│   │   │   │   ├── tasks
│   │   │   │   │   ├── add_scc.yml
│   │   │   │   │   ├── check_builds.yml
│   │   │   │   │   ├── main.yml
│   │   │   │   │   ├── query_setup_cluster.yml
│   │   │   │   │   ├── setup_jenkins_infra.yml
│   │   │   │   │   ├── setup_sample_pipelines.yml
│   │   │   │   └── templates
│   │   │   │       ├── contra-sample-pipeline1.xml.j2
│   │   │   │       └── pipeline-scc.yaml.j2
├── playbooks
│   ├── pipeline-sample-boot-verify.yml
│   ├── pipeline-sample.yml

```

#### Examples

###### Example 1: Setup on a local server :: Jenkins Infra and pipeline containers

 1. Install on a local server as user cloud-user.
 2. Don't setup pre-reqs (kvm driver and nested virtualization)
 3. Setup a minishift cluster.
 4. Setup jenkins infra and pipeline containers.
 5. Don't setup fedmsg relay.
 6. Modify my container tags with the default tag. tag=stable
 7. Override the pipeline_repo with another one then the default in global.yml
 8. The -K is used to prompt you for your password for sudo (if you require one)
 9. The -k is used to prompt you for your ssh password can hit enter if using -K and they are the same<br>
    _Note: Instead of -k you could use --private-key=<absolute_path_to_ssh_private_key>_
    
```
    ansible-playbook -vv -i "localhost," \
    ~/CentOS-PaaS-SIG/ci-pipeline/dev_setup/playbooks/setup.yml \
    -e remote_user=cloud-user -e skip_prereqs=true -e setup_minishift=true \
    -e setup_jenkins=true -e setup_containers=true \
    -e setup_fedmsg=false -e modify_tags=true \
    -e pipeline_repo=https://github.com/arilivigni/ci-pipeline -K -k

```

###### Example 2: Setup on a local server :: Jenkins Infra, fedmsg relay, and pipeline containers

 1. Install on a local server as user ari.
 2. Don't setup pre-reqs (kvm driver and nested virtualization)
 3. Don't setup a minishift cluster.
 4. Setup jenkins infra, fedmsg relay, and pipeline containers.
 5. Don't modify my container tags and 
 6. Don't clone the pipeline repo if it exists.

```
    ansible-playbook -vv -i "localhost," --private-key=/home/cloud-user/my-key \
    ~/CentOS-PaaS-SIG/ci-pipeline/dev_setup/playbooks/setup.yml \
    -e remote_user=ari -e skip_prereqs=false -e setup_minishift=false \
    -e setup_jenkins=true -e setup_containers=true \
    -e setup_fedmsg=true -e modify_tags=false -e force_clone=false -K
```


###### Example 3: Setup on a remote server :: Jenkins Infra and pipeline containers

 1. Install on a remote server as user cloud-user.
 2. Don't setup pre-reqs (kvm driver and nested virtualization)
 3. Setup a minishift cluster.
 4. Setup jenkins infra and pipeline containers.
 5. Don't setup fedmsg relay.
 6. Modify my container tags with the default tag. tag=stable
 7. The -K is used to prompt you for your password for sudo (if you require one) 
 8. The -k is used to prompt you for your ssh password can hit enter if using -K and they are the same<br>
    _Note: Instead of -k you could use --private-key=<absolute_path_to_ssh_private_key>_

```
    ansible-playbook -vv -i "ci-srv-01.bos.redhat.com," --private-key=/home/cloud-user/my-key \                        
    ~/CentOS-PaaS-SIG/ci-pipeline/dev_setup/playbooks/setup.yml \
    -e remote_user=cloud-user -e skip_prereqs=true -e setup_minishift=true \
    -e setup_jenkins=true -e setup_containers=true \
    -e setup_fedmsg=false -e modify_tags=true -K

```

