# Development Setup - minishift + pipeline
![CI-Pipeline](../continuous-infra-logo.png)

## What Does CI/CD Mean in the Context of the CI-Pipeline Project?

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
ansible -i <inventory> --private-key=</full/path/to/private/ssh/key> \
ci-pipeline/dev_setup/
```

## Ansible Playbook Role Structure
````
├── dev_setup
│   ├── playbooks
│   │   ├── group_vars
│   │   │   └── all
│   │   │       └── global.yml
│   │   ├── roles
│   │   │   ├── containers
│   │   │   │   ├── defaults
│   │   │   │   │   └── main.yml
│   │   │   │   ├── files
│   │   │   │   │   └── pipeline-scc.yaml
│   │   │   │   └── tasks
│   │   │   │       ├── add_scc.yml
│   │   │   │       └── main.yml
│   │   │   ├── jenkins
│   │   │   │   └── tasks
│   │   │   │       ├── jenkins_infra.yml
│   │   │   │       └── main.yml
│   │   │   ├── minishift
│   │   │   │   ├── defaults
│   │   │   │   │   └── main.yml
│   │   │   │   └── tasks
│   │   │   │       ├── init_minishift.yml
│   │   │   │       ├── install_minishift.yml
│   │   │   │       └── main.yml
│   │   │   ├── pipeline
│   │   │   │   ├── defaults
│   │   │   │   │   └── main.yml
│   │   │   │   └── tasks
│   │   │   │       ├── clone_pipeline.yml
│   │   │   │       ├── main.yml
│   │   │   │       └── start_mcluster.yml
│   │   │   └── prereqs
│   │   │       └── tasks
│   │   │           ├── install_kvm_plugin.yml
│   │   │           ├── install_virtual_reqs.yml
│   │   │           ├── main.yml
│   │   │           └── nested_virt.yml
│   │   ├── setup_containers.yml
│   │   └── setup.yml
│   └── README.md
````

### Example

```
ansible -i "10.8.170.204," --private-key=/home/test-user/.ssh/ci-factory \
ci-infrastructure/infrastructure/setup.yml

```

### Playbooks

####  setup.yml
        This will setup the minishift + pipeline development environment

##### default variables
```

```

##### Key options
_______

#### setup_containers.yml
    This will setup just containers in an existing minishift environment

```

```
_______


```

```

##### Important Variables

table with Variables

#### Examples

###### Example 1:

```
```


###### Example 2:

```
```

###### Example 3:

```
```
