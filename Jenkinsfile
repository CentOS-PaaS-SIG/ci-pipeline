properties(
        [
                buildDiscarder(logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '25', daysToKeepStr: '', numToKeepStr: '50')),
                disableConcurrentBuilds(),
                parameters(
                        [
                                string(description: 'CI Message that triggered the pipeline', name: 'CI_MESSAGE'),
                                string(defaultValue: 'f26', description: 'Fedora target branch', name: 'TARGET_BRANCH'),
                                string(defaultValue: 'http://artifacts.ci.centos.org/artifacts/fedora-atomic', description: 'URL for rsync content', name: 'HTTP_BASE'),
                                string(defaultValue: 'fedora-atomic', description: 'RSync User', name: 'RSYNC_USER'),
                                string(defaultValue: 'artifacts.ci.centos.org', description: 'RSync Server', name: 'RSYNC_SERVER'),
                                string(defaultValue: 'fedora-atomic', description: 'RSync Dir', name: 'RSYNC_DIR'),
                                string(defaultValue: 'ci-pipeline', description: 'Main project repo', name: 'PROJECT_REPO'),
                                string(defaultValue: 'org.centos.stage', description: 'Main topic to publish on', name: 'MAIN_TOPIC'),
                                string(defaultValue: 'fedora-fedmsg', description: 'Main provider to send messages on', name: 'MSG_PROVIDER'),
                                string(defaultValue: 'bpeck/jenkins-continuous-infra.apps.ci.centos.org@FEDORAPROJECT.ORG', description: 'Principal for authenticating with fedora build system', name: 'FEDORA_PRINCIPAL'),
                                booleanParam(defaultValue: false, description: 'Force generation of the image', name: 'GENERATE_IMAGE'),
                        ]
                ),
        ]
)

podTemplate(name: 'fedora-atomic-inline', label: 'fedora-atomic-inline', cloud: 'openshift', serviceAccount: 'jenkins',
        idleMinutes: 1,  namespace: 'continuous-infra',
        containers: [
                // This adds the custom slave container to the pod. Must be first with name 'jnlp'
                containerTemplate(name: 'jnlp',
                        image: '172.30.254.79:5000/continuous-infra/jenkins-continuous-infra-slave',
                        ttyEnabled: false,
                        args: '${computer.jnlpmac} ${computer.name}',
                        command: '',
                        workingDir: '/tmp'),
        ])

