env.ghprbGhRepository = env.ghprbGhRepository ?: 'CentOS-PaaS-SIG/ci-pipeline'
env.ghprbActualCommit = env.ghprbActualCommit ?: 'master'

// Needed for podTemplate()
env.SLAVE_TAG = env.SLAVE_TAG ?: 'stable'
env.RPMBUILD_TAG = env.RPMBUILD_TAG ?: 'stable'
env.DOCKER_REPO_URL = env.DOCKER_REPO_URL ?: '172.30.254.79:5000'
env.OPENSHIFT_NAMESPACE = env.OPENSHIFT_NAMESPACE ?: 'continuous-infra'

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
                                string(defaultValue: 'stable', description: 'Tag for slave image', name: 'SLAVE_TAG'),
                                string(defaultValue: 'stable', description: 'Tag for rpmbuild image', name: 'RPMBUILD_TAG'),
                                string(defaultValue: '172.30.254.79:5000', description: 'Docker repo url for Openshift instance', name: 'DOCKER_REPO_URL'),
                                string(defaultValue: 'continuous-infra', description: 'Project namespace for Openshift operations', name: 'OPENSHIFT_NAMESPACE'),
                                booleanParam(defaultValue: false, description: 'Force generation of the image', name: 'GENERATE_IMAGE'),
                        ]
                ),
        ]
)

