env.ghprbGhRepository = env.ghprbGhRepository ?: 'CentOS-PaaS-SIG/ci-pipeline'
env.ghprbActualCommit = env.ghprbActualCommit ?: 'master'
env.ghprbPullAuthorLogin = env.ghprbPullAuthorLogin ?: ''

env.TARGET_BRANCH = env.TARGET_BRANCH ?: 'master'

// Needed for podTemplate()
env.SLAVE_TAG = env.SLAVE_TAG ?: 'stable'
env.RPMBUILD_TAG = env.RPMBUILD_TAG ?: 'stable'
env.RSYNC_TAG = env.RSYNC_TAG ?: 'stable'
env.OSTREE_COMPOSE_TAG = env.OSTREE_COMPOSE_TAG ?: 'stable'
env.OSTREE_IMAGE_COMPOSE_TAG = env.OSTREE_IMAGE_COMPOSE_TAG ?: 'stable'
env.SINGLEHOST_TEST_TAG = env.SINGLEHOST_TEST_TAG ?: 'stable'
env.OSTREE_BOOT_IMAGE_TAG = env.OSTREE_BOOT_IMAGE_TAG ?: 'stable'
env.LINCHPIN_LIBVIRT_TAG = env.LINCHPIN_LIBVIRT_TAG ?: 'stable'

env.DOCKER_REPO_URL = env.DOCKER_REPO_URL ?: '172.30.254.79:5000'
env.OPENSHIFT_NAMESPACE = env.OPENSHIFT_NAMESPACE ?: 'continuous-infra'
env.OPENSHIFT_SERVICE_ACCOUNT = env.OPENSHIFT_SERVICE_ACCOUNT ?: 'jenkins'

// Audit file for all messages sent.
msgAuditFile = "messages/message-audit.json"

// IRC properties
IRC_NICK = "contra-bot"
IRC_CHANNEL = "#contra-ci-cd"

// Number of times to keep retrying to make sure message is ingested
// by datagrepper
fedmsgRetryCount = 120

// Execution ID for this run of the pipeline
executionID = UUID.randomUUID().toString()

// Pod name to use
podName = 'fedora-atomic-' + executionID + '-' + TARGET_BRANCH

library identifier: "ci-pipeline@${env.ghprbActualCommit}",
        retriever: modernSCM([$class: 'GitSCMSource',
                              remote: "https://github.com/${env.ghprbGhRepository}",
                              traits: [[$class: 'jenkins.plugins.git.traits.BranchDiscoveryTrait'],
                                       [$class: 'RefSpecsSCMSourceTrait',
                                        templates: [[value: '+refs/heads/*:refs/remotes/@{remote}/*'],
                                                    [value: '+refs/pull/*:refs/remotes/origin/pr/*']]]]])
properties(
        [
                buildDiscarder(logRotator(artifactDaysToKeepStr: '30', artifactNumToKeepStr: '', daysToKeepStr: '90', numToKeepStr: '')),
                disableConcurrentBuilds(),
                parameters(
                        [
                                string(description: 'CI Message that triggered the pipeline', name: 'CI_MESSAGE'),
                                string(defaultValue: 'f26', description: 'Fedora target branch', name: 'TARGET_BRANCH'),
                                string(defaultValue: '', description: 'HTTP Server', name: 'HTTP_SERVER'),
                                string(defaultValue: '', description: 'HTTP dir', name: 'HTTP_DIR'),
                                string(defaultValue: '', description: 'RSync User', name: 'RSYNC_USER'),
                                string(defaultValue: '', description: 'RSync Server', name: 'RSYNC_SERVER'),
                                string(defaultValue: '', description: 'RSync Dir', name: 'RSYNC_DIR'),
                                string(defaultValue: 'ci-pipeline', description: 'Main project repo', name: 'PROJECT_REPO'),
                                string(defaultValue: '', description: 'Main topic to publish on', name: 'MAIN_TOPIC'),
                                string(defaultValue: 'fedora-fedmsg', description: 'Main provider to send messages on', name: 'MSG_PROVIDER'),
                                string(defaultValue: '', description: 'Principal for authenticating with fedora build system', name: 'FEDORA_PRINCIPAL'),
                                string(defaultValue: 'master', description: '', name: 'ghprbActualCommit'),
                                string(defaultValue: 'CentOS-PaaS-SIG/ci-pipeline', description: '', name: 'ghprbGhRepository'),
                                string(defaultValue: '', description: '', name: 'sha1'),
                                string(defaultValue: '', description: '', name: 'ghprbPullId'),
                                string(defaultValue: '', description: '', name: 'ghprbPullAuthorLogin'),
                                string(defaultValue: 'stable', description: 'Tag for slave image', name: 'SLAVE_TAG'),
                                string(defaultValue: 'stable', description: 'Tag for ostree boot image', name: 'OSTREE_BOOT_IMAGE_TAG'),
                                string(defaultValue: 'stable', description: 'Tag for rpmbuild image', name: 'RPMBUILD_TAG'),
                                string(defaultValue: 'stable', description: 'Tag for rsync image', name: 'RSYNC_TAG'),
                                string(defaultValue: 'stable', description: 'Tag for ostree-compose image', name: 'OSTREE_COMPOSE_TAG'),
                                string(defaultValue: 'stable', description: 'Tag for ostree-image-compose image', name: 'OSTREE_IMAGE_COMPOSE_TAG'),
                                string(defaultValue: 'stable', description: 'Tag for singlehost test image', name: 'SINGLEHOST_TEST_TAG'),
                                string(defaultValue: '172.30.254.79:5000', description: 'Docker repo url for Openshift instance', name: 'DOCKER_REPO_URL'),
                                string(defaultValue: 'continuous-infra', description: 'Project namespace for Openshift operations', name: 'OPENSHIFT_NAMESPACE'),
                                string(defaultValue: 'jenkins', description: 'Service Account for Openshift operations', name: 'OPENSHIFT_SERVICE_ACCOUNT'),
                                booleanParam(defaultValue: false, description: 'Force generation of the image', name: 'GENERATE_IMAGE'),
                        ]
                ),
        ]
)