{

    node('fedora-atomic-inline') {
        ansiColor('xterm') {
            timestamps {
                def current_stage = ""
                try {
                    deleteDir()
                    current_stage = "ci-pipeline-rpmbuild"
                    stage(current_stage) {
                        env.MAIN_TOPIC = env.MAIN_TOPIC ?: 'org.centos.prod'
                        env.MSG_PROVIDER = env.MSG_PROVIDER ?: 'fedora-fedmsg'
                        env.HTTP_BASE = env.HTTP_BASE ?: 'http://artifacts.ci.centos.org/artifacts/fedora-atomic'
                        env.RSYNC_USER = env.RSYNC_USER ?: 'fedora-atomic'
                        env.RSYNC_SERVER = env.RSYNC_SERVER ?: 'artifacts.ci.centos.org'
                        env.RSYNC_DIR = env.RSYNC_DIR ?: 'fedora-atomic'
                        env.basearch = env.basearch ?: 'x86_64'
                        env.OSTREE_BRANCH = env.OSTREE_BRANCH ?: ''
                        env.commit = env.commit ?: ''
                        env.image2boot = env.image2boot ?: ''
                        env.image_name = env.image_name ?: ''
                        env.FEDORA_PRINCIPAL = env.FEDORA_PRINCIPAL ?: 'bpeck/jenkins-continuous-infra.apps.ci.centos.org@FEDORAPROJECT.ORG'

                        // SCM
                        dir('ci-pipeline') {
                            git 'https://github.com/CentOS-PaaS-SIG/ci-pipeline'
                        }
                        dir('cciskel') {
                            git 'https://github.com/cgwalters/centos-ci-skeleton'
                        }
                        dir('sig-atomic-buildscripts') {
                            git 'https://github.com/CentOS/sig-atomic-buildscripts'
                        }

                        // Python script to parse the ${CI_MESSAGE}
                        writeFile file: "${env.WORKSPACE}/parse_fedmsg.py",
                                text: "#!/bin/env python\n" +
                                        "import json\n" +
                                        "import sys\n\n" +
                                        "reload(sys)\n" +
                                        "sys.setdefaultencoding('utf-8')\n" +
                                        "message = json.load(sys.stdin)\n" +
                                        "if 'commit' in message:\n" +
                                        "    msg = message['commit']\n\n" +
                                        "    for key in msg:\n" +
                                        "        safe_key = key.replace('-', '_')\n" +
                                        "        print \"fed_%s=%s\" % (safe_key, msg[key])\n"

                        // Parse the ${CI_MESSAGE}
                        sh '''
                #!/bin/bash
                set -xuo pipefail

                chmod +x ${WORKSPACE}/parse_fedmsg.py

                # Write fedmsg fields to a file to inject them
                if [ -n "${CI_MESSAGE}" ]; then
                    echo ${CI_MESSAGE} | ${WORKSPACE}/parse_fedmsg.py > fedmsg_fields.txt
                    sed -i '/^\\\\s*$/d' ${WORKSPACE}/fedmsg_fields.txt
                    sed -i '/`/g' ${WORKSPACE}/fedmsg_fields.txt
                    sed -i '/^fed/!d' ${WORKSPACE}/fedmsg_fields.txt
                    grep fed ${WORKSPACE}/fedmsg_fields.txt > ${WORKSPACE}/fedmsg_fields.txt.tmp
                    mv ${WORKSPACE}/fedmsg_fields.txt.tmp ${WORKSPACE}/fedmsg_fields.txt
                fi
            '''

                        // Load fedmsg fields as environment variables
                        def fedmsg_fields = "${env.WORKSPACE}/fedmsg_fields.txt"
                        def fedmsg_fields_groovy = "${env.WORKSPACE}/fedmsg_fields.groovy"
                        convertProps(fedmsg_fields, fedmsg_fields_groovy)
                        load(fedmsg_fields_groovy)

                        // Add Branch and Message Topic to properties and inject
                        sh '''
                set +e
                branch=${fed_branch}
                if [ "${branch}" = "master" ]; then
                  branch="rawhide"
                fi
                
                
                # Save the bramch in job.properties
                echo "branch=${branch}" >> ${WORKSPACE}/job.properties
                echo "topic=${MAIN_TOPIC}.ci.pipeline.package.queued" >> ${WORKSPACE}/job.properties
                exit
            '''
                        def job_props = "${env.WORKSPACE}/job.properties"
                        def job_props_groovy = "${env.WORKSPACE}/job.properties.groovy"
                        convertProps(job_props, job_props_groovy)
                        load(job_props_groovy)

                        // Set groovy and env vars
                        env.task = "./ci-pipeline/tasks/rpmbuild-test"
                        env.playbook = "ci-pipeline/playbooks/setup-rpmbuild-system.yml"
                        env.ref = "fedora/${branch}/${basearch}/atomic-host"
                        env.repo = "${fed_repo}"
                        env.rev = "${fed_rev}"
                        env.ANSIBLE_HOST_KEY_CHECKING = "False"
                        env.DUFFY_OP = "--allocate"

                        // Send message org.centos.prod.ci.pipeline.package.running on fedmsg
                        env.topic = "${MAIN_TOPIC}.ci.pipeline.package.running"
                        messageProperties = "topic=${topic}\n" +
                                "build_url=${BUILD_URL}\n" +
                                "build_id=${BUILD_ID}\n" +
                                "branch=${branch}\n" +
                                "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                "rev=${fed_rev}\n" +
                                "repo=${fed_repo}\n" +
                                "namespace=${fed_namespace}\n" +
                                "username=fedora-atomic\n" +
                                "test_guidance=''\n" +
                                "status=${currentBuild.currentResult}"
                        messageContent = ''
                        sendMessage(messageProperties, messageContent)

                        // Provision of resources
                        allocDuffy("${current_stage}")

                        echo "Duffy Allocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                "ORIGIN_WORKSPACE=${env.ORIGIN_WORKSPACE}\r\n" +
                                "ORIGIN_BUILD_TAG=${env.ORIGIN_BUILD_TAG}\r\n" +
                                "ORIGIN_CLASS=${env.ORIGIN_CLASS}"

                        job_props = "${env.ORIGIN_WORKSPACE}/job.props"
                        job_props_groovy = "${env.ORIGIN_WORKSPACE}/job.groovy"
                        convertProps(job_props, job_props_groovy)
                        load(job_props_groovy)

                        // Stage resources - RPM build system
                        setupStage("${current_stage}")

                        if (env.OSTREE_BRANCH == null) {
                            env.OSTREE_BRANCH = ""
                        }

                        // Rsync Data
                        writeFile file: "${env.ORIGIN_WORKSPACE}/task.env",
                                text: "export JENKINS_JOB_NAME=\"${JOB_NAME}-${current_stage}\"\n" +
                                        "export HTTP_BASE=\"${HTTP_BASE}\"\n" +
                                        "export RSYNC_USER=\"${RSYNC_USER}\"\n" +
                                        "export RSYNC_SERVER=\"${RSYNC_SERVER}\"\n" +
                                        "export RSYNC_DIR=\"${RSYNC_DIR}\"\n" +
                                        "export FEDORA_PRINCIPAL=\"${FEDORA_PRINCIPAL}\"\n" +
                                        "export JENKINS_BUILD_TAG=\"${BUILD_TAG}-${current_stage}\"\n" +
                                        "export OSTREE_BRANCH=\"${OSTREE_BRANCH}\"\n" +
                                        "export fed_repo=\"${fed_repo}\"\n" +
                                        "export fed_branch=\"${fed_branch}\"\n" +
                                        "export fed_rev=\"${fed_rev}\"\n"
                        rsyncResults("${current_stage}")

                        def package_props = "${env.ORIGIN_WORKSPACE}/logs/package_props.txt"
                        def package_props_groovy = "${env.ORIGIN_WORKSPACE}/package_props.groovy"
                        convertProps(package_props, package_props_groovy)
                        load(package_props_groovy)

                        // Teardown resources
                        env.DUFFY_OP="--teardown"
                        allocDuffy("${current_stage}")
                        echo "Duffy Deallocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                "RSYNC_PASSWORD=${env.RSYNC_PASSWORD}\r\n" +
                                "DUFFY_HOST=${env.DUFFY_HOST}"

                        // Send message org.centos.prod.ci.pipeline.package.complete on fedmsg
                        env.topic = "${MAIN_TOPIC}.ci.pipeline.package.complete"
                        messageProperties = "topic=${topic}\n" +
                                "build_url=${BUILD_URL}\n" +
                                "build_id=${BUILD_ID}\n" +
                                "branch=${branch}\n" +
                                "package_url=${package_url}\n" +
                                "original_spec_nvr=${original_spec_nvr}\n" +
                                "nvr=${nvr}\n" +
                                "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                "rev=${fed_rev}\n" +
                                "repo=${fed_repo}\n" +
                                "namespace=${fed_namespace}\n" +
                                "username=fedora-atomic\n" +
                                "test_guidance=''\n" +
                                "status=${currentBuild.currentResult}"
                        messageContent = ''
                        sendMessage(messageProperties, messageContent)
                    }
                    current_stage = "ci-pipeline-ostree-compose"
                    stage(current_stage) {

                        // Set groovy and env vars
                        env.task = "./ci-pipeline/tasks/ostree-compose"
                        env.playbook = "ci-pipeline/playbooks/rdgo-setup.yml"
                        env.ref = "fedora/${branch}/${basearch}/atomic-host"
                        env.repo = "${fed_repo}"
                        env.rev = "${fed_rev}"
                        env.basearch = "x86_64"
                        env.ANSIBLE_HOST_KEY_CHECKING = "False"
                        env.DUFFY_OP = "--allocate"

                        // Send message org.centos.prod.ci.pipeline.compose.running on fedmsg
                        env.topic = "${MAIN_TOPIC}.ci.pipeline.compose.running"
                        messageProperties = "topic=${topic}\n" +
                                "build_url=${BUILD_URL}\n" +
                                "build_id=${BUILD_ID}\n" +
                                "compose_url=${HTTP_BASE}/${branch}/ostree\n" +
                                "compose_rev=''\n" +
                                "branch=${branch}\n" +
                                "original_spec_nvr=${original_spec_nvr}\n" +
                                "nvr=${nvr}\n" +
                                "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                "rev=${fed_rev}\n" +
                                "repo=${fed_repo}\n" +
                                "namespace=${fed_namespace}\n" +
                                "username=fedora-atomic\n" +
                                "test_guidance=''\n" +
                                "status=${currentBuild.currentResult}"
                        messageContent = ''
                        sendMessage(messageProperties, messageContent)

                        // Provision resources
                        env.DUFFY_OP = "--allocate"
                        allocDuffy("${current_stage}")

                        echo "Duffy Allocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                "ORIGIN_WORKSPACE=${env.ORIGIN_WORKSPACE}\r\n" +
                                "ORIGIN_BUILD_TAG=${env.ORIGIN_BUILD_TAG}\r\n" +
                                "ORIGIN_CLASS=${env.ORIGIN_CLASS}"
                        def job_props = "${env.ORIGIN_WORKSPACE}/job.props"
                        def job_props_groovy = "${env.ORIGIN_WORKSPACE}/job.groovy"
                        convertProps(job_props, job_props_groovy)
                        load(job_props_groovy)

                        // Stage resources - ostree compose
                        setupStage("${current_stage}")

                        if (env.OSTREE_BRANCH == null) {
                            env.OSTREE_BRANCH = ""
                        }

                        // Rsync Data
                        writeFile file: "${env.ORIGIN_WORKSPACE}/task.env",
                                text: "export branch=\"${branch}\"\n" +
                                        "export HTTP_BASE=\"${HTTP_BASE}\"\n" +
                                        "export RSYNC_USER=\"${RSYNC_USER}\"\n" +
                                        "export RSYNC_SERVER=\"${RSYNC_SERVER}\"\n" +
                                        "export RSYNC_DIR=\"${RSYNC_DIR}\"\n" +
                                        "export FEDORA_PRINCIPAL=\"${FEDORA_PRINCIPAL}\"\n" +
                                        "export JENKINS_JOB_NAME=\"${JOB_NAME}-${current_stage}\"\n" +
                                        "export JENKINS_BUILD_TAG=\"${BUILD_TAG}-${current_stage}\"\n" +
                                        "export OSTREE_BRANCH=\"${OSTREE_BRANCH}\"\n"
                        rsyncResults("${current_stage}")

                        def ostree_props = "${env.ORIGIN_WORKSPACE}/logs/ostree.props"
                        def ostree_props_groovy = "${env.ORIGIN_WORKSPACE}/ostree.props.groovy"
                        convertProps(ostree_props, ostree_props_groovy)
                        load(ostree_props_groovy)

                        // Teardown resource
                        env.DUFFY_OP = "--teardown"
                        allocDuffy("${current_stage}")

                        echo "Duffy Deallocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                "RSYNC_PASSWORD=${env.RSYNC_PASSWORD}\r\n" +
                                "DUFFY_HOST=${env.DUFFY_HOST}"

                        // Send message org.centos.prod.ci.pipeline.compose.complete on fedmsg
                        env.topic = "${MAIN_TOPIC}.ci.pipeline.compose.complete"
                        messageProperties = "topic=${topic}\n" +
                                "build_url=${BUILD_URL}\n" +
                                "build_id=${BUILD_ID}\n" +
                                "compose_url=${HTTP_BASE}/${branch}/ostree\n" +
                                "compose_rev=${commit}\n" +
                                "branch=${branch}\n" +
                                "original_spec_nvr=${original_spec_nvr}\n" +
                                "nvr=${nvr}\n" +
                                "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                "rev=${fed_rev}\n" +
                                "repo=${fed_repo}\n" +
                                "namespace=${fed_namespace}\n" +
                                "username=fedora-atomic\n" +
                                "test_guidance=''\n" +
                                "status=${currentBuild.currentResult}"
                        messageContent = ''
                        sendMessage(messageProperties, messageContent)

                        checkLastImage("${current_stage}")
                    }
                    current_stage = "ci-pipeline-ostree-image-compose"
                    stage(current_stage) {
                        // Set groovy and env vars
                        // Check if a new ostree image compose is needed
                        if (fileExists("${env.WORKSPACE}/NeedNewImage.txt") || ("${env.GENERATE_IMAGE}" == "true")) {
                            env.task = "./ci-pipeline/tasks/ostree-image-compose"
                            env.playbook = "ci-pipeline/playbooks/rdgo-setup.yml"
                            env.ANSIBLE_HOST_KEY_CHECKING = "False"
                            env.DUFFY_OP = "--allocate"

                            // Send message org.centos.prod.ci.pipeline.image.running on fedmsg
                            env.topic = "${MAIN_TOPIC}.ci.pipeline.image.running"
                            messageProperties = "topic=${topic}\n" +
                                    "build_url=${BUILD_URL}\n" +
                                    "build_id=${BUILD_ID}\n" +
                                    "image_url=''\n" +
                                    "image_name=''\n" +
                                    "type=qcow2\n" +
                                    "compose_url=${HTTP_BASE}/${branch}/ostree\n" +
                                    "compose_rev=${commit}\n" +
                                    "branch=${branch}\n" +
                                    "original_spec_nvr=${original_spec_nvr}\n" +
                                    "nvr=${nvr}\n" +
                                    "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                    "rev=${fed_rev}\n" +
                                    "repo=${fed_repo}\n" +
                                    "namespace=${fed_namespace}\n" +
                                    "username=fedora-atomic\n" +
                                    "test_guidance=''\n" +
                                    "status=${currentBuild.currentResult}"
                            messageContent = ''
                            sendMessage(messageProperties, messageContent)

                            // Provision resources
                            env.DUFFY_OP = "--allocate"
                            allocDuffy("${current_stage}")

                            echo "Duffy Allocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                    "ORIGIN_WORKSPACE=${env.ORIGIN_WORKSPACE}\r\n" +
                                    "ORIGIN_BUILD_TAG=${env.ORIGIN_BUILD_TAG}\r\n" +
                                    "ORIGIN_CLASS=${env.ORIGIN_CLASS}"
                            job_props = "${env.ORIGIN_WORKSPACE}/job.props"
                            job_props_groovy = "${env.ORIGIN_WORKSPACE}/job.groovy"
                            convertProps(job_props, job_props_groovy)
                            load(job_props_groovy)

                            // Stage resources - ostree compose
                            setupStage("${current_stage}")

                            if (env.OSTREE_BRANCH == null) {
                                env.OSTREE_BRANCH = ""
                            }

                            // Rsync Data
                            writeFile file: "${env.ORIGIN_WORKSPACE}/task.env",
                                    text: "export branch=\"${branch}\"\n" +
                                            "export HTTP_BASE=\"${HTTP_BASE}\"\n" +
                                            "export RSYNC_USER=\"${RSYNC_USER}\"\n" +
                                            "export RSYNC_SERVER=\"${RSYNC_SERVER}\"\n" +
                                            "export RSYNC_DIR=\"${RSYNC_DIR}\"\n" +
                                            "export FEDORA_PRINCIPAL=\"${FEDORA_PRINCIPAL}\"\n" +
                                            "export JENKINS_JOB_NAME=\"${JOB_NAME}-${current_stage}\"\n" +
                                            "export JENKINS_BUILD_TAG=\"${BUILD_TAG}-${current_stage}\"\n" +
                                            "export OSTREE_BRANCH=\"${OSTREE_BRANCH}\"\n"
                            rsyncResults("${current_stage}")

                            ostree_props = "${env.ORIGIN_WORKSPACE}/logs/ostree.props"
                            ostree_props_groovy = "${env.ORIGIN_WORKSPACE}/ostree.props.groovy"
                            convertProps(ostree_props, ostree_props_groovy)
                            load(ostree_props_groovy)

                            // Teardown resources
                            env.DUFFY_OP = "--teardown"
                            allocDuffy("${current_stage}")

                            echo "Duffy Deallocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                    "RSYNC_PASSWORD=${env.RSYNC_PASSWORD}\r\n" +
                                    "DUFFY_HOST=${env.DUFFY_HOST}"

                            // Send message org.centos.prod.ci.pipeline.image.complete on fedmsg
                            env.topic = "${MAIN_TOPIC}.ci.pipeline.image.complete"
                            messageProperties = "topic=${topic}\n" +
                                    "build_url=${BUILD_URL}\n" +
                                    "build_id=${BUILD_ID}\n" +
                                    "image_url=${image2boot}\n" +
                                    "image_name=${image_name}\n" +
                                    "type=qcow2\n" +
                                    "compose_url=${HTTP_BASE}/${branch}/ostree\n" +
                                    "compose_rev=${commit}\n" +
                                    "branch=${branch}\n" +
                                    "original_spec_nvr=${original_spec_nvr}\n" +
                                    "nvr=${nvr}\n" +
                                    "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                    "rev=${fed_rev}\n" +
                                    "repo=${fed_repo}\n" +
                                    "namespace=${fed_namespace}\n" +
                                    "username=fedora-atomic\n" +
                                    "test_guidance=''\n" +
                                    "status=${currentBuild.currentResult}"
                            messageContent = ''
                            sendMessage(messageProperties, messageContent)
                        } else {
                            echo "Not Generating a New Image"
                        }
                    }
                    current_stage = "ci-pipeline-ostree-image-boot-sanity"
                    stage(current_stage) {
                        // Set groovy and env vars
                        if (fileExists("${env.WORKSPACE}/NeedNewImage.txt") || ("${env.GENERATE_IMAGE}" == "true")) {
                            env.task = "./ci-pipeline/tasks/ostree-image-compose"
                            env.playbook = "ci-pipeline/playbooks/system-setup.yml"
                            env.ANSIBLE_HOST_KEY_CHECKING = "False"
                            env.DUFFY_OP = "--allocate"

                            // Send message org.centos.prod.ci.pipeline.image.test.smoke.running on fedmsg
                            env.topic = "${MAIN_TOPIC}.ci.pipeline.image.test.smoke.running"
                            messageProperties = "topic=${topic}\n" +
                                    "build_url=${BUILD_URL}\n" +
                                    "build_id=${BUILD_ID}\n" +
                                    "image_url=${image2boot}\n" +
                                    "image_name=${image_name}\n" +
                                    "type=qcow2\n" +
                                    "compose_url=${HTTP_BASE}/${branch}/ostree\n" +
                                    "compose_rev=${commit}\n" +
                                    "branch=${branch}\n" +
                                    "original_spec_nvr=${original_spec_nvr}\n" +
                                    "nvr=${nvr}\n" +
                                    "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                    "rev=${fed_rev}\n" +
                                    "repo=${fed_repo}\n" +
                                    "namespace=${fed_namespace}\n" +
                                    "username=fedora-atomic\n" +
                                    "test_guidance=''\n" +
                                    "status=${currentBuild.currentResult}"
                            messageContent = ''
                            sendMessage(messageProperties, messageContent)

                            // Provision resources
                            env.DUFFY_OP = "--allocate"
                            allocDuffy("${current_stage}")

                            echo "Duffy Allocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                    "ORIGIN_WORKSPACE=${env.ORIGIN_WORKSPACE}\r\n" +
                                    "ORIGIN_BUILD_TAG=${env.ORIGIN_BUILD_TAG}\r\n" +
                                    "ORIGIN_CLASS=${env.ORIGIN_CLASS}"
                            job_props = "${env.ORIGIN_WORKSPACE}/job.props"
                            job_props_groovy = "${env.ORIGIN_WORKSPACE}/job.groovy"
                            convertProps(job_props, job_props_groovy)
                            load(job_props_groovy)

                            // Stage resources - ostree compose
                            setupStage("${current_stage}")

                            if (env.OSTREE_BRANCH == null) {
                                env.OSTREE_BRANCH = ""
                            }

                            // Rsync Data
                            writeFile file: "${env.ORIGIN_WORKSPACE}/task.env",
                                    text: "export branch=\"${branch}\"\n" +
                                            "export HTTP_BASE=\"${HTTP_BASE}\"\n" +
                                            "export RSYNC_USER=\"${RSYNC_USER}\"\n" +
                                            "export RSYNC_SERVER=\"${RSYNC_SERVER}\"\n" +
                                            "export RSYNC_DIR=\"${RSYNC_DIR}\"\n" +
                                            "export FEDORA_PRINCIPAL=\"${FEDORA_PRINCIPAL}\"\n" +
                                            "export JENKINS_JOB_NAME=\"${JOB_NAME}-${current_stage}\"\n" +
                                            "export JENKINS_BUILD_TAG=\"${BUILD_TAG}-${current_stage}\"\n" +
                                            "export OSTREE_BRANCH=\"${OSTREE_BRANCH}\"\n" +
                                            "export ANSIBLE_HOST_KEY_CHECKING=\"False\"\n"
                            rsyncResults("${current_stage}")

                            // Teardown resources
                            env.DUFFY_OP="--teardown"
                            allocDuffy("${current_stage}")

                            echo "Duffy Deallocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                    "RSYNC_PASSWORD=${env.RSYNC_PASSWORD}\r\n" +
                                    "DUFFY_HOST=${env.DUFFY_HOST}"

                            // Send message org.centos.prod.ci.pipeline.image.test.smoke.complete on fedmsg
                            env.topic = "${MAIN_TOPIC}.ci.pipeline.image.test.smoke.complete"
                            messageProperties = "topic=${topic}\n" +
                                    "build_url=${BUILD_URL}\n" +
                                    "build_id=${BUILD_ID}\n" +
                                    "image_url=${image2boot}\n" +
                                    "image_name=${image_name}\n" +
                                    "type=qcow2\n" +
                                    "compose_url=${HTTP_BASE}/${branch}/ostree\n" +
                                    "compose_rev=${commit}\n" +
                                    "branch=${branch}\n" +
                                    "original_spec_nvr=${original_spec_nvr}\n" +
                                    "nvr=${nvr}\n" +
                                    "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                    "rev=${fed_rev}\n" +
                                    "repo=${fed_repo}\n" +
                                    "namespace=${fed_namespace}\n" +
                                    "username=fedora-atomic\n" +
                                    "test_guidance=''\n" +
                                    "status=${currentBuild.currentResult}"
                            sendMessage(messageProperties, messageContent)
                        } else {
                            echo "Not Running Image Boot Sanity on Image"
                        }
                    }
                    current_stage = "ci-pipeline-ostree-boot-sanity"
                    stage(current_stage) {
                        // Set groovy and env vars
                        env.task = "./ci-pipeline/tasks/ostree-boot-image"
                        env.playbook = "ci-pipeline/playbooks/system-setup.yml"

                        // Provision resources
                        env.DUFFY_OP = "--allocate"
                        allocDuffy("${current_stage}")


                        echo "Duffy Allocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                "ORIGIN_WORKSPACE=${env.ORIGIN_WORKSPACE}\r\n" +
                                "ORIGIN_BUILD_TAG=${env.ORIGIN_BUILD_TAG}\r\n" +
                                "ORIGIN_CLASS=${env.ORIGIN_CLASS}"

                        def job_props = "${env.ORIGIN_WORKSPACE}/job.props"
                        def job_props_groovy = "${env.ORIGIN_WORKSPACE}/job.groovy"
                        convertProps(job_props, job_props_groovy)
                        load(job_props_groovy)

                        // Stage resources - ostree compose
                        setupStage("${current_stage}")

                        if (env.OSTREE_BRANCH == null) {
                            env.OSTREE_BRANCH = ""
                        }

                        if (env.commit == null) {
                            env.commit = ""
                        }

                        if (env.image2boot == null) {
                            env.image2boot = ""
                        }

                        // Rsync Data
                        writeFile file: "${env.ORIGIN_WORKSPACE}/task.env",
                                text: "export branch=\"${branch}\"\n" +
                                        "export HTTP_BASE=\"${HTTP_BASE}\"\n" +
                                        "export RSYNC_USER=\"${RSYNC_USER}\"\n" +
                                        "export RSYNC_SERVER=\"${RSYNC_SERVER}\"\n" +
                                        "export RSYNC_DIR=\"${RSYNC_DIR}\"\n" +
                                        "export FEDORA_PRINCIPAL=\"${FEDORA_PRINCIPAL}\"\n" +
                                        "export fed_repo=\"${fed_repo}\"\n" +
                                        "export image2boot=\"${image2boot}\"\n" +
                                        "export commit=\"${commit}\"\n" +
                                        "export JENKINS_JOB_NAME=\"${JOB_NAME}-${current_stage}\"\n" +
                                        "export JENKINS_BUILD_TAG=\"${BUILD_TAG}-${current_stage}\"\n" +
                                        "export OSTREE_BRANCH=\"${OSTREE_BRANCH}\"\n" +
                                        "export ANSIBLE_HOST_KEY_CHECKING=\"False\"\n"

                        rsyncResults("${current_stage}")

                        // Teardown resources
                        env.DUFFY_OP="--teardown"
                        allocDuffy("${current_stage}")

                        echo "Duffy Deallocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                "RSYNC_PASSWORD=${env.RSYNC_PASSWORD}\r\n" +
                                "DUFFY_HOST=${env.DUFFY_HOST}"

//                    step([$class: 'XUnitBuilder',
//                          thresholds: [[$class: 'FailedThreshold', unstableThreshold: '1']],
//                          tools: [[$class: 'JUnitType', pattern: "${env.ORIGIN_WORKSPACE}/logs/*.xml"]]]
//                    )

                        // Send integration test queued message on fedmsg
                        env.topic = "${MAIN_TOPIC}.ci.pipeline.compose.test.integration.queued"
                        messageProperties = "topic=${topic}\n" +
                                "build_url=${BUILD_URL}\n" +
                                "build_id=${BUILD_ID}\n" +
                                "compose_url=${HTTP_BASE}/${branch}/ostree\n" +
                                "compose_rev=${commit}\n" +
                                "branch=${branch}\n" +
                                "original_spec_nvr=${original_spec_nvr}\n" +
                                "nvr=${nvr}\n" +
                                "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                "rev=${fed_rev}\n" +
                                "repo=${fed_repo}\n" +
                                "namespace=${fed_namespace}\n" +
                                "username=fedora-atomic\n" +
                                "test_guidance=''\n" +
                                "status=${currentBuild.currentResult}"
                        messageContent = ''
                        sendMessage(messageProperties, messageContent)
                    }
                    current_stage="ci-pipeline-atomic-host-tests"
                    stage(current_stage) {
                        // Set groovy and env vars
                        env.task = "./ci-pipeline/tasks/atomic-host-tests"
                        env.playbook = "ci-pipeline/playbooks/system-setup.yml"

                        // Send integration test running message on fedmsg
                        env.topic = "${MAIN_TOPIC}.ci.pipeline.compose.test.integration.running"
                        messageProperties = "topic=${topic}\n" +
                                "build_url=${BUILD_URL}\n" +
                                "build_id=${BUILD_ID}\n" +
                                "compose_url=${HTTP_BASE}/${branch}/ostree\n" +
                                "compose_rev=${commit}\n" +
                                "branch=${branch}\n" +
                                "original_spec_nvr=${original_spec_nvr}\n" +
                                "nvr=${nvr}\n" +
                                "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                "rev=${fed_rev}\n" +
                                "repo=${fed_repo}\n" +
                                "namespace=${fed_namespace}\n" +
                                "username=fedora-atomic\n" +
                                "test_guidance=''\n" +
                                "status=${currentBuild.currentResult}"
                        messageContent = ''
                        sendMessage(messageProperties, messageContent)

                        env.DUFFY_OP="--allocate"
                        allocDuffy("${current_stage}")


                        echo "Duffy Allocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                "ORIGIN_WORKSPACE=${env.ORIGIN_WORKSPACE}\r\n" +
                                "ORIGIN_BUILD_TAG=${env.ORIGIN_BUILD_TAG}\r\n" +
                                "ORIGIN_CLASS=${env.ORIGIN_CLASS}"

                        def props_file = "${env.ORIGIN_WORKSPACE}/job.props"
                        def new_props_file = "${env.ORIGIN_WORKSPACE}/job.groovy"
                        convertProps(props_file, new_props_file)
                        load(new_props_file)

                        // Run Setup
                        setupStage("${current_stage}")

                        // Teardown
                        env.DUFFY_OP="--teardown"
                        allocDuffy("${current_stage}")
                        echo "Duffy Deallocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                "RSYNC_PASSWORD=${env.RSYNC_PASSWORD}\r\n" +
                                "DUFFY_HOST=${env.DUFFY_HOST}"

//                     step([$class: 'XUnitBuilder',
//                          thresholds: [[$class: 'FailedThreshold', unstableThreshold: '1']],
//                          tools: [[$class: 'JUnitType', pattern: "${env.ORIGIN_WORKSPACE}/logs/ansible_xunit.xml"]]]
//                    )

                        // Send integration test complete message on fedmsg
                        env.topic = "${MAIN_TOPIC}.ci.pipeline.compose.test.integration.complete"
                        messageProperties = "topic=${topic}\n" +
                                "build_url=${BUILD_URL}\n" +
                                "build_id=${BUILD_ID}\n" +
                                "compose_url=${HTTP_BASE}/${branch}/ostree\n" +
                                "compose_rev=${commit}\n" +
                                "branch=${branch}\n" +
                                "original_spec_nvr=${original_spec_nvr}\n" +
                                "nvr=${nvr}\n" +
                                "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                "rev=${fed_rev}\n" +
                                "repo=${fed_repo}\n" +
                                "namespace=${fed_namespace}\n" +
                                "username=fedora-atomic\n" +
                                "test_guidance=''\n" +
                                "status=${currentBuild.currentResult}"
                        messageContent = ''
                        sendMessage(messageProperties, messageContent)
                    }
                } catch (e) {
                    echo "Error: Exception from " + current_stage + ":"
                    echo e.getMessage()
                    // Teardown resources
                    env.DUFFY_OP = "--teardown"
                    echo "Duffy Deallocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                            "RSYNC_PASSWORD=${env.RSYNC_PASSWORD}\r\n" +
                            "DUFFY_HOST=${env.DUFFY_HOST}"
                    allocDuffy("${current_stage}")
                    // Send failure message for appropriate topic
                    sendMessage(messageProperties, messageContent)
                    throw e
                } finally {
                    currentBuild.displayName = "Build#: ${env.BUILD_NUMBER} - Branch: ${env.branch} - Package: ${env.fed_repo}"
                    currentBuild.description = "${currentBuild.currentResult}"
                    //emailext subject: "${env.JOB_NAME} - Build # ${env.BUILD_NUMBER} - STATUS = ${currentBuild.currentResult}", to: "ari@redhat.com", body: "This pipeline was a ${currentBuild.currentResult}"
                    step([$class: 'ArtifactArchiver', allowEmptyArchive: true, artifacts: '**/logs/**,*.txt,*.groovy,**/job.*,**/*.groovy,**/inventory.*', excludes: '**/*.example', fingerprint: true])
                }
            }
        }
    }
}

