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
                                string(defaultValue: 'stable', description: 'Tag for linchpin-libvirt image', name: 'LINCHPIN_LIBVIRT_TAG'),
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

                    // Set our current stage value
                    currentStage = "ci-pipeline-rpmbuild"
                    stage(currentStage) {

                        // SCM
                        dir('ci-pipeline') {
                            // Checkout our ci-pipeline repo based on the value of env.ghprbActualCommit
                            checkout([$class: 'GitSCM', branches: [[name: env.ghprbActualCommit]],
                                      doGenerateSubmoduleConfigurations: false,
                                      extensions                       : [],
                                      submoduleCfg                     : [],
                                      userRemoteConfigs                : [
                                              [refspec:
                                                       '+refs/heads/*:refs/remotes/origin/*  +refs/pull/*:refs/remotes/origin/pr/* ',
                                               url: "https://github.com/${env.ghprbGhRepository}"]
                                      ]
                            ])
                        }

                        // Set stage specific vars
                        pipelineUtils.setStageEnvVars(currentStage)

                        // Return a map (messageFields) of our message topic, properties, and content
                        messageFields = pipelineUtils.setMessageFields("package.running")

                        // Send message org.centos.prod.ci.pipeline.package.running on fedmsg
                        pipelineUtils.sendMessageWithAudit(messageFields['topic'], messageFields['properties'], messageFields['content'], msgAuditFile, fedmsgRetryCount)

                        // Execute rpmbuild-test script in rpmbuild container
                        pipelineUtils.executeInContainer(currentStage, "rpmbuild", "/tmp/rpmbuild-test.sh")

                        def package_props = "${env.WORKSPACE}/" + currentStage + "/logs/package_props.txt"
                        def package_props_groovy = "${env.WORKSPACE}/package_props.groovy"
                        pipelineUtils.convertProps(package_props, package_props_groovy)
                        load(package_props_groovy)

                        // Set our message topic, properties, and content
                        messageFields = pipelineUtils.setMessageFields("package.complete")

                        // Send message org.centos.prod.ci.pipeline.package.complete on fedmsg
                        pipelineUtils.sendMessageWithAudit(messageFields['topic'], messageFields['properties'], messageFields['content'], msgAuditFile, fedmsgRetryCount)
                    }

                    currentStage = "ci-pipeline-ostree-compose"
                    stage(currentStage) {
                        // Set stage specific vars
                        pipelineUtils.setStageEnvVars(currentStage)

                        //Set our message topic, properties, and content
                        messageFields = pipelineUtils.setMessageFields("compose.running")

                        // Send message org.centos.prod.ci.pipeline.compose.running on fedmsg
                        pipelineUtils.sendMessageWithAudit(messageFields['topic'], messageFields['properties'], messageFields['content'], msgAuditFile, fedmsgRetryCount)

                        // Get previous ostree artifacts
                        env.rsync_paths = "ostree"
                        env.rsync_from = "${env.RSYNC_USER}@${env.RSYNC_SERVER}::${env.RSYNC_DIR}/${env.RSYNC_BRANCH}/"
                        env.rsync_to = "${env.WORKSPACE}/"
                        pipelineUtils.executeInContainer(currentStage + "-rsync-before", "rsync", "/tmp/rsync.sh")

                        // Compose new ostree
                        pipelineUtils.executeInContainer(currentStage, "ostree-compose", "/tmp/ostree-compose.sh")

                        // Push new ostree compose to artifacts server
                        env.rsync_to = "${env.RSYNC_USER}@${env.RSYNC_SERVER}::${env.RSYNC_DIR}/${env.RSYNC_BRANCH}/"
                        env.rsync_from = "${env.WORKSPACE}/"
                        pipelineUtils.executeInContainer(currentStage + "-rsync-after", "rsync", "/tmp/rsync.sh")

                        // Load ostree properties as variables
                        def ostree_props = "${env.WORKSPACE}/" + currentStage + "/logs/ostree.props"
                        def ostree_props_groovy = "${env.WORKSPACE}/ostree.props.groovy"
                        pipelineUtils.convertProps(ostree_props, ostree_props_groovy)
                        load(ostree_props_groovy)

                        // Rsync push logs
                        env.rsync_paths = "."
                        env.rsync_from = "${env.WORKSPACE}/" + currentStage + "/logs/"
                        env.rsync_to = "${env.RSYNC_USER}@${env.RSYNC_SERVER}::${env.RSYNC_DIR}/${env.RSYNC_BRANCH}/images/${env.imgname}/" + currentStage + "/"
                        pipelineUtils.executeInContainer(currentStage + "-rsync-logs", "rsync", "/tmp/rsync.sh")

                        // Set our message topic, properties, and content
                        messageFields = pipelineUtils.setMessageFields("compose.complete")

                        // Send message org.centos.prod.ci.pipeline.compose.complete on fedmsg
                        pipelineUtils.sendMessageWithAudit(messageFields['topic'], messageFields['properties'], messageFields['content'], msgAuditFile, fedmsgRetryCount)

                        pipelineUtils.checkLastImage(currentStage)
                    }

                    currentStage = "ci-pipeline-ostree-image-compose"
                    stage(currentStage) {
                        // Set stage specific vars
                        pipelineUtils.setStageEnvVars(currentStage)
                        // We always run, but don't always push to artifacts
                        env.PUSH_IMAGE = "false"

                        // Check if a new ostree image compose is needed
                        if (fileExists("${env.WORKSPACE}/NeedNewImage.txt") || ("${env.GENERATE_IMAGE}" == "true")) {
                            // We will push a new qcow2 to artifacts
                            env.PUSH_IMAGE = "true"

                            // Set our message topic, properties, and content
                            messageFields = pipelineUtils.setMessageFields("image.running")

                            // Send message org.centos.prod.ci.pipeline.image.running on fedmsg
                            pipelineUtils.sendMessageWithAudit(messageFields['topic'], messageFields['properties'], messageFields['content'], msgAuditFile, fedmsgRetryCount)
                        }

                        // Rsync pull from artifacts
                        env.rsync_paths = "netinst ostree images"
                        env.rsync_from = "${env.RSYNC_USER}@${env.RSYNC_SERVER}::${env.RSYNC_DIR}/${env.RSYNC_BRANCH}/"
                        env.rsync_to = "${env.WORKSPACE}/"
                        pipelineUtils.executeInContainer(currentStage + "-rsync-before", "rsync", "/tmp/rsync.sh")

                        // Compose image
                        pipelineUtils.executeInContainer(currentStage, "ostree-image-compose", "/tmp/ostree-image-compose.sh")

                        // Rsync push netinst
                        env.rsync_paths = "netinst"
                        env.rsync_from = "${env.WORKSPACE}/"
                        env.rsync_to = "${env.RSYNC_USER}@${env.RSYNC_SERVER}::${env.RSYNC_DIR}/${env.RSYNC_BRANCH}/"
                        pipelineUtils.executeInContainer(currentStage + "-rsync-push-netinst", "rsync", "/tmp/rsync.sh")

                        String untested_img_loc = "${env.WORKSPACE}/images/untested-atomic.qcow2"
                        sh "cp -f ${untested_img_loc} ${env.WORKSPACE}/"
                        if (fileExists("${env.WORKSPACE}/NeedNewImage.txt") || ("${env.GENERATE_IMAGE}" == "true")) {
                            // Rsync push images
                            env.rsync_paths = "images"
                            pipelineUtils.executeInContainer(currentStage + "-rsync-after-netinst", "rsync", "/tmp/rsync.sh")

                            // These variables will mess with boot sanity jobs
                            // later if they are injected from a non pushed img
                            def ostree_props = "${env.WORKSPACE}/" + currentStage + "/logs/ostree.props"
                            def ostree_props_groovy = "${env.WORKSPACE}/ostree.props.groovy"
                            pipelineUtils.convertProps(ostree_props, ostree_props_groovy)
                            load(ostree_props_groovy)

                            // Set our message topic, properties, and content
                            messageFields = pipelineUtils.setMessageFields("image.complete")

                            // Send message org.centos.prod.ci.pipeline.image.complete on fedmsg
                            pipelineUtils.sendMessageWithAudit(messageFields['topic'], messageFields['properties'], messageFields['content'], msgAuditFile, fedmsgRetryCount)

                        } else {
                            echo "Not Pushing a New Image"
                        }
                        // Rsync push logs
                        env.rsync_paths = "."
                        env.rsync_from = "${env.WORKSPACE}/" + currentStage + "/logs/"
                        env.rsync_to = "${env.RSYNC_USER}@${env.RSYNC_SERVER}::${env.RSYNC_DIR}/${env.RSYNC_BRANCH}/images/${env.imgname}/" + currentStage + "/"
                        pipelineUtils.executeInContainer(currentStage + "-rsync-logs", "rsync", "/tmp/rsync.sh")
                    }

                    currentStage = "ci-pipeline-ostree-image-boot-sanity"
                    stage(currentStage) {
                        if (fileExists("${env.WORKSPACE}/NeedNewImage.txt") || ("${env.GENERATE_IMAGE}" == "true")) {
                            pipelineUtils.setStageEnvVars(currentStage)

                            // Set our message topic, properties, and content
                            messageFields = pipelineUtils.setMessageFields("image.test.smoke.running")

                            // Send message org.centos.prod.ci.pipeline.image.test.smoke.running on fedmsg
                            pipelineUtils.sendMessageWithAudit(messageFields['topic'], messageFields['properties'], messageFields['content'], msgAuditFile, fedmsgRetryCount)

                            // Rsync pull images dir from artifacts
                            env.rsync_paths = "images"
                            env.rsync_from = "${env.RSYNC_USER}@${env.RSYNC_SERVER}::${env.RSYNC_DIR}/${env.RSYNC_BRANCH}/"
                            env.rsync_to = "${env.WORKSPACE}/"
                            pipelineUtils.executeInContainer(currentStage + "-rsync-before", "rsync", "/tmp/rsync.sh")

                            // Run boot sanity on image
                            pipelineUtils.executeInContainer(currentStage, "ostree-boot-image", "/home/ostree-boot-image.sh")

                            // If boot sanity passes, we update images dir on artifacts
                            env.rsync_to = "${env.RSYNC_USER}@${env.RSYNC_SERVER}::${env.RSYNC_DIR}/${env.RSYNC_BRANCH}/"
                            env.rsync_from = "${env.WORKSPACE}/"
                            pipelineUtils.executeInContainer(currentStage + "-rsync-after", "rsync", "/tmp/rsync.sh")

                            // Set our message topic, properties, and content
                            messageFields = pipelineUtils.setMessageFields("image.test.smoke.complete")

                            // Send message org.centos.prod.ci.pipeline.image.test.smoke.complete on fedmsg
                            pipelineUtils.sendMessageWithAudit(messageFields['topic'], messageFields['properties'], messageFields['content'], msgAuditFile, fedmsgRetryCount)

                        } else {
                            echo "Not Running Image Boot Sanity on Image"
                        }

                    }

                    currentStage = "ci-pipeline-ostree-boot-sanity"
                    stage(currentStage) {
                        pipelineUtils.setStageEnvVars(currentStage)

                        // Run ostree boot sanity
                        pipelineUtils.executeInContainer(currentStage, "ostree-boot-image", "/home/ostree-boot-image.sh")

                    }

                    // Only run this stage if tests exist
                    if (pipelineUtils.checkTests(env.fed_repo, env.fed_branch, 'atomic')) {
                        // Set our message topic, properties, and content
                        messageFields = pipelineUtils.setMessageFields("package.test.functional.queued")

                        // Send message org.centos.prod.ci.pipeline.package.test.functional.queued on fedmsg
                        pipelineUtils.sendMessageWithAudit(messageFields['topic'], messageFields['properties'], messageFields['content'], msgAuditFile, fedmsgRetryCount)

                        currentStage = "ci-pipeline-functional-tests"
                        stage(currentStage) {
                            // Set stage specific vars
                            pipelineUtils.setStageEnvVars(currentStage)

                            //Set our message topic, properties, and content
                            messageFields = pipelineUtils.setMessageFields("package.test.functional.running")

                            // Send message org.centos.prod.ci.pipeline.package.test.functional.running on fedmsg
                            pipelineUtils.sendMessage(messageFields['topic'], messageFields['properties'], messageFields['content'])

                            // Run functional tests
                            pipelineUtils.executeInContainer(currentStage, "singlehost-test", "/tmp/package-test.sh")

                            // Set our message topic, properties, and content
                            messageFields = pipelineUtils.setMessageFields("package.test.functional.complete")

                            // Send message org.centos.prod.ci.pipeline.package.test.functional.complete on fedmsg
                            pipelineUtils.sendMessage(messageFields['topic'], messageFields['properties'], messageFields['content'])

                        }
                    }
                    // Set our message topic, properties, and content
                    messageFields = pipelineUtils.setMessageFields("compose.test.integration.queued")

                    // Send message org.centos.prod.ci.pipeline.compose.test.integration.queued on fedmsg
                    pipelineUtils.sendMessageWithAudit(messageFields['topic'], messageFields['properties'], messageFields['content'], msgAuditFile, fedmsgRetryCount)

                    currentStage = "ci-pipeline-atomic-host-tests"
                    stage(currentStage) {
                        // Set stage specific vars
                        pipelineUtils.setStageEnvVars(currentStage)

                        // Set our message topic, properties, and content
                        messageFields = pipelineUtils.setMessageFields("compose.test.integration.running")

                        // Send message org.centos.prod.ci.pipeline.compose.test.integration.running on fedmsg
                        pipelineUtils.sendMessageWithAudit(messageFields['topic'], messageFields['properties'], messageFields['content'], msgAuditFile, fedmsgRetryCount)

                        // Run integration tests
                        pipelineUtils.executeInContainer(currentStage, "singlehost-test", "/tmp/integration-test.sh")

                        // Set our message topic, properties, and content
                        messageFields = pipelineUtils.setMessageFields("compose.test.integration.complete")

                        // Send message org.centos.prod.ci.pipeline.compose.test.integration.complete on fedmsg
                        pipelineUtils.sendMessageWithAudit(messageFields['topic'], messageFields['properties'], messageFields['content'], msgAuditFile, fedmsgRetryCount)

                    }
                    currentStage = "openshift-e2e-tests"
                    stage(currentStage) {
                        // run linchpin up and other steps
                        // note: need to be updated

                        // Set stage specific vars
                        pipelineUtils.setStageEnvVars(currentStage)

                        // run linchpin workspace for e2e tests
                        pipelineUtils.executeInContainer(currentStage, "linchpin-libvirt", "/root/linchpin_workspace/run_e2e_tests.sh")
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
                        pipelineUtils.getContainerLogsFromPod(OPENSHIFT_NAMESPACE, env.NODE_NAME)
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
                    pipelineUtils.sendMessageWithAudit(messageFields['topic'], messageFields['properties'], messageFields['content'], msgAuditFile, fedmsgRetryCount)

                }
            }
        }
    }
}