podTemplate(name: 'fedora-atomic-' + env.ghprbActualCommit,
            label: 'fedora-atomic-' + env.ghprbActualCommit,
            cloud: 'openshift',
            serviceAccount: 'jenkins',
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
        ])
{
    node('fedora-atomic-' + env.ghprbActualCommit) {

        def currentStage = ""

        // Gather some info about the node we are running on for diagnostics
        //
        currentStage = "verify-pod"
        stage(currentStage) {
            pipelineUtils.verifyPod(OPENSHIFT_NAMESPACE, env.NODE_NAME)
        }

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
        ansiColor('xterm') {
            timestamps {
                try {
                    deleteDir()

                    // Set our default env variables
                    pipelineUtils.setDefaultEnvVars()

                    // Prepare Credentials (keys, passwords, etc)
                    pipelineUtils.prepareCredentials()

                    // Parse the CI_MESSAGE and inject it as env vars
                    pipelineUtils.injectFedmsgVars()

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
                        dir('cciskel') {
                            git 'https://github.com/cgwalters/centos-ci-skeleton'
                        }
                        dir('sig-atomic-buildscripts') {
                            git 'https://github.com/CentOS/sig-atomic-buildscripts'
                        }

                        // Set stage specific vars
                        pipelineUtils.setStageEnvVars(currentStage)

                        // Return a map (messageFields) of our message topic, properties, and content
                        messageFields = pipelineUtils.setMessageFields("package.running")

                        // Send message org.centos.prod.ci.pipeline.package.running on fedmsg
                        pipelineUtils.sendMessage(messageFields['properties'], messageFields['content'])

                        // Execute rpmbuild-test script in rpmbuild container
                        pipelineUtils.executeInContainer(currentStage, "rpmbuild", "/tmp/rpmbuild-test.sh")

                        def package_props = "${env.WORKSPACE}/" + currentStage + "/logs/package_props.txt"
                        def package_props_groovy = "${env.WORKSPACE}/package_props.groovy"
                        pipelineUtils.convertProps(package_props, package_props_groovy)
                        load(package_props_groovy)

                        // Set our message topic, properties, and content
                        messageFields = pipelineUtils.setMessageFields("package.complete")

                        // Send message org.centos.prod.ci.pipeline.package.complete on fedmsg
                        pipelineUtils.sendMessage(messageFields['properties'], messageFields['content'])
                    }

                    currentStage = "ci-pipeline-ostree-compose"
                    stage(currentStage) {
                        // Set stage specific vars
                        pipelineUtils.setStageEnvVars(currentStage)

                        //Set our message topic, properties, and content
                        messageFields = pipelineUtils.setMessageFields("compose.running")

                        // Send message org.centos.prod.ci.pipeline.compose.running on fedmsg
                        pipelineUtils.sendMessage(messageFields['properties'], messageFields['content'])

                        // Provision resources
                        pipelineUtils.provisionResources(currentStage)

                        // Stage resources - ostree compose
                        pipelineUtils.setupStage(currentStage, 'fedora-atomic-key')

                        // Rsync Data
                        pipelineUtils.rsyncData(currentStage)

                        def ostree_props = "${env.ORIGIN_WORKSPACE}/logs/ostree.props"
                        def ostree_props_groovy = "${env.ORIGIN_WORKSPACE}/ostree.props.groovy"
                        pipelineUtils.convertProps(ostree_props, ostree_props_groovy)
                        load(ostree_props_groovy)

                        // Teardown resource
                        pipelineUtils.teardownResources(currentStage)

                        // Set our message topic, properties, and content
                        messageFields = pipelineUtils.setMessageFields("package.complete")

                        // Send message org.centos.prod.ci.pipeline.package.complete on fedmsg
                        pipelineUtils.sendMessage(messageFields['properties'], messageFields['content'])

                        pipelineUtils.checkLastImage(currentStage)
                    }

                    currentStage = "ci-pipeline-ostree-image-compose"
                    stage(currentStage) {
                        // Check if a new ostree image compose is needed
                        if (fileExists("${env.WORKSPACE}/NeedNewImage.txt") || ("${env.GENERATE_IMAGE}" == "true")) {
                            // Set stage specific vars
                            pipelineUtils.setStageEnvVars(currentStage)

                            // Set our message topic, properties, and content
                            messageFields = pipelineUtils.setMessageFields("image.running")

                            // Send message org.centos.prod.ci.pipeline.image.running on fedmsg
                            pipelineUtils.sendMessage(messageFields['properties'], messageFields['content'])

                            // Provision resources
                            pipelineUtils.provisionResources(currentStage)

                            // Stage resources - ostree image compose
                            pipelineUtils.setupStage(currentStage, 'fedora-atomic-key')

                            // Rsync Data
                            pipelineUtils.rsyncData(currentStage)

                            ostree_props = "${env.ORIGIN_WORKSPACE}/logs/ostree.props"
                            ostree_props_groovy = "${env.ORIGIN_WORKSPACE}/ostree.props.groovy"
                            pipelineUtils.convertProps(ostree_props, ostree_props_groovy)
                            load(ostree_props_groovy)

                            // Teardown resources
                            pipelineUtils.teardownResources(currentStage)

                            // Set our message topic, properties, and content
                            messageFields = pipelineUtils.setMessageFields("image.complete")

                            // Send message org.centos.prod.ci.pipeline.image.complete on fedmsg
                            pipelineUtils.sendMessage(messageFields['properties'], messageFields['content'])

                        } else {
                            echo "Not Generating a New Image"
                        }
                    }

                    currentStage = "ci-pipeline-ostree-image-boot-sanity"
                    stage(currentStage) {
                        if (fileExists("${env.WORKSPACE}/NeedNewImage.txt") || ("${env.GENERATE_IMAGE}" == "true")) {
                            pipelineUtils.setStageEnvVars(currentStage)

                            // Set our message topic, properties, and content
                            messageFields = pipelineUtils.setMessageFields("smoke.running")

                            // Send message org.centos.prod.ci.pipeline.smoke.running on fedmsg
                            pipelineUtils.sendMessage(messageFields['properties'], messageFields['content'])

                            // Provision resources
                            pipelineUtils.provisionResources(currentStage)

                            // Stage resources - ostree image boot sanity
                            pipelineUtils.setupStage(currentStage, 'fedora-atomic-key')

                            // Rsync Data
                            pipelineUtils.rsyncData(currentStage)

                            // Teardown resources
                            pipelineUtils.teardownResources(currentStage)

                            // Set our message topic, properties, and content
                            messageFields = pipelineUtils.setMessageFields("smoke.complete")

                            // Send message org.centos.prod.ci.pipeline.smoke.complete on fedmsg
                            pipelineUtils.sendMessage(messageFields['properties'], messageFields['content'])

                        } else {
                            echo "Not Running Image Boot Sanity on Image"
                        }
                    }

                    currentStage = "ci-pipeline-ostree-boot-sanity"
                    stage(currentStage) {
                        pipelineUtils.setStageEnvVars(currentStage)

                        // Provision resources
                        pipelineUtils.provisionResources(currentStage)

                        // Stage resources - ostree boot sanity
                        pipelineUtils.setupStage(currentStage, 'fedora-atomic-key')

                        // Rsync Data
                        pipelineUtils.rsyncData(currentStage)

                        // Teardown resources
                        pipelineUtils.teardownResources(currentStage)

                        // Set our message topic, properties, and content
                        messageFields = pipelineUtils.setMessageFields("integration.queued")

                        // Send message org.centos.prod.ci.pipeline.integration.queued on fedmsg
                        pipelineUtils.sendMessage(messageFields['properties'], messageFields['content'])
                    }
                    currentStage = "ci-pipeline-atomic-host-tests"
                    stage(
                            currentStage) {
                        pipelineUtils.setStageEnvVars(currentStage)

                        // Set our message topic, properties, and content
                        messageFields = pipelineUtils.setMessageFields("integration.running")

                        // Send message org.centos.prod.ci.pipeline.integration.running on fedmsg
                        pipelineUtils.sendMessage(messageFields['properties'], messageFields['content'])

                        // Provision resources
                        pipelineUtils.provisionResources(currentStage)

                        // Stage resources - atomic host tests
                        pipelineUtils.setupStage(currentStage, 'fedora-atomic-key')

                        // Teardown resources
                        pipelineUtils.teardownResources(currentStage)

                        // Set our message topic, properties, and content
                        messageFields = pipelineUtils.setMessageFields("integration.complete")

                        // Send message org.centos.prod.ci.pipeline.integration.complete on fedmsg
                        pipelineUtils.sendMessage(messageFields['properties'], messageFields['content'])
                    }

                } catch (e) {
                    // Set build result
                    currentBuild.result = 'FAILURE'

                    // Report the exception
                    echo "Error: Exception from " + currentStage + ":"
                    echo e.getMessage()

                    // Teardown resources
                    pipelineUtils.teardownResources(currentStage)

                    // Throw the error
                    throw e

                } finally {
                    // Set the build display name and description
                    currentBuild.displayName = "Build#: ${env.BUILD_NUMBER} - Branch: ${env.branch} - Package: ${env.fed_repo}"
                    currentBuild.description = "${currentBuild.currentResult}"

                    //emailext subject: "${env.JOB_NAME} - Build # ${env.BUILD_NUMBER} - STATUS = ${currentBuild.currentResult}", to: "ari@redhat.com", body: "This pipeline was a ${currentBuild.currentResult}"

                    // Archive our artifacts
                    step([$class: 'ArtifactArchiver', allowEmptyArchive: true, artifacts: '**/logs/**,*.txt,*.groovy,**/job.*,**/*.groovy,**/inventory.*', excludes: '**/job.props,**/job.props.groovy,**/*.example', fingerprint: true])

                    // Set our message topic, properties, and content
                    messageFields = pipelineUtils.setMessageFields("complete")

                    // Send message org.centos.prod.ci.pipeline.complete on fedmsg
                    pipelineUtils.sendMessage(messageFields['properties'], messageFields['content'])

                }
            }
        }
    }
}