def allocDuffy(stage) {
    echo "Currently in stage: ${stage} ${env.DUFFY_OP} resources"
    env.ORIGIN_WORKSPACE="${env.WORKSPACE}/${stage}"
    env.ORIGIN_BUILD_TAG="${env.BUILD_TAG}-${stage}"
    env.ORIGIN_CLASS="builder"
    env.DUFFY_JOB_TIMEOUT_SECS="3600"

    withCredentials([file(credentialsId: 'duffy-key', variable: 'DUFFY_KEY')]) {
        sh '''
            #!/bin/bash
            set -xeuo pipefail
    
            cp ${DUFFY_KEY} ~/duffy.key
            chmod 600 ~/duffy.key

            mkdir -p ${ORIGIN_WORKSPACE}
            # If we somehow got called without an op, do nothing.
            if test -z "${DUFFY_OP:-}"; then
              exit 0
            fi
            if test -n "${ORIGIN_WORKSPACE:-}"; then
              pushd ${ORIGIN_WORKSPACE}
            fi
            if test -n "${ORIGIN_CLASS:-}"; then
                exec ${WORKSPACE}/cciskel/cciskel-duffy ${DUFFY_OP} --prefix=ci-pipeline --class=${ORIGIN_CLASS} --jobid=${ORIGIN_BUILD_TAG} \
                    --timeout=${DUFFY_JOB_TIMEOUT_SECS:-0} --count=${DUFFY_COUNT:-1}
            else
                exec ${WORKSPACE}/cciskel/cciskel-duffy ${DUFFY_OP}
            fi
            exit
        '''
    }
}