podTemplate(name: podName,
            label: podName,
            cloud: 'openshift',
            serviceAccount: OPENSHIFT_SERVICE_ACCOUNT,
            idleMinutes: 0,
            namespace: OPENSHIFT_NAMESPACE,

        containers: [
                // This adds the custom slave container to the pod. Must be first with name 'jnlp'
                containerTemplate(name: 'jnlp',
                        image: DOCKER_REPO_URL + '/' + OPENSHIFT_NAMESPACE + '/jenkins-continuous-infra-slave:' + SLAVE_TAG,
                        ttyEnabled: false,
                        args: '${computer.jnlpmac} ${computer.name}',
                        command: '',
                        workingDir: '/workDir'),
                // This adds the rpmbuild test container to the pod.
                containerTemplate(name: 'rpmbuild',
                        alwaysPullImage: true,
                        image: DOCKER_REPO_URL + '/' + OPENSHIFT_NAMESPACE + '/rpmbuild:' + RPMBUILD_TAG,
                        ttyEnabled: true,
                        command: 'cat',
                        privileged: true,
                        workingDir: '/workDir'),
                // This adds the rsync test container to the pod.
                containerTemplate(name: 'rsync',
                        alwaysPullImage: true,
                        image: DOCKER_REPO_URL + '/' + OPENSHIFT_NAMESPACE + '/rsync:' + RSYNC_TAG,
                        ttyEnabled: true,
                        command: 'cat',
                        privileged: true,
                        workingDir: '/workDir'),
                // This adds the ostree-compose test container to the pod.
                containerTemplate(name: 'ostree-compose',
                        alwaysPullImage: true,
                        image: DOCKER_REPO_URL + '/' + OPENSHIFT_NAMESPACE + '/ostree-compose:' + OSTREE_COMPOSE_TAG,
                        ttyEnabled: true,
                        command: 'cat',
                        privileged: true,
                        workingDir: '/workDir'),
                // This adds the ostree-image-compose test container to the pod.
                containerTemplate(name: 'ostree-image-compose',
                        alwaysPullImage: true,
                        image: DOCKER_REPO_URL + '/' + OPENSHIFT_NAMESPACE + '/ostree-image-compose:' + OSTREE_IMAGE_COMPOSE_TAG,
                        ttyEnabled: true,
                        command: 'cat',
                        privileged: true,
                        workingDir: '/workDir'),
                // This adds the singlehost test container to the pod.
                containerTemplate(name: 'singlehost-test',
                        alwaysPullImage: true,
                        image: DOCKER_REPO_URL + '/' + OPENSHIFT_NAMESPACE + '/singlehost-test:' + SINGLEHOST_TEST_TAG,
                        ttyEnabled: true,
                        command: 'cat',
                        privileged: true,
                        workingDir: '/workDir'),
                // This adds the ostree boot image container to the pod.
                containerTemplate(name: 'ostree-boot-image',
                        alwaysPullImage: true,
                        image: DOCKER_REPO_URL + '/' + OPENSHIFT_NAMESPACE + '/ostree-boot-image:' + OSTREE_BOOT_IMAGE_TAG,
                        ttyEnabled: true,
                        command: '/usr/sbin/init',
                        privileged: true,
                        workingDir: '/workDir'),
                containerTemplate(name: 'linchpin-libvirt',
                        alwaysPullImage: true,
                        image: DOCKER_REPO_URL + '/' + OPENSHIFT_NAMESPACE + '/linchpin-libvirt:' + LINCHPIN_LIBVIRT_TAG,
                        ttyEnabled: true,
                        command: '/usr/sbin/init',
                        privileged: true,
                        workingDir: '/workDir')
        ],
        volumes: [emptyDirVolume(memory: false, mountPath: '/sys/class/net')])
{
    node(podName) {

        def currentStage = ""

        ansiColor('xterm') {
            timestamps {
                // We need to set env.HOME because the openshift slave image
                // forces this to /home/jenkins and then ~ expands to that
                // even though id == "root"
                // See https://github.com/openshift/jenkins/blob/master/slave-base/Dockerfile#L5
                //
                // Even the kubernetes plugin will create a pod with containers
                // whose $HOME env var will be its workingDir
                // See https://github.com/jenkinsci/kubernetes-plugin/blob/master/src/main/java/org/csanchez/jenkins/plugins/kubernetes/KubernetesLauncher.java#L311
                //
                env.HOME = "/root"
                //
                try {
                    // Prepare our environment
                    currentStage = "prepare-environment"
                    stage(currentStage) {
                        deleteDir()
                        // Set our default env variables
                        pipelineUtils.setDefaultEnvVars()
                        // Prepare Credentials (keys, passwords, etc)
                        pipelineUtils.prepareCredentials()
                        // Parse the CI_MESSAGE and inject it as env vars
                        pipelineUtils.injectFedmsgVars(env.CI_MESSAGE)
                        // Set RSYNC_BRANCH for rsync'ing to artifacts store
                        env.RSYNC_BRANCH = pipelineUtils.getRsyncBranch()
                        // Decorate our build
                        pipelineUtils.updateBuildDisplayAndDescription()
                        // Gather some info about the node we are running on for diagnostics
                        pipelineUtils.verifyPod(OPENSHIFT_NAMESPACE, env.NODE_NAME)
                        // create audit message file
                        pipelineUtils.initializeAuditFile(msgAuditFile)
                    }

                    currentStage = "openshift-e2e-tests"
                    stage(currentStage) {
                        // run linchpin up and other steps
                        // note: need to be updated

                        // Set stage specific vars
                        pipelineUtils.setStageEnvVars(currentStage)

                        // run linchpin workspace for e2e tests
                        //pipelineUtils.executeInContainer(currentStage, "linchpin-libvirt", "/root/linchpin_workspace/run_e2e_tests.sh")
                        //pipelineUtils.executeInContainer(currentStage, "linchpin-libvirt", "date")
                    }

                } catch (e) {
                    // Set build result
                    currentBuild.result = 'FAILURE'

                    // Report the exception
                    echo "Error: Exception from " + currentStage + ":"
                    echo e.getMessage()

                    // Throw the error
                    throw e

                } finally {
                    // Set the build display name and description
                    pipelineUtils.setBuildDisplayAndDescription()

                    // only post to IRC on a failure
                    if (currentBuild.result == 'FAILURE') {
                        // only if this is a production build
                        if (env.ghprbActualCommit == null || env.ghprbActualCommit == "master") {
                            def message = "${JOB_NAME} build #${BUILD_NUMBER}: ${currentBuild.currentResult}: ${BUILD_URL}"
                            pipelineUtils.sendIRCNotification("${IRC_NICK}-${UUID.randomUUID()}", IRC_CHANNEL, message)
                        }
                    }

                    try {
                        //pipelineUtils.getContainerLogsFromPod(OPENSHIFT_NAMESPACE, env.NODE_NAME)
                    } catch (e) {
                        // Report the exception
                        echo "Warning: Could not get containerLogsFromPod: "
                        echo e.getMessage()
                    }

                    // Archive our artifacts
                    step([$class: 'ArtifactArchiver', allowEmptyArchive: true, artifacts: '**/logs/**,*.txt,*.groovy,**/job.*,**/*.groovy,**/inventory.*', excludes: '**/job.props,**/job.props.groovy,**/*.example', fingerprint: true])

                    // Set our message topic, properties, and content
                    messageFields = pipelineUtils.setMessageFields("complete")

                    // Send message org.centos.prod.ci.pipeline.complete on fedmsg
                    pipelineUtils.sendMessageWithAudit(messageFields['properties'], messageFields['content'], msgAuditFile, fedmsgRetryCount)

                }
            }
        }
    }
}
