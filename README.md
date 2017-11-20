<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [CI-Pipeline Architecture and Design](#ci-pipeline-architecture-and-design)
  - [What Does CI/CD Mean in the Context of the CI-Pipeline Project?](#what-does-cicd-mean-in-the-context-of-the-ci-pipeline-project)
  - [CI-Pipeline Overview](#ci-pipeline-overview)
  - [Dependencies and Assumptions](#dependencies-and-assumptions)
    - [Automation Frameworks and Tests](#automation-frameworks-and-tests)
    - [Triggering the Pipeline](#triggering-the-pipeline)
    - [CI/CD Toolset and Infrastructure](#cicd-toolset-and-infrastructure)
      - [Openshift, Jenkins 2.0 pipeline, Pipeline Shared Libraries](#openshift-jenkins-20-pipeline-pipeline-shared-libraries)
        - [Jenkins 2.0 Pipeline](#jenkins-20-pipeline)
          - [Jenkins Masters and Slaves](#jenkins-masters-and-slaves)
        - [Pipeline Shared Libraries](#pipeline-shared-libraries)
    - [CI the CI-Pipeline - Inception](#ci-the-ci-pipeline---inception)
      - [Example of CI the CI-Pipeline](#example-of-ci-the-ci-pipeline)
    - [Pipeline References](#pipeline-references)
  - [Example Project - Fedora Atomic Host](#example-project---fedora-atomic-host)
    - [Fedora Atomic Host Complete View](#fedora-atomic-host-complete-view)
      - [Automation Frameworks and Testing in Fedora](#automation-frameworks-and-testing-in-fedora)
      - [Design Diagrams](#design-diagrams)
      - [CI-Pipeline in Action](#ci-pipeline-in-action)
    - [Fedora Atomic Host Pipeline Stages](#fedora-atomic-host-pipeline-stages)
      - [Trigger](#trigger)
      - [Build Package](#build-package)
      - [Functional Tests on Packages](#functional-tests-on-packages)
      - [Compose an OStree](#compose-an-ostree)
      - [Integration Tests on OStree Composes and Images](#integration-tests-on-ostree-composes-and-images)
      - [Image Generated From Successful Integration Tests On OStree](#image-generated-from-successful-integration-tests-on-ostree)
      - [Openshift Cluster and e2e Conformance tests on top of Fedora Atomic Host](#openshift-cluster-and-e2e-conformance-tests-on-top-of-fedora-atomic-host)
      - [Image Smoke Test Validation](#image-smoke-test-validation)
    - [fedmsg Bus](#fedmsg-bus)
      - [fedmsg - Message Types](#fedmsg---message-types)
        - [fedmsg - Message Legend](#fedmsg---message-legend)
      - [Trigger - org.fedoraproject.prod.git.receive](#trigger---orgfedoraprojectprodgitreceive)
      - [Dist-git message example](#dist-git-message-example)
      - [org.centos.prod.ci.pipeline.package.ignore](#orgcentosprodcipipelinepackageignore)
      - [org.centos.prod.ci.pipeline.package.queued](#orgcentosprodcipipelinepackagequeued)
      - [org.centos.prod.ci.pipeline.package.running](#orgcentosprodcipipelinepackagerunning)
      - [org.centos.prod.ci.pipeline.package.complete](#orgcentosprodcipipelinepackagecomplete)
      - [org.centos.prod.ci.pipeline.package.test.functional.queued](#orgcentosprodcipipelinepackagetestfunctionalqueued)
      - [org.centos.prod.ci.pipeline.package.test.functional.running](#orgcentosprodcipipelinepackagetestfunctionalrunning)
      - [org.centos.prod.ci.pipeline.package.test.functional.complete](#orgcentosprodcipipelinepackagetestfunctionalcomplete)
      - [org.centos.prod.ci.pipeline.compose.running](#orgcentosprodcipipelinecomposerunning)
      - [org.centos.prod.ci.pipeline.compose.complete](#orgcentosprodcipipelinecomposecomplete)
      - [org.centos.prod.ci.pipeline.image.running](#orgcentosprodcipipelineimagerunning)
      - [org.centos.prod.ci.pipeline.image.complete](#orgcentosprodcipipelineimagecomplete)
      - [org.centos.prod.ci.pipeline.image.test.smoke.running](#orgcentosprodcipipelineimagetestsmokerunning)
      - [org.centos.prod.ci.pipeline.image.test.smoke.complete](#orgcentosprodcipipelineimagetestsmokecomplete)
      - [org.centos.prod.ci.pipeline.compose.test.integration.queued](#orgcentosprodcipipelinecomposetestintegrationqueued)
      - [org.centos.prod.ci.pipeline.compose.test.integration.running](#orgcentosprodcipipelinecomposetestintegrationrunning)
      - [org.centos.prod.ci.pipeline.compose.test.integration.complete](#orgcentosprodcipipelinecomposetestintegrationcomplete)
      - [org.centos.prod.ci.pipeline.complete](#orgcentosprodcipipelinecomplete)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# CI-Pipeline Architecture and Design
![CI-Pipeline](continuous-infra-logo.png)

## What Does CI/CD Mean in the Context of the CI-Pipeline Project?

True CI starts at gating developers before code is integrated into the general code base to find bugs sooner. 
It is less costly for the developer that changed the code to fix their own issues before the code is merged into the repo.
Obviously there is a certain balance of what testing/validation is run and time to get feedback to the developer and this may vary among projects.

## CI-Pipeline Overview

CI in general is the continuous integration of components/projects/products and validating these work together and then providing feedback to developers.
Continuous delivery is the act of taking these integrated components that have been validated and are stable and delivering them with consistency over and over efficiently.
Continuous deployment allows us to take the deliverable and deploy it on some set of infrastructure to be used in a development, stage, and/or production environments. <br><br>

The way continuous integration works is that robots test every change. They can then tell you which change caused the integrated result to break. We can then “gate” that change and ask a human to fix it.
When those changes are small and regular, the robots can gate it, and it’s trivial for a developer to quickly see why and how the change broke the code.
On the other hand, if the changes that flow into continuous integration are massive bundles of changes, with months between them, with myriad test failures, then it becomes a tedious never-ending process to dissect them and figure out what went wrong. The effect of continuous integration evaporates.
Hence we arrive at the following truth: <br>
 
<b>The closer to the source of change the continuous integration acts, the more effective it is.<br></b>

This CI/CD toolset is designed to provide a flexible solution to that problem.  The pipeline is fully containerized and built using upstream projects Openshift, Jenkins, and Ansible.
This makes the pipeline extremely portable and can run in any Openshift instance and adapted to any project/product.

## Dependencies and Assumptions

### Automation Frameworks and Tests

The CI-Pipeline is NOT an automation framework or set of automated tests.  There are plenty of those that exist and this project's goal is to be flexible to accommodate execution of any automation framework, tests and tools, especially if they are already integrated in a container.  
Unit tests can easily be defined as make targets and can run as part of the build and need minimal resources.  Functional and integration testing may require more robust test beds to execute scenarios.  
In most cases these more complex tests can still be verified inside containers or VMs running inside containers.  This is both more efficient and provides a quicker feedback loop for developers.

### Triggering the Pipeline

Since Jenkins is integrated with many trigger options we can easily trigger the pipeline based on cron, github, gerrit, gitlab, and fedmsg thanks to the [Jenkins JMS plugin](https://wiki.jenkins-ci.org/display/JENKINS/JMS+Messaging+Plugin)

### CI/CD Toolset and Infrastructure

We are dependent on the following tools:
 * Openshift
   * Containers
 * Jenkins 2.0
   * Plugins
   * Pipeline
   * Shared libraries
 * Ansible

#### Openshift, Jenkins 2.0 pipeline, Pipeline Shared Libraries


##### Openshift
 
The CI-Pipeline is defined using Jenkins 2.0 pipeline (Jenkinsfile) + shared libraries.  Jenkins 2.0 Pipeline is already integrated into Openshift [(Openshift Pipelines Deep Dive)](https://blog.openshift.com/openshift-3-3-pipelines-deep-dive/).
All our pipeline components, containers, etc. are running inside the CentOS Openshift instance.

##### Jenkins 2.0 Pipeline 
Our Jenkins master that runs inside Openshift is [Jenkins Master](https://jenkins-continuous-infra.apps.ci.centos.org/)

###### Jenkins Masters and Slaves

The Jenkins Master is created from Openshift's s2i (source-to-image) feature.  This means we can create our infrastructure for our pipeline right from source.
The Jenkins Master is backed by a persistent volume to maintain historical data.<br>

Slave images are created from Dockerfiles.   

````
├── config
│   └── s2i
│       ├── create-containers.sh
│       ├── jenkins
│       │   ├── continuous-infra-create-openshift-project
│       │   ├── continuous-infra-jenkins-master-s2i-template.yaml
│       │   ├── continuous-infra-slave-template.yaml
│       │   ├── master
│       │   │   ├── configuration
│       │   │   │   ├── hudson.plugins.ircbot.IrcPublisher.xml
│       │   │   │   ├── hudson.tasks.Maven.xml
│       │   │   │   ├── init.groovy
│       │   │   │   └── jobs
│       │   │   │       ├── fedmsg-test
│       │   │   │       │   └── config.xml
│       │   │   │       └── maven-test
│       │   │   │           └── config.xml
│       │   │   └── plugins.txt
│       │   └── slave
│       │       └── Dockerfile

````

##### Pipeline Shared Libraries

We have shared libraries that are used in this repo/project and we also use other shared libraries that we contribute to along with the CentOS Community<br>
[cico-pipeline-library](https://github.com/CentOS/cico-pipeline-library)
<br>

The libraries in this repo/project follows the [Jenkins community shared library structure](https://jenkins.io/doc/book/pipeline/shared-libraries/):

````
├── src
│   └── org
│       └── centos
│           └── pipeline
│               └── PipelineUtils.groovy
└── vars
    └── pipelineUtils.groovy
````

### CI the CI-Pipeline - Inception

Since we can easily integrate into github then we can use our own pipeline to validate our stage containers, pipeline code, and shared libraries.  
 1. We inspect the changelog in the pipeline using the [Jenkins declaritive pipeline DSL](https://github.com/CentOS-PaaS-SIG/ci-pipeline/blob/master/JenkinsfileStageTrigger).
 2. If stage containers are touched then they are built in Openshift and validated
 3. If the stage container passes validation it is tagged stable and promoted to production in the pipeline
 4. If a container and/or pipeline code and/or shared libraries are changed the change is run through the pipeline for validation

#### Example of CI the CI-Pipeline

![ci-the-ci-pipeline](stage-pipeline-trigger.gif) 

### Pipeline References

Currently documentation, Jenkins master/slave containers, container definitions - s2i/docker, pipeline shared libraries, tools, etc. are located [here in this repo](https://github.com/CentOS-PaaS-SIG/ci-pipeline).

## Example Project - Fedora Atomic Host

In leveraging the CI-Pipeline this project was able to deliver a stable Fedora Atomic host and gate packagers in Fedora.  We were able to integrate with fedmsg as our trigger and publishing communication backbone.
This allowed us to gate packagers in the Fedora infrastructure. 


### Fedora Atomic Host Complete View

#### Automation Frameworks and Testing in Fedora

Setup and invoking of tests is being done using ansible as outlined in [Invoking CI Tests](https://fedoraproject.org/wiki/CI/Tests)

#### Design Diagrams
![ci-pipeline-detail](ci-pipeline-detail.png) 

#### CI-Pipeline in Action
![Fedora Atomic f26 example](ci-pipelinef26.gif)

### Fedora Atomic Host Pipeline Stages

#### Trigger

Once packages are pushed to Fedora dist-git this will trigger a message.  The pipeline will be triggered via the [Jenkins JMS plugin](https://wiki.jenkins-ci.org/display/JENKINS/JMS+Messaging+Plugin) for dist-git messages on fedmsg.  
Only Fedora Atomic Host packages are monitored for changes currently.  This can easliy be broadened to all of Fedora packages.

CI Pipeline messages sent via fedmsg for this stage are captured by the topics org.centos.prod.ci.pipeline.package.[queued,ignored].

#### Build Package

Once the pipeline is triggered as part of the build process if unit tests exist they will be executed.

The end result is package will be produced to then be used for further testing.  Success or failure will result with a fedmsg back to the Fedora package maintainer.

CI Pipeline messages sent via fedmsg for this stage are captured by the topics org.centos.prod.ci.pipeline.package.[running,complete].

#### Functional Tests on Packages

Functional tests will be executed on the produced package from the previous stage of the pipeline if they exist.  This will help identify issues isolated to the package themselves.  Success or failure will result with a fedmsg back to the Fedora package maintainer.

CI Pipeline messages sent via fedmsg for this stage are captured by the topics org.centos.prod.ci.pipeline.package.test.functional.[queued,running,complete].

#### Compose an OStree

If functional tests are successful in the previous stage of the pipeline then an OStree compose is generated.

CI Pipeline messages sent via fedmsg for this stage are captured by the topics org.centos.prod.ci.pipeline.compose.[running,complete].

#### Integration Tests on OStree Composes and Images

Integration tests are run on the OStree compose.  Success or failure will result with a fedmsg back to the Fedora package maintainer.

CI Pipeline messages sent via fedmsg for this stage are captured by the topics org.centos.prod.ci.pipeline.compose.test.integration[queued,running,complete].

#### Image Generated From Successful Integration Tests On OStree

An image will be initially generated at a certain interval when there has been successful integration test execution on an OStree compose. Success or failure will result with a fedmsg back to the Fedora package maintainer.

CI Pipeline messages sent via fedmsg for this stage are captured by the topics org.centos.prod.ci.pipeline.image.[running,complete].

#### Openshift Cluster and e2e Conformance tests on top of Fedora Atomic Host

If integration tests of the images are successful an openshift cluster will be configured using the Atomic Openshift Installer with the new Fedora Atomic Host image as the base system.  Once the cluster is configured Kubernetes conformance tests will run. Success or failure will result with a fedmsg back to the Fedora package maintainer.

#### Image Smoke Test Validation

The validation left is to make sure the image can boot and more smoke tests may follow if required.  Success or failure will result with a fedmsg sent back to the Fedora package maintainer.  Also, this can trigger the Red Hat continuous delivery process to run more comprehensive testing.

CI Pipeline messages sent via fedmsg for this stage are captured by the topics org.centos.prod.ci.pipeline.image.test.smoke.[running,complete].

### fedmsg Bus

Communication between Fedora, CentOS, and Red Hat infrastructures will be done via fedmsg.  Messages will be received of updates to dist-git repos that we are concerned about for Fedora Atomic host.  Triggering will happen from Fedora dist-git. The CI-Pipeline in CentOS infrastructure will build and functional test packages, compose and integration test ostrees, generate and smoke test (boot) images.  We are dependant on CentOS Infrastructure for allowing us a hub for publishing messages to fedmsg.

#### fedmsg - Message Types
Below are the different message types that we listen and publish.  There will be different subtopics so we can keep things organized under the org.centos.prod.ci.pipeline.* umbrella. The fact that ‘org.centos’ is contained in the messages is a side effect of the way fedmsg enforces message naming.

##### fedmsg - Message Legend

* CI_TYPE - Type of message we are sending (default value = custom)
  - ex. custom
* build_id - Jenkins pipeline build ID
  - ex. 91
* build_url - Full url to the Jenkins pipeline build  
  - ex. https://jenkins-continuous-infra.apps.ci.centos.org/job/ci-pipeline-f26/91/
* username - Audit of who is sending the message (default value = fedora-atomic)
  - ex. fedora_atomic
* compose_url - Full url to the OStree compose 
  - ex. http://artifacts.ci.centos.org/artifacts/fedora-atomic/f26/ostree
* compose_rev - SHA-1 of the compose
  - ex. c15b07cc0f560dd4325b64b8ed8f5750ab102f2ff2e0ace39cda4158f900e4da
* rev - This is the commit SHA-1 that is passed on from the dist-git message we recieve 
  - ex. 591b0d2fc67a45e4ad13bdc3e312d5554852426a
* image_url - Full url to the image 
  - ex. http://artifacts.ci.centos.org/artifacts/fedora-atomic/f26/images/fedora-atomic-26.200-c15b07cc0f560dd.qcow2
* image_name - Image name
  - ex. fedora-atomic-26.200-c15b07cc0f560dd.qcow2
* message-content - If additional content is needed in the bod of the message (default = "")
* namespace - Packaging type passed from dist-git message 
  - ex. rpms
* original_spec_nvr - The NVR of the RPM if the spec file hadn't been modified
  - ex. gnutls-3.5.15-1.fc26
* nvr - The NVR of the RPM after modification, so including sha and # commits
  - ex. gnutls-3.5.15-1.246.a3e666c.fc26
* CI_NAME - Jenkins pipeline job name
  - ex. ci-pipeline-f26
* repo - Package name
  - ex. vim
* topic - Topic that is being published on the fedmsg bus
  - ex. org.centos.prod.ci.pipeline.image.complete
* status - Status of the stage and overall pipeline at the time when the message is published.
           UNSTABLE status indicates that some tests did not pass and should be analyzed.
  - ex. SUCCESS
  - options = <SUCCESS/FAILURE/UNSTABLE/ABORTED>
* branch - Fedora branch master = rawhide for now this may change in the future 
  - ex. f26
* type - Image type 
  - ex. qcow2
* test_guidance - <comma-separated-list-of-test-suites-to-run> required by downstream CI
  - ex. "''"
* ref - Indication of what we are building distro/branch/arch/distro_type
  - ex. fedora/f26/x86_64/atomic-host
* msgJson - A full dump of the message properties in one field of JSON


Each change passing through the pipeline is uniquely identified by repo, rev, and namespace. 

#### Trigger - org.fedoraproject.prod.git.receive

Below is an example of the message that we will trigger off of to start our CI pipeline.  We concentrate on the commit part of the message.

````
username=jchaloup
stats={u'files': {u'fix-rootScopeNaming-generate-selfLink-issue-37686.patch': {u'deletions': 8, u'additions': 8, u'lines': 16}, u'build-with-debug-info.patch': {u'deletions': 8, u'additions': 8, u'lines': 16}, u'get-rid-of-the-git-commands-in-mungedocs.patch': {u'deletions': 25, u'additions': 0, u'lines': 25}, u'kubernetes.spec': {u'deletions': 13, u'additions': 11, u'lines': 24}, u'remove-apiserver-add-kube-prefix-for-hyperkube-remov.patch': {u'deletions': 0, u'additions': 169, u'lines': 169}, u'.gitignore': {u'deletions': 1, u'additions': 1, u'lines': 2}, u'sources': {u'deletions': 1, u'additions': 1, u'lines': 2}, u'remove-apiserver-add-kube-prefix-for-hyperkube.patch': {u'deletions': 66, u'additions': 0, u'lines': 66}, u'use_go_build-is-not-fully-propagated-so-make-it-fixe.patch': {u'deletions': 5, u'additions': 5, u'lines': 10}, u'Hyperkube-remove-federation-cmds.patch': {u'deletions': 118, u'additions': 0, u'lines': 118}, u'fix-support-for-ppc64le.patch': {u'deletions': 9, u'additions': 9, u'lines': 18}}, u'total': {u'deletions': 254, u'files': 11, u'additions': 212, u'lines': 466}}
name=Jan Chaloupka
namespace=rpms
rev=b0ef5e0207cea46836a49cd4049908f14015ed8d
agent=jchaloup
summary=Update to upstream v1.6.1
repo=kubernetes
branch=f26
path=/srv/git/repositories/rpms/kubernetes.git
seen=False
message=Update to upstream v1.6.1- related: #1422889
email=jchaloup@redhat.com
````

#### Dist-git message example
````
{
  "source_name": "datanommer",  
  "i": 1, 
  "timestamp": 1493386183.0, 
  "msg_id": "2017-b29fa2b4-0600-4f08-9475-5f82f6684bd4", 
  "topic": "org.fedoraproject.prod.git.receive", 
  "source_version": "0.6.5", 
  "signature": "MbQSb1uwzh6UIFKVm+Uxt+56nW/QRH1nOehifxUrbZfiEDEscRdHtb8dj1Skdv7fcZGHhNlR3PGI\nz/4YqPFJjoAM/k60FsnBIIG1gklJaFBM8MloEYauzo/fUK//W99ojk3UPK0lGTIBijG2knbD9t3T\nUMRuDjt45zmGBXHPlR8=\n", 
  "msg": {
    "commit": {
      "username": "trasher", 
      "stats": {
        "files": {
          "sources": {
            "deletions": 1, 
            "additions": 1, 
            "lines": 2
          }, 
          "php-simplepie.spec": {
            "deletions": 5, 
            "additions": 8, 
            "lines": 13
          }, 
          ".gitignore": {
            "deletions": 0, 
            "additions": 1, 
            "lines": 1
          }
        }, 
        "total": {
          "deletions": 6, 
          "files": 3, 
          "additions": 10, 
          "lines": 16
        }
      }, 
      "name": "Johan Cwiklinski", 
      "rev": "81e09b9c83e8550b54a64c7bdb4e5d7b534df058", 
      "namespace": "rpms", 
      "agent": "trasher", 
      "summary": "Last upstream release", 
      "repo": "php-simplepie", 
      "branch": "f24", 
      "seen": false, 
      "path": "/srv/git/repositories/rpms/php-simplepie.git", 
      "message": "Last upstream release\n", 
      "email": "johan@x-tnd.be"
    }
  }
}
````

#### org.centos.prod.ci.pipeline.package.ignore

````
{
  "i": 1, 
  "timestamp": 1507135702, 
  "msg_id": "2017-1dc328f8-7421-4d09-8a4f-41ec82f00785", 
  "crypto": "x509", 
  "topic": "org.centos.prod.ci.pipeline.package.ignore", 
  "msgJson": "{\"CI_NAME\":\"ci-pipeline-trigger\",\"CI_TYPE\":\"custom\",\"branch\":\"rawhide\",\"build_id\":\"52867\",\"build_url\":\"https://jenkins-continuous-infra.apps.ci.centos.org/jo
b/ci-pipeline-trigger/52867/\",\"message-content\":\"\",\"namespace\":\"rpms\",\"ref\":\"fedora/rawhide/x86_64/atomic-host\",\"repo\":\"polari\",\"rev\":\"8073b99c61e58abb8fbcd60cf8ea518d184d0108\",\"status\":\"SUCCESS\",\"test_guidance\"
:\"''\",\"topic\":\"org.centos.prod.ci.pipeline.package.ignore\",\"username\":\"fedora-atomic\"}", 
  "msg": {
    "CI_TYPE": "custom", 
    "build_id": "52867", 
    "username": "fedora-atomic", 
    "rev": "8073b99c61e58abb8fbcd60cf8ea518d184d0108", 
    "message-content": "", 
    "build_url": "https://jenkins-continuous-infra.apps.ci.centos.org/job/ci-pipeline-trigger/52867/", 
    "namespace": "rpms", 
    "CI_NAME": "ci-pipeline-trigger", 
    "repo": "polari", 
    "topic": "org.centos.prod.ci.pipeline.package.ignore", 
    "status": "SUCCESS", 
    "branch": "rawhide", 
    "test_guidance": "''", 
    "ref": "fedora/rawhide/x86_64/atomic-host"
  }
}
````

#### org.centos.prod.ci.pipeline.package.queued

````
{
  "i": 1, 
  "timestamp": 1507062395, 
  "msg_id": "2017-2d2e013c-12bd-4ee7-9edc-167aaf0a162b", 
  "crypto": "x509", 
  "topic": "org.centos.prod.ci.pipeline.package.queued", 
  "msgJson": "{\"CI_NAME\":\"ci-pipeline-trigger\",\"CI_TYPE\":\"custom\",\"branch\":\"f26\",\"build_id\":\"52257\",\"build_url\":\"https://jenkins-continuous-infra.apps.ci.centos.org/job/ci
-pipeline-trigger/52257/\",\"message-content\":\"\",\"namespace\":\"rpms\",\"ref\":\"fedora/f26/x86_64/atomic-host\",\"repo\":\"mesa\",\"rev\":\"163e745ef5f654a5df09ccca9350dc98e926af39\",\"status\":\"SUCCESS\",\"test_guidance\":\"''\",\"
topic\":\"org.centos.prod.ci.pipeline.package.queued\",\"username\":\"fedora-atomic\"}", 
  "msg": {
    "CI_TYPE": "custom", 
    "build_id": "52257", 
    "username": "fedora-atomic", 
    "rev": "163e745ef5f654a5df09ccca9350dc98e926af39", 
    "message-content": "", 
    "build_url": "https://jenkins-continuous-infra.apps.ci.centos.org/job/ci-pipeline-trigger/52257/", 
    "namespace": "rpms", 
    "CI_NAME": "ci-pipeline-trigger", 
    "repo": "mesa", 
    "topic": "org.centos.prod.ci.pipeline.package.queued", 
    "status": "SUCCESS", 
    "branch": "f26", 
    "test_guidance": "''", 
    "ref": "fedora/f26/x86_64/atomic-host"
  }
}
````

#### org.centos.prod.ci.pipeline.package.running

````
{
  "i": 1, 
  "timestamp": 1507135699, 
  "msg_id": "2017-d7510906-71dd-48a9-a3b4-56d6f64ce9c9", 
  "crypto": "x509", 
  "topic": "org.centos.prod.ci.pipeline.package.running", 
  "msgJson": "{\"CI_NAME\":\"continuous-infra-ci-pipeline-f26\",\"CI_TYPE\":\"custom\",\"branch\":\"f26\",\"build_id\":\"464\",\"build_url\":\"https://jenkins-continuous-infra.apps.ci.centos
.org/job/continuous-infra-ci-pipeline-f26/464/\",\"compose_rev\":\"\",\"message-content\":\"\",\"namespace\":\"rpms\",\"nvr\":\"\",\"original_spec_nvr\":\"\",\"ref\":\"fedora/f26/x86_64/atomic-host\",\"repo\":\"mesa\",\"rev\":\"35fdde92a0
292def6a99acd3c237272789d020b2\",\"status\":\"SUCCESS\",\"test_guidance\":\"''\",\"topic\":\"org.centos.prod.ci.pipeline.package.running\",\"username\":\"fedora-atomic\"}", 
  "msg": {
    "CI_TYPE": "custom", 
    "build_id": "464", 
    "original_spec_nvr": "", 
    "username": "fedora-atomic", 
    "nvr": "", 
    "rev": "35fdde92a0292def6a99acd3c237272789d020b2", 
    "message-content": "", 
    "build_url": "https://jenkins-continuous-infra.apps.ci.centos.org/job/continuous-infra-ci-pipeline-f26/464/", 
    "namespace": "rpms", 
    "CI_NAME": "continuous-infra-ci-pipeline-f26", 
    "repo": "mesa", 
    "compose_rev": "", 
    "topic": "org.centos.prod.ci.pipeline.package.running", 
    "status": "SUCCESS", 
    "branch": "f26", 
    "test_guidance": "''", 
    "ref": "fedora/f26/x86_64/atomic-host"
  }
}
````

#### org.centos.prod.ci.pipeline.package.complete

````
{
  "i": 1, 
  "timestamp": 1507136310, 
  "msg_id": "2017-0f165bf3-0324-40cc-9cd4-a008c9522d96", 
  "crypto": "x509", 
  "topic": "org.centos.prod.ci.pipeline.package.complete", 
  "msgJson": "{\"CI_NAME\":\"continuous-infra-ci-pipeline-f26\",\"CI_TYPE\":\"custom\",\"branch\":\"f26\",\"build_id\":\"464\",\"build_url\":\"https://jenkins-continuous-infra.apps.ci.centos
.org/job/continuous-infra-ci-pipeline-f26/464/\",\"compose_rev\":\"\",\"message-content\":\"\",\"namespace\":\"rpms\",\"nvr\":\"mesa-17.1.5-1.816.35fdde9.fc26.2.src\",\"original_spec_nvr\":\"mesa-17.1.5-1.fc26.2\",\"ref\":\"fedora/f26/x86
_64/atomic-host\",\"repo\":\"mesa\",\"rev\":\"35fdde92a0292def6a99acd3c237272789d020b2\",\"status\":\"SUCCESS\",\"test_guidance\":\"''\",\"topic\":\"org.centos.prod.ci.pipeline.package.complete\",\"username\":\"fedora-atomic\"}"
, 
  "msg": {
    "CI_TYPE": "custom", 
    "build_id": "464", 
    "original_spec_nvr": "mesa-17.1.5-1.fc26.2", 
    "username": "fedora-atomic", 
    "nvr": "mesa-17.1.5-1.816.35fdde9.fc26.2.src", 
    "rev": "35fdde92a0292def6a99acd3c237272789d020b2", 
    "message-content": "", 
    "build_url": "https://jenkins-continuous-infra.apps.ci.centos.org/job/continuous-infra-ci-pipeline-f26/464/", 
    "namespace": "rpms", 
    "CI_NAME": "continuous-infra-ci-pipeline-f26", 
    "repo": "mesa", 
    "compose_rev": "", 
    "topic": "org.centos.prod.ci.pipeline.package.complete", 
    "status": "SUCCESS", 
    "branch": "f26", 
    "test_guidance": "''", 
    "ref": "fedora/f26/x86_64/atomic-host"
  }
}
````

#### org.centos.prod.ci.pipeline.package.test.functional.queued

````
{
  "i": 1,
  "timestamp": 1501741048,
  "msg_id": "2017-b420134c-0e39-4f70-8e5f-0975d7019e4b",
  "crypto": "x509",
  "topic": "org.centos.prod.ci.pipeline.package.test.functional.queued",
  "msg": {
    "CI_TYPE": "custom",
    "build_id": "91",
    "username": "fedora-atomic",
    "rev": "591b0d2fc67a45e4ad13bdc3e312d5554852426a",
    "message-content": "",
    "build_url": "https://jenkins-continuous-infra.apps.ci.centos.org/job/ci-pipeline-f26/91/",
    "namespace": "rpms",
    "CI_NAME": "ci-pipeline-f26",
    "repo": "vim",
    "original_spec_nvr": "vim-7.4.160-1.fc26",
    "nvr": "vim-7.4.160-1.200.591b0d2.fc26",
    "topic": "org.centos.prod.ci.pipeline.package.test.functional.queued",
    "status": "SUCCESS",
    "test_guidance": "''",
    "branch": "f26",
    "package_url": "http://artifacts.ci.centos.org/fedora-atomic/f26/repo/vim_repo/",
    "ref": "fedora/f26/x86_64/atomic-host"
  }
}
````

#### org.centos.prod.ci.pipeline.package.test.functional.running

````
{
  "i": 1,
  "timestamp": 1501741048,
  "msg_id": "2017-b420134c-0e39-4f70-8e5f-0975d7019e4b",
  "crypto": "x509",
  "topic": "org.centos.prod.ci.pipeline.package.test.functional.running",
  "msg": {
    "CI_TYPE": "custom",
    "build_id": "91",
    "username": "fedora-atomic",
    "rev": "591b0d2fc67a45e4ad13bdc3e312d5554852426a",
    "message-content": "",
    "build_url": "https://jenkins-continuous-infra.apps.ci.centos.org/job/ci-pipeline-f26/91/",
    "namespace": "rpms",
    "CI_NAME": "ci-pipeline-f26",
    "repo": "vim",
    "original_spec_nvr": "vim-7.4.160-1.fc26",
    "nvr": "vim-7.4.160-1.200.591b0d2.fc26",
    "topic": "org.centos.prod.ci.pipeline.package.test.functional.running",
    "status": "SUCCESS",
    "test_guidance": "''",
    "branch": "f26",
    "package_url": "http://artifacts.ci.centos.org/fedora-atomic/f26/repo/vim_repo/",
    "ref": "fedora/f26/x86_64/atomic-host"
  }
}
````

#### org.centos.prod.ci.pipeline.package.test.functional.complete

````
{
  "i": 1,
  "timestamp": 1501741048,
  "msg_id": "2017-b420134c-0e39-4f70-8e5f-0975d7019e4b",
  "crypto": "x509",
  "topic": "org.centos.prod.ci.pipeline.package.test.functional.complete",
  "msg": {
    "CI_TYPE": "custom",
    "build_id": "91",
    "username": "fedora-atomic",
    "rev": "591b0d2fc67a45e4ad13bdc3e312d5554852426a",
    "message-content": "",
    "build_url": "https://jenkins-continuous-infra.apps.ci.centos.org/job/ci-pipeline-f26/91/",
    "namespace": "rpms",
    "CI_NAME": "ci-pipeline-f26",
    "repo": "vim",
    "original_spec_nvr": "vim-7.4.160-1.fc26",
    "nvr": "vim-7.4.160-1.200.591b0d2.fc26",
    "topic": "org.centos.prod.ci.pipeline.package.test.functional.complete",
    "status": "SUCCESS",
    "test_guidance": "''",
    "branch": "f26",
    "package_url": "http://artifacts.ci.centos.org/fedora-atomic/f26/repo/vim_repo/",
    "ref": "fedora/f26/x86_64/atomic-host"
  }
}
````

#### org.centos.prod.ci.pipeline.compose.running

````
{
  "i": 1, 
  "timestamp": 1507136315, 
  "msg_id": "2017-809b57f5-581d-4270-8cdb-c0ced8d37cc9", 
  "crypto": "x509", 
  "topic": "org.centos.prod.ci.pipeline.compose.running", 
  "msgJson": "{\"CI_NAME\":\"continuous-infra-ci-pipeline-f26\",\"CI_TYPE\":\"custom\",\"branch\":\"f26\",\"build_id\":\"464\",\"build_url\":\"https://jenkins-continuous-infra.apps.ci.centos
.org/job/continuous-infra-ci-pipeline-f26/464/\",\"compose_rev\":\"''\",\"compose_url\":\"http://artifacts.ci.centos.org/fedora-atomic/f26/ostree\",\"message-content\":\"\",\"namespace\":\"rpms\",\"nvr\":\"mesa-17.1.5-1.816.35fdde9.fc26.2
.src\",\"original_spec_nvr\":\"mesa-17.1.5-1.fc26.2\",\"ref\":\"fedora/f26/x86_64/atomic-host\",\"repo\":\"mesa\",\"rev\":\"35fdde92a0292def6a99acd3c237272789d020b2\",\"status\":\"SUCCESS\",\"test_guidance\":\"''\",\"topic\":\"org.centos.
prod.ci.pipeline.compose.running\",\"username\":\"fedora-atomic\"}", 
  "msg": {
    "CI_TYPE": "custom", 
    "build_id": "464", 
    "original_spec_nvr": "mesa-17.1.5-1.fc26.2", 
    "username": "fedora-atomic", 
    "compose_url": "http://artifacts.ci.centos.org/fedora-atomic/f26/ostree", 
    "rev": "35fdde92a0292def6a99acd3c237272789d020b2", 
    "message-content": "", 
    "build_url": "https://jenkins-continuous-infra.apps.ci.centos.org/job/continuous-infra-ci-pipeline-f26/464/", 
    "namespace": "rpms", 
    "CI_NAME": "continuous-infra-ci-pipeline-f26", 
    "repo": "mesa", 
    "compose_rev": "''", 
    "topic": "org.centos.prod.ci.pipeline.compose.running", 
    "status": "SUCCESS", 
    "branch": "f26", 
    "test_guidance": "''", 
    "ref": "fedora/f26/x86_64/atomic-host", 
    "nvr": "mesa-17.1.5-1.816.35fdde9.fc26.2.src"
  }
}
````

#### org.centos.prod.ci.pipeline.compose.complete

````
{
  "i": 1, 
  "timestamp": 1507136621, 
  "msg_id": "2017-6723f16f-93e1-4ec0-a38e-78f092a592ee", 
  "crypto": "x509", 
  "topic": "org.centos.prod.ci.pipeline.compose.complete", 
  "msgJson": "{\"CI_NAME\":\"continuous-infra-ci-pipeline-f26\",\"CI_TYPE\":\"custom\",\"branch\":\"f26\",\"build_id\":\"464\",\"build_url\":\"https://jenkins-continuous-infra.apps.ci.centos
.org/job/continuous-infra-ci-pipeline-f26/464/\",\"compose_rev\":\"9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04\",\"compose_url\":\"http://artifacts.ci.centos.org/fedora-atomic/f26/ostree\",\"message-content\":\"\",\"n
amespace\":\"rpms\",\"nvr\":\"mesa-17.1.5-1.816.35fdde9.fc26.2.src\",\"original_spec_nvr\":\"mesa-17.1.5-1.fc26.2\",\"ref\":\"fedora/f26/x86_64/atomic-host\",\"repo\":\"mesa\",\"rev\":\"35fdde92a0292def6a99acd3c237272789d020b2\",\"status\
":\"SUCCESS\",\"test_guidance\":\"''\",\"topic\":\"org.centos.prod.ci.pipeline.compose.complete\",\"username\":\"fedora-atomic\"}", 
  "msg": {
    "CI_TYPE": "custom", 
    "build_id": "464", 
    "original_spec_nvr": "mesa-17.1.5-1.fc26.2", 
    "username": "fedora-atomic", 
    "compose_url": "http://artifacts.ci.centos.org/fedora-atomic/f26/ostree", 
    "rev": "35fdde92a0292def6a99acd3c237272789d020b2", 
    "message-content": "", 
    "build_url": "https://jenkins-continuous-infra.apps.ci.centos.org/job/continuous-infra-ci-pipeline-f26/464/", 
    "namespace": "rpms", 
    "CI_NAME": "continuous-infra-ci-pipeline-f26", 
    "repo": "mesa", 
    "compose_rev": "9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04", 
    "topic": "org.centos.prod.ci.pipeline.compose.complete", 
    "status": "SUCCESS", 
    "branch": "f26", 
    "test_guidance": "''", 
    "ref": "fedora/f26/x86_64/atomic-host", 
    "nvr": "mesa-17.1.5-1.816.35fdde9.fc26.2.src"
  }
}
````

#### org.centos.prod.ci.pipeline.image.running

````
{
  "i": 1, 
  "timestamp": 1507136627, 
  "msg_id": "2017-9f9bde8a-0508-44cc-9ae3-a962e9228125", 
  "crypto": "x509", 
  "topic": "org.centos.prod.ci.pipeline.image.running", 
  "msgJson": "{\"CI_NAME\":\"continuous-infra-ci-pipeline-f26\",\"CI_TYPE\":\"custom\",\"branch\":\"f26\",\"build_id\":\"464\",\"build_url\":\"https://jenkins-continuous-infra.apps.ci.centos
.org/job/continuous-infra-ci-pipeline-f26/464/\",\"compose_rev\":\"9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04\",\"compose_url\":\"http://artifacts.ci.centos.org/fedora-atomic/f26/ostree\",\"image_name\":\"''\",\"imag
e_url\":\"''\",\"message-content\":\"\",\"namespace\":\"rpms\",\"nvr\":\"mesa-17.1.5-1.816.35fdde9.fc26.2.src\",\"original_spec_nvr\":\"mesa-17.1.5-1.fc26.2\",\"ref\":\"fedora/f26/x86_64/atomic-host\",\"repo\":\"mesa\",\"rev\":\"35fdde92a
0292def6a99acd3c237272789d020b2\",\"status\":\"SUCCESS\",\"test_guidance\":\"''\",\"topic\":\"org.centos.prod.ci.pipeline.image.running\",\"type\":\"qcow2\",\"username\":\"fedora-atomic\"}", 
  "msg": {
    "CI_TYPE": "custom", 
    "build_id": "464", 
    "original_spec_nvr": "mesa-17.1.5-1.fc26.2", 
    "username": "fedora-atomic", 
    "compose_url": "http://artifacts.ci.centos.org/fedora-atomic/f26/ostree", 
    "rev": "35fdde92a0292def6a99acd3c237272789d020b2", 
    "message-content": "", 
    "build_url": "https://jenkins-continuous-infra.apps.ci.centos.org/job/continuous-infra-ci-pipeline-f26/464/", 
    "namespace": "rpms", 
    "CI_NAME": "continuous-infra-ci-pipeline-f26", 
    "image_name": "''", 
    "repo": "mesa", 
    "compose_rev": "9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04", 
    "topic": "org.centos.prod.ci.pipeline.image.running", 
    "status": "SUCCESS", 
    "branch": "f26", 
    "type": "qcow2", 
    "test_guidance": "''", 
    "ref": "fedora/f26/x86_64/atomic-host", 
    "image_url": "''", 
    "nvr": "mesa-17.1.5-1.816.35fdde9.fc26.2.src"
  }
}
````

#### org.centos.prod.ci.pipeline.image.complete

````
{
  "i": 1, 
  "timestamp": 1507137242, 
  "msg_id": "2017-b6db02c4-2e0d-4535-bb3c-6c771cc1f20e", 
  "crypto": "x509", 
  "topic": "org.centos.prod.ci.pipeline.image.complete", 
  "msgJson": "{\"CI_NAME\":\"continuous-infra-ci-pipeline-f26\",\"CI_TYPE\":\"custom\",\"branch\":\"f26\",\"build_id\":\"464\",\"build_url\":\"https://jenkins-continuous-infra.apps.ci.centos
.org/job/continuous-infra-ci-pipeline-f26/464/\",\"compose_rev\":\"9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04\",\"compose_url\":\"http://artifacts.ci.centos.org/fedora-atomic/f26/ostree\",\"image_name\":\"fedora-atom
ic-26.391-9a4e37c459e67c7.qcow2\",\"image_url\":\"http://artifacts.ci.centos.org/fedora-atomic/f26/images/fedora-atomic-26.391-9a4e37c459e67c7.qcow2\",\"message-content\":\"\",\"namespace\":\"rpms\",\"nvr\":\"mesa-17.1.5-1.816.35fdde9.fc2
6.2.src\",\"original_spec_nvr\":\"mesa-17.1.5-1.fc26.2\",\"ref\":\"fedora/f26/x86_64/atomic-host\",\"repo\":\"mesa\",\"rev\":\"35fdde92a0292def6a99acd3c237272789d020b2\",\"status\":\"SUCCESS\",\"test_guidance\":\"''\",\"topic\":\"org.cent
os.prod.ci.pipeline.image.complete\",\"type\":\"qcow2\",\"username\":\"fedora-atomic\"}", 
  "msg": {
    "CI_TYPE": "custom", 
    "build_id": "464", 
    "original_spec_nvr": "mesa-17.1.5-1.fc26.2", 
    "username": "fedora-atomic", 
    "compose_url": "http://artifacts.ci.centos.org/fedora-atomic/f26/ostree", 
    "rev": "35fdde92a0292def6a99acd3c237272789d020b2", 
    "message-content": "", 
    "build_url": "https://jenkins-continuous-infra.apps.ci.centos.org/job/continuous-infra-ci-pipeline-f26/464/", 
    "namespace": "rpms", 
    "CI_NAME": "continuous-infra-ci-pipeline-f26", 
    "image_name": "fedora-atomic-26.391-9a4e37c459e67c7.qcow2", 
    "repo": "mesa", 
    "compose_rev": "9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04", 
    "topic": "org.centos.prod.ci.pipeline.image.complete", 
    "status": "SUCCESS", 
    "branch": "f26", 
    "type": "qcow2", 
    "test_guidance": "''", 
    "ref": "fedora/f26/x86_64/atomic-host", 
    "image_url": "http://artifacts.ci.centos.org/fedora-atomic/f26/images/fedora-atomic-26.391-9a4e37c459e67c7.qcow2", 
    "nvr": "mesa-17.1.5-1.816.35fdde9.fc26.2.src"
  }
}
````

#### org.centos.prod.ci.pipeline.image.test.smoke.running

````
{
  "i": 1, 
  "timestamp": 1507137248, 
  "msg_id": "2017-d27543a1-53bf-46f6-87c5-8b01258fc112", 
  "crypto": "x509", 
  "topic": "org.centos.prod.ci.pipeline.image.test.smoke.running", 
  "msgJson": "{\"CI_NAME\":\"continuous-infra-ci-pipeline-f26\",\"CI_TYPE\":\"custom\",\"branch\":\"f26\",\"build_id\":\"464\",\"build_url\":\"https://jenkins-continuous-infra.apps.ci.centos
.org/job/continuous-infra-ci-pipeline-f26/464/\",\"compose_rev\":\"9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04\",\"compose_url\":\"http://artifacts.ci.centos.org/fedora-atomic/f26/ostree\",\"image_name\":\"fedora-atom
ic-26.391-9a4e37c459e67c7.qcow2\",\"image_url\":\"http://artifacts.ci.centos.org/fedora-atomic/f26/images/fedora-atomic-26.391-9a4e37c459e67c7.qcow2\",\"message-content\":\"\",\"namespace\":\"rpms\",\"nvr\":\"mesa-17.1.5-1.816.35fdde9.fc2
6.2.src\",\"original_spec_nvr\":\"mesa-17.1.5-1.fc26.2\",\"ref\":\"fedora/f26/x86_64/atomic-host\",\"repo\":\"mesa\",\"rev\":\"35fdde92a0292def6a99acd3c237272789d020b2\",\"status\":\"SUCCESS\",\"test_guidance\":\"''\",\"topic\":\"org.cent
os.prod.ci.pipeline.image.test.smoke.running\",\"type\":\"qcow2\",\"username\":\"fedora-atomic\"}", 
  "msg": {
    "CI_TYPE": "custom", 
    "build_id": "464", 
    "original_spec_nvr": "mesa-17.1.5-1.fc26.2", 
    "username": "fedora-atomic", 
    "compose_url": "http://artifacts.ci.centos.org/fedora-atomic/f26/ostree", 
    "rev": "35fdde92a0292def6a99acd3c237272789d020b2", 
    "message-content": "", 
    "build_url": "https://jenkins-continuous-infra.apps.ci.centos.org/job/continuous-infra-ci-pipeline-f26/464/", 
    "namespace": "rpms", 
    "CI_NAME": "continuous-infra-ci-pipeline-f26", 
    "image_name": "fedora-atomic-26.391-9a4e37c459e67c7.qcow2", 
    "repo": "mesa", 
    "compose_rev": "9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04", 
    "topic": "org.centos.prod.ci.pipeline.image.test.smoke.running", 
    "status": "SUCCESS", 
    "branch": "f26", 
    "type": "qcow2", 
    "test_guidance": "''", 
    "ref": "fedora/f26/x86_64/atomic-host", 
    "image_url": "http://artifacts.ci.centos.org/fedora-atomic/f26/images/fedora-atomic-26.391-9a4e37c459e67c7.qcow2", 
    "nvr": "mesa-17.1.5-1.816.35fdde9.fc26.2.src"
  }
}
````

#### org.centos.prod.ci.pipeline.image.test.smoke.complete

````
{
  "i": 1, 
  "timestamp": 1507137602, 
  "msg_id": "2017-0772207c-3664-427e-8721-67bec95cd373", 
  "crypto": "x509", 
  "topic": "org.centos.prod.ci.pipeline.image.test.smoke.complete", 
  "msgJson": "{\"CI_NAME\":\"continuous-infra-ci-pipeline-f26\",\"CI_TYPE\":\"custom\",\"branch\":\"f26\",\"build_id\":\"464\",\"build_url\":\"https://jenkins-continuous-infra.apps.ci.centos
.org/job/continuous-infra-ci-pipeline-f26/464/\",\"compose_rev\":\"9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04\",\"compose_url\":\"http://artifacts.ci.centos.org/fedora-atomic/f26/ostree\",\"image_name\":\"fedora-atom
ic-26.391-9a4e37c459e67c7.qcow2\",\"image_url\":\"http://artifacts.ci.centos.org/fedora-atomic/f26/images/fedora-atomic-26.391-9a4e37c459e67c7.qcow2\",\"message-content\":\"\",\"namespace\":\"rpms\",\"nvr\":\"mesa-17.1.5-1.816.35fdde9.fc2
6.2.src\",\"original_spec_nvr\":\"mesa-17.1.5-1.fc26.2\",\"ref\":\"fedora/f26/x86_64/atomic-host\",\"repo\":\"mesa\",\"rev\":\"35fdde92a0292def6a99acd3c237272789d020b2\",\"status\":\"SUCCESS\",\"test_guidance\":\"''\",\"topic\":\"org.cent
os.prod.ci.pipeline.image.test.smoke.complete\",\"type\":\"qcow2\",\"username\":\"fedora-atomic\"}", 
  "msg": {
    "CI_TYPE": "custom", 
    "build_id": "464", 
    "original_spec_nvr": "mesa-17.1.5-1.fc26.2", 
    "username": "fedora-atomic", 
    "compose_url": "http://artifacts.ci.centos.org/fedora-atomic/f26/ostree", 
    "rev": "35fdde92a0292def6a99acd3c237272789d020b2", 
    "message-content": "", 
    "build_url": "https://jenkins-continuous-infra.apps.ci.centos.org/job/continuous-infra-ci-pipeline-f26/464/", 
    "namespace": "rpms", 
    "CI_NAME": "continuous-infra-ci-pipeline-f26", 
    "image_name": "fedora-atomic-26.391-9a4e37c459e67c7.qcow2", 
    "repo": "mesa", 
    "compose_rev": "9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04", 
    "topic": "org.centos.prod.ci.pipeline.image.test.smoke.complete", 
    "status": "SUCCESS", 
    "branch": "f26", 
    "type": "qcow2", 
    "test_guidance": "''", 
    "ref": "fedora/f26/x86_64/atomic-host", 
    "image_url": "http://artifacts.ci.centos.org/fedora-atomic/f26/images/fedora-atomic-26.391-9a4e37c459e67c7.qcow2", 
    "nvr": "mesa-17.1.5-1.816.35fdde9.fc26.2.src"
  }
}
````

#### org.centos.prod.ci.pipeline.compose.test.integration.queued

````
{
  "i": 1, 
  "timestamp": 1507138147, 
  "msg_id": "2017-4ef1db00-ef4b-4b3f-ac54-a79866f24d62", 
  "crypto": "x509", 
  "topic": "org.centos.prod.ci.pipeline.compose.test.integration.queued", 
  "msgJson": "{\"CI_NAME\":\"continuous-infra-ci-pipeline-f26\",\"CI_TYPE\":\"custom\",\"branch\":\"f26\",\"build_id\":\"464\",\"build_url\":\"https://jenkins-continuous-infra.apps.ci.centos
.org/job/continuous-infra-ci-pipeline-f26/464/\",\"compose_rev\":\"9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04\",\"compose_url\":\"http://artifacts.ci.centos.org/fedora-atomic/f26/ostree\",\"message-content\":\"\",\"n
amespace\":\"rpms\",\"nvr\":\"mesa-17.1.5-1.816.35fdde9.fc26.2.src\",\"original_spec_nvr\":\"mesa-17.1.5-1.fc26.2\",\"ref\":\"fedora/f26/x86_64/atomic-host\",\"repo\":\"mesa\",\"rev\":\"35fdde92a0292def6a99acd3c237272789d020b2\",\"status\
":\"SUCCESS\",\"test_guidance\":\"''\",\"topic\":\"org.centos.prod.ci.pipeline.compose.test.integration.queued\",\"username\":\"fedora-atomic\"}", 
  "msg": {
    "CI_TYPE": "custom", 
    "build_id": "464", 
    "original_spec_nvr": "mesa-17.1.5-1.fc26.2", 
    "username": "fedora-atomic", 
    "compose_url": "http://artifacts.ci.centos.org/fedora-atomic/f26/ostree", 
    "rev": "35fdde92a0292def6a99acd3c237272789d020b2", 
    "message-content": "", 
    "build_url": "https://jenkins-continuous-infra.apps.ci.centos.org/job/continuous-infra-ci-pipeline-f26/464/", 
    "namespace": "rpms", 
    "CI_NAME": "continuous-infra-ci-pipeline-f26", 
    "repo": "mesa", 
    "compose_rev": "9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04", 
    "topic": "org.centos.prod.ci.pipeline.compose.test.integration.queued", 
    "status": "SUCCESS", 
    "branch": "f26", 
    "test_guidance": "''", 
    "ref": "fedora/f26/x86_64/atomic-host", 
    "nvr": "mesa-17.1.5-1.816.35fdde9.fc26.2.src"
  }
}
````

#### org.centos.prod.ci.pipeline.compose.test.integration.running

````
{
  "i": 1, 
  "timestamp": 1507138153, 
  "msg_id": "2017-9a9781b9-3d17-438c-b22d-002d6e505428", 
  "crypto": "x509", 
  "topic": "org.centos.prod.ci.pipeline.compose.test.integration.running", 
  "msgJson": "{\"CI_NAME\":\"continuous-infra-ci-pipeline-f26\",\"CI_TYPE\":\"custom\",\"branch\":\"f26\",\"build_id\":\"464\",\"build_url\":\"https://jenkins-continuous-infra.apps.ci.centos
.org/job/continuous-infra-ci-pipeline-f26/464/\",\"compose_rev\":\"9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04\",\"compose_url\":\"http://artifacts.ci.centos.org/fedora-atomic/f26/ostree\",\"message-content\":\"\",\"n
amespace\":\"rpms\",\"nvr\":\"mesa-17.1.5-1.816.35fdde9.fc26.2.src\",\"original_spec_nvr\":\"mesa-17.1.5-1.fc26.2\",\"ref\":\"fedora/f26/x86_64/atomic-host\",\"repo\":\"mesa\",\"rev\":\"35fdde92a0292def6a99acd3c237272789d020b2\",\"status\
":\"SUCCESS\",\"test_guidance\":\"''\",\"topic\":\"org.centos.prod.ci.pipeline.compose.test.integration.running\",\"username\":\"fedora-atomic\"}", 
  "msg": {
    "CI_TYPE": "custom", 
    "build_id": "464", 
    "original_spec_nvr": "mesa-17.1.5-1.fc26.2", 
    "username": "fedora-atomic", 
    "compose_url": "http://artifacts.ci.centos.org/fedora-atomic/f26/ostree", 
    "rev": "35fdde92a0292def6a99acd3c237272789d020b2", 
    "message-content": "", 
    "build_url": "https://jenkins-continuous-infra.apps.ci.centos.org/job/continuous-infra-ci-pipeline-f26/464/", 
    "namespace": "rpms", 
    "CI_NAME": "continuous-infra-ci-pipeline-f26", 
    "repo": "mesa", 
    "compose_rev": "9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04", 
    "topic": "org.centos.prod.ci.pipeline.compose.test.integration.running", 
    "status": "SUCCESS", 
    "branch": "f26", 
    "test_guidance": "''", 
    "ref": "fedora/f26/x86_64/atomic-host", 
    "nvr": "mesa-17.1.5-1.816.35fdde9.fc26.2.src"
  }
}
````

#### org.centos.prod.ci.pipeline.compose.test.integration.complete

````
{
  "i": 1, 
  "timestamp": 1507138177, 
  "msg_id": "2017-d104ac21-0807-4fa8-b8db-8905d11aadfe", 
  "crypto": "x509", 
  "topic": "org.centos.prod.ci.pipeline.compose.test.integration.complete", 
  "msgJson": "{\"CI_NAME\":\"continuous-infra-ci-pipeline-f26\",\"CI_TYPE\":\"custom\",\"branch\":\"f26\",\"build_id\":\"464\",\"build_url\":\"https://jenkins-continuous-infra.apps.ci.centos
.org/job/continuous-infra-ci-pipeline-f26/464/\",\"compose_rev\":\"9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04\",\"compose_url\":\"http://artifacts.ci.centos.org/fedora-atomic/f26/ostree\",\"message-content\":\"\",\"n
amespace\":\"rpms\",\"nvr\":\"mesa-17.1.5-1.816.35fdde9.fc26.2.src\",\"original_spec_nvr\":\"mesa-17.1.5-1.fc26.2\",\"ref\":\"fedora/f26/x86_64/atomic-host\",\"repo\":\"mesa\",\"rev\":\"35fdde92a0292def6a99acd3c237272789d020b2\",\"status\
":\"SUCCESS\",\"test_guidance\":\"''\",\"topic\":\"org.centos.prod.ci.pipeline.compose.test.integration.complete\",\"username\":\"fedora-atomic\"}", 
  "msg": {
    "CI_TYPE": "custom", 
    "build_id": "464", 
    "original_spec_nvr": "mesa-17.1.5-1.fc26.2", 
    "username": "fedora-atomic", 
    "compose_url": "http://artifacts.ci.centos.org/fedora-atomic/f26/ostree", 
    "rev": "35fdde92a0292def6a99acd3c237272789d020b2", 
    "message-content": "", 
    "build_url": "https://jenkins-continuous-infra.apps.ci.centos.org/job/continuous-infra-ci-pipeline-f26/464/", 
    "namespace": "rpms", 
    "CI_NAME": "continuous-infra-ci-pipeline-f26", 
    "repo": "mesa", 
    "compose_rev": "9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04", 
    "topic": "org.centos.prod.ci.pipeline.compose.test.integration.complete", 
    "status": "SUCCESS", 
    "branch": "f26", 
    "test_guidance": "''", 
    "ref": "fedora/f26/x86_64/atomic-host", 
    "nvr": "mesa-17.1.5-1.816.35fdde9.fc26.2.src"
  }
}
````

#### org.centos.prod.ci.pipeline.complete

````
{
  "i": 1, 
  "timestamp": 1507138233, 
  "msg_id": "2017-203ce174-de23-4e62-9ddc-3522b59d62a1", 
  "crypto": "x509", 
  "topic": "org.centos.prod.ci.pipeline.complete", 
  "msgJson": "{\"CI_NAME\":\"continuous-infra-ci-pipeline-f26\",\"CI_TYPE\":\"custom\",\"branch\":\"f26\",\"build_id\":\"464\",\"build_url\":\"https://jenkins-continuous-infra.apps.ci.centos
.org/job/continuous-infra-ci-pipeline-f26/464/\",\"compose_rev\":\"9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04\",\"message-content\":\"\",\"namespace\":\"rpms\",\"nvr\":\"mesa-17.1.5-1.816.35fdde9.fc26.2.src\",\"origi
nal_spec_nvr\":\"mesa-17.1.5-1.fc26.2\",\"ref\":\"fedora/f26/x86_64/atomic-host\",\"repo\":\"mesa\",\"rev\":\"35fdde92a0292def6a99acd3c237272789d020b2\",\"status\":\"SUCCESS\",\"test_guidance\":\"''\",\"topic\":\"org.centos.prod.ci.pipeli
ne.complete\",\"username\":\"fedora-atomic\"}", 
  "msg": {
    "CI_TYPE": "custom", 
    "build_id": "464", 
    "original_spec_nvr": "mesa-17.1.5-1.fc26.2", 
    "username": "fedora-atomic", 
    "nvr": "mesa-17.1.5-1.816.35fdde9.fc26.2.src", 
    "rev": "35fdde92a0292def6a99acd3c237272789d020b2", 
    "message-content": "", 
    "build_url": "https://jenkins-continuous-infra.apps.ci.centos.org/job/continuous-infra-ci-pipeline-f26/464/", 
    "namespace": "rpms", 
    "CI_NAME": "continuous-infra-ci-pipeline-f26", 
    "repo": "mesa", 
    "compose_rev": "9a4e37c459e67c7187df4c571ddd0ad75969633d40bdfaa7c1d95bbff5fe1e04", 
    "topic": "org.centos.prod.ci.pipeline.complete", 
    "status": "SUCCESS", 
    "branch": "f26", 
    "test_guidance": "''", 
    "ref": "fedora/f26/x86_64/atomic-host"
  }
}
````