def convertProps(file1, file2) {
    def command = $/awk -F'=' '{print "env."$1"=\""$2"\""}' ${file1} > ${file2}/$
    sh command
}

def setupStage(stage) {
    echo "Currently in stage: ${stage} in setupStage"

    withCredentials([file(credentialsId: 'fedora-atomic-key', variable: 'FEDORA_ATOMIC_KEY'), file(credentialsId: 'fedora-atomic-pub-key', variable: 'FEDORA_ATOMIC_PUB_KEY')]) {
        sh '''
            #!/bin/bash
            set -xeuo pipefail

            mkdir -p ~/.ssh
            cp ${FEDORA_ATOMIC_KEY} ~/.ssh/id_rsa
            cp ${FEDORA_ATOMIC_PUB_KEY} ~/.ssh/id_rsa.pub
            chmod 600 ~/.ssh/id_rsa
            chmod 644 ~/.ssh/id_rsa.pub

            # Keep compatibility with earlier cciskel-duffy
            if test -f ${ORIGIN_WORKSPACE}/inventory.${ORIGIN_BUILD_TAG}; then
                ln -fs ${ORIGIN_WORKSPACE}/inventory.${ORIGIN_BUILD_TAG} ${WORKSPACE}/inventory
            fi
    
            if test -n "${playbook:-}"; then
                ansible-playbook --private-key=${FEDORA_ATOMIC_KEY} -u root -i ${WORKSPACE}/inventory "${playbook}"
            else
                ansible --private-key=${FEDORA_ATOMIC_KEY} -u root -i ${WORKSPACE}/inventory all -m ping
            fi
            exit
        '''
    }
}

def rsyncResults(stage) {
    echo "Currently in stage: ${stage} in rsyncResults"

    withCredentials([file(credentialsId: 'duffy-key', variable: 'DUFFY_KEY'), file(credentialsId: 'fedora-keytab', variable: 'FEDORA_KEYTAB')]) {
        sh '''
            #!/bin/bash
            set -xeuo pipefail
    
            cp ${DUFFY_KEY} ~/duffy.key
            chmod 600 ~/duffy.key
    
            cp ${FEDORA_KEYTAB} fedora.keytab
            chmod 0600 fedora.keytab

            source ${ORIGIN_WORKSPACE}/task.env
            (echo -n "export RSYNC_PASSWORD=" && cat ~/duffy.key | cut -c '-13') > rsync-password.sh
            
            rsync -Hrlptv --stats -e ssh ${ORIGIN_WORKSPACE}/task.env rsync-password.sh fedora.keytab builder@${DUFFY_HOST}:${JENKINS_JOB_NAME}
            for repo in ci-pipeline sig-atomic-buildscripts; do
                rsync -Hrlptv --stats --delete -e ssh ${repo}/ builder@${DUFFY_HOST}:${JENKINS_JOB_NAME}/${repo}
            done
            
            # Use the following in ${task} to authenticate.
            #kinit -k -t ${FEDORA_KEYTAB} ${FEDORA_PRINCIPAL}
            build_success=true
            if ! ssh -tt builder@${DUFFY_HOST} "pushd ${JENKINS_JOB_NAME} && . rsync-password.sh && . task.env && ${task}"; then
                build_success=false
            fi
            
            rsync -Hrlptv --stats -e ssh builder@${DUFFY_HOST}:${JENKINS_JOB_NAME}/logs/ ${ORIGIN_WORKSPACE}/logs || true
            # Exit with code from the build
            if test "${build_success}" = "false"; then
                echo 'Build failed, see logs above'; exit 1
            fi
            exit
        '''
    }
}

def checkLastImage(stage) {
    echo "Currently in stage: ${stage} in checkLastImage"

    sh '''
        prev=$( date --date="$( curl -I --silent ${HTTP_BASE}/${branch}/images/latest-atomic.qcow2 | grep Last-Modified | sed s'/Last-Modified: //' )" +%s )
        cur=$( date +%s )
        
        elapsed=$((cur - prev))
        if [ $elapsed -gt 86400 ]; then
            echo "Time for a new image since time elapsed is ${elapsed}"
            touch ${WORKSPACE}/NeedNewImage.txt
        else
            echo "No need for a new image not time yet since time elapsed is ${elapsed}"
        fi
        exit
    '''
}

def sendMessage(msgProps, msgContent) {
    sendCIMessage messageContent: msgContent,
            messageProperties: msgProps,

            messageType: 'Custom',
            overrides: [topic: "${topic}"],
            providerName: "${MSG_PROVIDER}"
}