properties(
        [
                buildDiscarder(logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '15', daysToKeepStr: '', numToKeepStr: '30')),
                disableConcurrentBuilds(),
                parameters(
                    [
                        string(description: 'fedmsg msg', name: 'CI_MESSAGE'),
                        string(defaultValue: '^(f25|f26|master)$', description: 'fedora branch targets', name: 'TARGETS'),
                        string(defaultValue: 'ci-pipeline', description: 'Main project repo', name: 'PROJECT_REPO'),
                    ]
                )
        ]
)

node('fedora-atomic') {
    ansiColor('xterm') {
        timestamps {
            try {
                deleteDir()
                stage('ci-pipeline-rpmbuild-trigger') {
                    def current_stage = "ci-pipeline-rpmbuild-trigger"
                    env.basearch = "x86_64"

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
                                    "        print \"fed_%s=%s\" % (key, msg[key])\n"

                    // Parse the ${CI_MESSAGE}
                    sh '''
                        #!/bin/bash
                        set -xuo pipefail

                        chmod +x ${WORKSPACE}/parse_fedmsg.py

                        # Write fedmsg fields to a file to inject them
                        if [ -n "${CI_MESSAGE}" ]; then
                            echo ${CI_MESSAGE} | ${WORKSPACE}/parse_fedmsg.py > fedmsg_fields.txt
                            sed -i '/^\\\\s*$/d' ${WORKSPACE}/fedmsg_fields.txt
                            grep fed ${WORKSPACE}/fedmsg_fields.txt > ${WORKSPACE}/fedmsg_fields.txt.tmp
                            mv ${WORKSPACE}/fedmsg_fields.txt.tmp ${WORKSPACE}/fedmsg_fields.txt
                        fi
                    '''

                    // Load fedmsg fields as environment variables
                    def fedmsg_fields = "${env.WORKSPACE}/fedmsg_fields.txt"
                    def fedmsg_fields_groovy = "${env.WORKSPACE}/fedmsg_fields.groovy"
                    convertProps(fedmsg_fields, fedmsg_fields_groovy)
                    load(fedmsg_fields_groovy)

                    // Check if package is in the package list for fedora-atomic host
                    sh '''
                        set +e
                        branch=${fed_branch}
                        if [ "${branch}" = "master" ]; then
                          branch="rawhide"
                        fi
                        echo "branch=${branch}" >> ${WORKSPACE}/job.properties
                        
                        # Verify this is a branch in our list of targets defined above in the parameters
                        if [[ ! "${fed_branch}" =~ ${TARGETS} ]]; then
                            echo "${fed_branch} is not in the list"
                            echo "topic=org.centos.prod.ci.pipeline.package.ignore" >> ${WORKSPACE}/job.properties
                        else                                           
                            # Verify this is a package we are interested in
                            valid=0
                            for package in $(cat ${PROJECT_REPO}/config/package_list); do
                                if [ "${package}" = "${fed_repo}" ]; then
                                    valid=1
                                    break
                                fi
                            done
                            if [ $valid -eq 0 ]; then
                                echo "Not a package we are interested in"
                                echo "topic=org.centos.prod.ci.pipeline.package.ignore" >> ${WORKSPACE}/job.properties
                            else
                                echo "topic=org.centos.prod.ci.pipeline.package.queued" >> ${WORKSPACE}/job.properties
                                touch ${WORKSPACE}/trigger.downstream
                            fi
                        fi
                    '''
                    def job_props = "${env.WORKSPACE}/job.properties"
                    def job_props_groovy = "${env.WORKSPACE}/job.properties.groovy"
                    convertProps(job_props, job_props_groovy)
                    load(job_props_groovy)

                    // Send message org.centos.prod.ci.pipeline.package.queued or .ignore on fedmsg
                    sendCIMessage messageContent: '',
                            messageProperties: "topic=${topic}\n" +
                                    "build_url=${BUILD_URL}\n" +
                                    "build_id=${BUILD_ID}\n" +
                                    "branch=${branch}\n" +
                                    "ref=fedora/${branch}/x86_64/atomic-host\n" +
                                    "rev=${fed_rev}\n" +
                                    "repo=${fed_repo}\n" +
                                    "namespace=${fed_namespace}\n" +
                                    "username=fedora-atomic\n" +
                                    "test_guidance=''\n" +
                                    "status=success",

                            messageType: 'Custom',
                            overrides: [topic: "${topic}"],
                            providerName: 'fedora-fedmsg'

                    currentBuild.result = 'SUCCESS'
                }
                if (fileExists("${env.WORKSPACE}/trigger.downstream")) {
                    stage('ci-pipeline-rpmbuild') {
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

                        // Set groovy and env vars
                        def current_stage = "ci-pipeline-rpmbuild"
                        env.task = "ci-pipeline/tasks/rpmbuild-test"
                        env.topic = "org.centos.prod.ci.pipeline.package.running"
                        env.playbook = "ci-pipeline/config/duffy-setup/setup-rpmbuild-system.yml"
                        env.ref = "fedora/${branch}/${basearch}/atomic-host"
                        env.repo = "${fed_repo}"
                        env.rev = "${fed_rev}"
                        env.ANSIBLE_HOST_KEY_CHECKING = "False"
                        env.DUFFY_OP = "--allocate"

                        // Send message org.centos.prod.ci.pipeline.package.running on fedmsg
                        sendCIMessage messageContent: '',
                                messageProperties: "topic=${topic}\n" +
                                        "build_url=${BUILD_URL}\n" +
                                        "build_id=${BUILD_ID}\n" +
                                        "branch=${branch}\n" +
                                        "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                        "rev=${fed_rev}\n" +
                                        "repo=${fed_repo}\n" +
                                        "namespace=${fed_namespace}\n" +
                                        "username=fedora-atomic\n" +
                                        "test_guidance=''\n" +
                                        "status=success",

                                messageType: 'Custom',
                                overrides: [topic: "${topic}"],
                                providerName: 'fedora-fedmsg'

                        // Provision of resources
                        allocDuffy("${current_stage}")

                        echo "Duffy Allocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                "ORIGIN_WORKSPACE=${env.ORIGIN_WORKSPACE}\r\n" +
                                "ORIGIN_BUILD_TAG=${env.ORIGIN_BUILD_TAG}\r\n" +
                                "ORIGIN_CLASS=${env.ORIGIN_CLASS}"
                        def job_props = "${env.ORIGIN_WORKSPACE}/job.props"
                        def job_props_groovy = "${env.ORIGIN_WORKSPACE}/job.groovy"
                        convertProps(job_props, job_props_groovy)
                        load(job_props_groovy)

                        // Stage resources - RPM build system
                        setupStage()

                        // Rsync Data
                        writeFile file: "${env.ORIGIN_WORKSPACE}/task.env",
                                  text: "export JENKINS_JOB_NAME=\"${JOB_NAME}-${current_stage}\"\n" +
                                        "export JENKINS_BUILD_TAG=\"${BUILD_TAG}-${current_stage}\"\n" +
                                        "export OSTREE_BRANCH=\"\${OSTREE_BRANCH:-}\"\n" +
                                        "export fed_repo=\"${fed_repo}\"\n" +
                                        "export fed_branch=\"${branch}\"\n" +
                                        "export fed_rev=\"${fed_rev}\"\n"
                        rsyncResults("$current_stage")

                        //def desc_txt = "${env.ORIGIN_WORKSPACE}/logs/description.txt"
                        //def desc_txt_groovy = "${env.ORIGIN_WORKSPACE}/description.groovy"
                        //convertProps(desc_txt, desc_txt_groovy)
                        //load(desc_txt_groovy)
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
                        env.topic = "org.centos.prod.ci.pipeline.package.complete"
                        sendCIMessage messageContent: '',
                                messageProperties: "topic=${topic}\n" +
                                        "build_url=${BUILD_URL}\n" +
                                        "build_id=${BUILD_ID}\n" +
                                        "branch=${branch}\n" +
                                        "package_url=${package_url}\n" +
                                        "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                        "rev=${fed_rev}\n" +
                                        "repo=${fed_repo}\n" +
                                        "namespace=${fed_namespace}\n" +
                                        "username=fedora-atomic\n" +
                                        "test_guidance=''\n" +
                                        "status=success",

                                messageType: 'Custom',
                                overrides: [topic: "${topic}"],
                                providerName: 'fedora-fedmsg'
                        currentBuild.result = 'SUCCESS'
                    }
                    stage('ci-pipeline-ostree-compose') {
                        // Set groovy and env vars
                        def current_stage="ci-pipeline-ostree-compose"
                        env.task = "./ci-pipeline/tasks/ostree-compose"
                        env.topic = "org.centos.prod.ci.pipeline.compose.running"
                        env.playbook = "sig-atomic-buildscripts/centos-ci/setup/setup-system.yml"
                        env.ref = "fedora/${branch}/${basearch}/atomic-host"
                        env.repo = "${fed_repo}"
                        env.rev = "${fed_rev}"
                        env.basearch = "x86_64"
                        env.ANSIBLE_HOST_KEY_CHECKING = "False"
                        env.DUFFY_OP = "--allocate"


                        // Send message org.centos.prod.ci.pipeline.compose.running on fedmsg
                        sendCIMessage messageContent: '',
                                messageProperties: "topic=${topic}\n" +
                                        "build_url=${BUILD_URL}\n" +
                                        "build_id=${BUILD_ID}\n" +
                                        "compose_url=http://artifacts.ci.centos.org/artifacts/fedora-atomic/${branch}/ostree\n" +
                                        "compose_rev='N/A'\n" +
                                        "branch=${branch}\n" +
                                        "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                        "rev=${fed_rev}\n" +
                                        "repo=${fed_repo}\n" +
                                        "namespace=${fed_namespace}\n" +
                                        "username=fedora-atomic\n" +
                                        "test_guidance=''\n" +
                                        "status=success",

                                messageType: 'Custom',
                                overrides: [topic: "${topic}"],
                                providerName: 'fedora-fedmsg'

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
                        setupStage()

                        // Rsync Data
                        writeFile file: "${env.ORIGIN_WORKSPACE}/task.env",
                                  text: "export BUILD=\"${branch}\"\n" +
                                        "export JENKINS_JOB_NAME=\"${JOB_NAME}-${current_stage}\"\n" +
                                        "export JENKINS_BUILD_TAG=\"${BUILD_TAG}-${current_stage}\"\n" +
                                        "export OSTREE_BRANCH=\"\${OSTREE_BRANCH:-}\"\n"
                        rsyncResults("$current_stage")

                        def ostree_props = "${env.ORIGIN_WORKSPACE}/logs/ostree.props"
                        def ostree_props_groovy = "${env.ORIGIN_WORKSPACE}/ostree.props.groovy"
                        convertProps(ostree_props, ostree_props_groovy)
                        load(ostree_props_groovy)

                        // Teardown resource
                        env.DUFFY_OP="--teardown"
                        allocDuffy("${current_stage}")

                        echo "Duffy Deallocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                "RSYNC_PASSWORD=${env.RSYNC_PASSWORD}\r\n" +
                                "DUFFY_HOST=${env.DUFFY_HOST}"

                        // Check if a new ostree image compose is needed
                        checkLastImage()
                        if (fileExists("${env.WORKSPACE}/NeedNewImage.txt")) {
                            stage("ci-pipeline-ostree-image-compose") {
                                // Set groovy and env vars
                                current_stage = "ci-pipeline-ostree-image-compose"
                                env.task = "./ci-pipeline/tasks/ostree-image-compose"
                                env.playbook = "sig-atomic-buildscripts/centos-ci/setup/setup-system.yml"
                                env.ANSIBLE_HOST_KEY_CHECKING = "False"
                                env.DUFFY_OP = "--allocate"

                                // Send message org.centos.prod.ci.pipeline.image.running on fedmsg
                                env.topic = "org.centos.prod.ci.pipeline.image.running"
                                sendCIMessage messageContent: '',
                                        messageProperties: "topic=${topic}\n" +
                                                "build_url=${BUILD_URL}\n" +
                                                "build_id=${BUILD_ID}\n" +
                                                "image_url=''\n" +
                                                "image_name=''\n" +
                                                "type=qcow2\n" +
                                                "compose_url=http://artifacts.ci.centos.org/artifacts/fedora-atomic/${branch}/ostree\n" +
                                                "compose_rev=${commit}\n" +
                                                "branch=${branch}\n" +
                                                "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                                "rev=${fed_rev}\n" +
                                                "repo=${fed_repo}\n" +
                                                "namespace=${fed_namespace}\n" +
                                                "username=fedora-atomic\n" +
                                                "test_guidance=''\n" +
                                                "status=success",

                                        messageType: 'Custom',
                                        overrides: [topic: "${topic}"],
                                        providerName: 'fedora-fedmsg'

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
                                setupStage()

                                // Rsync Data
                                writeFile file: "${env.ORIGIN_WORKSPACE}/task.env",
                                        text: "export BUILD=\"${branch}\"\n" +
                                                "export JENKINS_JOB_NAME=\"${JOB_NAME}-${current_stage}\"\n" +
                                                "export JENKINS_BUILD_TAG=\"${BUILD_TAG}-${current_stage}\"\n" +
                                                "export OSTREE_BRANCH=\"\${OSTREE_BRANCH:-}\"\n"
                                rsyncResults("$current_stage")

                                ostree_props = "${env.ORIGIN_WORKSPACE}/logs/ostree.props"
                                ostree_props_groovy = "${env.ORIGIN_WORKSPACE}/ostree.props.groovy"
                                convertProps(ostree_props, ostree_props_groovy)
                                load(ostree_props_groovy)

                                // Teardown resources
                                env.DUFFY_OP="--teardown"
                                allocDuffy("${current_stage}")

                                echo "Duffy Deallocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                        "RSYNC_PASSWORD=${env.RSYNC_PASSWORD}\r\n" +
                                        "DUFFY_HOST=${env.DUFFY_HOST}"

                                // Send message org.centos.prod.ci.pipeline.image.complete on fedmsg
                                env.topic = "org.centos.prod.ci.pipeline.image.complete"
                                sendCIMessage messageContent: '',
                                        messageProperties: "topic=${topic}\n" +
                                                "build_url=${BUILD_URL}\n" +
                                                "build_id=${BUILD_ID}\n" +
                                                "image_url=${image2boot}\n" +
                                                "image_name=${image_name}\n" +
                                                "type=qcow2\n" +
                                                "compose_url=http://artifacts.ci.centos.org/artifacts/fedora-atomic/${branch}/ostree\n" +
                                                "compose_rev=${commit}\n" +
                                                "branch=${branch}\n" +
                                                "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                                "rev=${fed_rev}\n" +
                                                "repo=${fed_repo}\n" +
                                                "namespace=${fed_namespace}\n" +
                                                "username=fedora-atomic\n" +
                                                "test_guidance=''\n" +
                                                "status=success",

                                        messageType: 'Custom',
                                        overrides: [topic: "${topic}"],
                                        providerName: 'fedora-fedmsg'

                                currentBuild.result = 'SUCCESS'
                            }
                            stage("ci-pipeline-ostree-image-boot-sanity") {
                                // Set groovy and env vars
                                current_stage = "ci-pipeline-ostree-image-boot-sanity"
                                env.task = "./ci-pipeline/tasks/ostree-image-compose"
                                env.playbook = "sig-atomic-buildscripts/centos-ci/setup/setup-system.yml"
                                env.ANSIBLE_HOST_KEY_CHECKING = "False"
                                env.DUFFY_OP = "--allocate"

                                // Send message org.centos.prod.ci.pipeline.image.test.smoke.running on fedmsg
                                env.topic = "org.centos.prod.ci.pipeline.image.test.smoke.running"
                                sendCIMessage messageContent: '',
                                        messageProperties: "topic=${topic}\n" +
                                                "build_url=${BUILD_URL}\n" +
                                                "build_id=${BUILD_ID}\n" +
                                                "image_url=${image2boot}\n" +
                                                "image_name=${image_name}\n" +
                                                "type=qcow2\n" +
                                                "compose_url=http://artifacts.ci.centos.org/artifacts/fedora-atomic/${branch}/ostree\n" +
                                                "compose_rev=${commit}\n" +
                                                "branch=${branch}\n" +
                                                "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                                "rev=${fed_rev}\n" +
                                                "repo=${fed_repo}\n" +
                                                "namespace=${fed_namespace}\n" +
                                                "username=fedora-atomic\n" +
                                                "test_guidance=''\n" +
                                                "status=success",

                                        messageType: 'Custom',
                                        overrides: [topic: "${topic}"],
                                        providerName: 'fedora-fedmsg'

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
                                setupStage()

                                // Rsync Data
                                writeFile file: "${env.ORIGIN_WORKSPACE}/task.env",
                                        text: "export BUILD=\"${branch}\"\n" +
                                                "export JENKINS_JOB_NAME=\"${JOB_NAME}-${current_stage}\"\n" +
                                                "export JENKINS_BUILD_TAG=\"${BUILD_TAG}-${current_stage}\"\n" +
                                                "export OSTREE_BRANCH=\"\${OSTREE_BRANCH:-}\"\n"
                                rsyncResults("$current_stage")

                                ostree_props = "${env.ORIGIN_WORKSPACE}/logs/ostree.props"
                                ostree_props_groovy = "${env.ORIGIN_WORKSPACE}/ostree.props.groovy"
                                convertProps(ostree_props, ostree_props_groovy)
                                load(ostree_props_groovy)

                                // Teardown resources
                                env.DUFFY_OP="--teardown"
                                allocDuffy("${current_stage}")

                                echo "Duffy Deallocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                        "RSYNC_PASSWORD=${env.RSYNC_PASSWORD}\r\n" +
                                        "DUFFY_HOST=${env.DUFFY_HOST}"

                                // Send message org.centos.prod.ci.pipeline.image.test.smoke.complete on fedmsg
                                env.topic = "org.centos.prod.ci.pipeline.image.test.smoke.complete"
                                sendCIMessage messageContent: '',
                                        messageProperties: "topic=${topic}\n" +
                                                "build_url=${BUILD_URL}\n" +
                                                "build_id=${BUILD_ID}\n" +
                                                "image_url=${image2boot}\n" +
                                                "image_name=${image_name}\n" +
                                                "type=qcow2\n" +
                                                "compose_url=http://artifacts.ci.centos.org/artifacts/fedora-atomic/${branch}/ostree\n" +
                                                "compose_rev=${commit}\n" +
                                                "branch=${branch}\n" +
                                                "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                                "rev=${fed_rev}\n" +
                                                "repo=${fed_repo}\n" +
                                                "namespace=${fed_namespace}\n" +
                                                "username=fedora-atomic\n" +
                                                "test_guidance=''\n" +
                                                "status=success",

                                        messageType: 'Custom',
                                        overrides: [topic: "${topic}"],
                                        providerName: 'fedora-fedmsg'

                                currentBuild.result = 'SUCCESS'
                            }

                        }


                        // Send message org.centos.prod.ci.pipeline.compose.complete on fedmsg
                        env.topic = "org.centos.prod.ci.pipeline.compose.complete"
                        sendCIMessage messageContent: '',
                                messageProperties: "topic=${topic}\n" +
                                        "build_url=${BUILD_URL}\n" +
                                        "build_id=${BUILD_ID}\n" +
                                        "compose_url=http://artifacts.ci.centos.org/artifacts/fedora-atomic/${branch}/ostree\n" +
                                        "compose_rev=${commit}\n" +
                                        "branch=${branch}\n" +
                                        "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                        "rev=${fed_rev}\n" +
                                        "repo=${fed_repo}\n" +
                                        "namespace=${fed_namespace}\n" +
                                        "username=fedora-atomic\n" +
                                        "test_guidance=''\n" +
                                        "status=success",

                                messageType: 'Custom',
                                overrides: [topic: "${topic}"],
                                providerName: 'fedora-fedmsg'

                        currentBuild.result = 'SUCCESS'
                    }
                    stage('ci-pipeline-ostree-boot-sanity') {
                        // Set groovy and env vars
                        def current_stage = "ci-pipeline-ostree-boot-sanity"
                        env.task = "./ci-pipeline/tasks/ostree-boot-image"
                        env.playbook = "sig-atomic-buildscripts/centos-ci/setup/setup-system.yml"

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
                        setupStage()

                        // Rsync Data
                        writeFile file: "${env.ORIGIN_WORKSPACE}/task.env",
                                text: "export BUILD=\"${branch}\"\n" +
                                       "export image2boot=\"\${image2boot:-}\"\n" +
                                       "export commit=\"\${commit:-}\"\n" +
                                       "export JENKINS_JOB_NAME=\"${JOB_NAME}-${current_stage}\"\n" +
                                       "export JENKINS_BUILD_TAG=\"${BUILD_TAG}-${current_stage}\"\n" +
                                       "export OSTREE_BRANCH=\"\${OSTREE_BRANCH:-}\"\n"
                        rsyncResults("$current_stage")

                        // Teardown resources
                        env.DUFFY_OP="--teardown"
                        allocDuffy("${current_stage}")

                        echo "Duffy Deallocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                "RSYNC_PASSWORD=${env.RSYNC_PASSWORD}\r\n" +
                                "DUFFY_HOST=${env.DUFFY_HOST}"

                        step([$class: 'XUnitBuilder',
                              thresholds: [[$class: 'FailedThreshold', unstableThreshold: '1']],
                              tools: [[$class: 'JUnitType', pattern: "${env.ORIGIN_WORKSPACE}/logs/*.xml"]]]
                        )

                        // Send integration test queued message on fedmsg
                        env.topic = "org.centos.prod.ci.pipeline.compose.test.integration.queued"
                        sendCIMessage messageContent: '',
                                messageProperties: "topic=${topic}\n" +
                                        "build_url=${BUILD_URL}\n" +
                                        "build_id=${BUILD_ID}\n" +
                                        "compose_url=http://artifacts.ci.centos.org/artifacts/fedora-atomic/${branch}/ostree\n" +
                                        "compose_rev=${commit}\n" +
                                        "branch=${branch}\n" +
                                        "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                        "rev=${fed_rev}\n" +
                                        "repo=${fed_repo}\n" +
                                        "namespace=${fed_namespace}\n" +
                                        "username=fedora-atomic\n" +
                                        "test_guidance=''\n" +
                                        "status=success",

                                messageType: 'Custom',
                                overrides: [topic: "${topic}"],
                                providerName: 'fedora-fedmsg'

                        currentBuild.result = 'SUCCESS'
                    }
                    stage('ci-pipeline-atomic-host-tests') {
                        // Set groovy and env vars
                        def current_stage="ci-pipeline-atomic-host-tests"
                        env.task = "./ci-pipeline/tasks/atomic-host-tests"
                        env.playbook = "sig-atomic-buildscripts/centos-ci/setup/setup-system.yml"

                        // Send integration test running message on fedmsg
                        env.topic = "org.centos.prod.ci.pipeline.compose.test.integration.running"
                        sendCIMessage messageContent: '',
                                messageProperties: "topic=${topic}\n" +
                                        "build_url=${BUILD_URL}\n" +
                                        "build_id=${BUILD_ID}\n" +
                                        "compose_url=http://artifacts.ci.centos.org/artifacts/fedora-atomic/${branch}/ostree\n" +
                                        "compose_rev=${commit}\n" +
                                        "branch=${branch}\n" +
                                        "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                        "rev=${fed_rev}\n" +
                                        "repo=${fed_repo}\n" +
                                        "namespace=${fed_namespace}\n" +
                                        "username=fedora-atomic\n" +
                                        "test_guidance=''\n" +
                                        "status=success",

                                messageType: 'Custom',
                                overrides: [topic: "${topic}"],
                                providerName: 'fedora-fedmsg'

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
                        setupStage()

                        // Teardown
                        env.DUFFY_OP="--teardown"
                        allocDuffy("${current_stage}")
                        echo "Duffy Deallocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                                "RSYNC_PASSWORD=${env.RSYNC_PASSWORD}\r\n" +
                                "DUFFY_HOST=${env.DUFFY_HOST}"

                        step([$class: 'XUnitBuilder',
                              thresholds: [[$class: 'FailedThreshold', unstableThreshold: '1']],
                              tools: [[$class: 'JUnitType', pattern: "${env.ORIGIN_WORKSPACE}/logs/ansible_xunit.xml"]]]
                        )

                        // Send integration test complete message on fedmsg
                        env.topic = "org.centos.prod.ci.pipeline.compose.test.integration.complete"
                        sendCIMessage messageContent: '',
                                messageProperties: "topic=${topic}\n" +
                                        "build_url=${BUILD_URL}\n" +
                                        "build_id=${BUILD_ID}\n" +
                                        "compose_url=http://artifacts.ci.centos.org/artifacts/fedora-atomic/${branch}/ostree\n" +
                                        "compose_rev=${commit}\n" +
                                        "branch=${branch}\n" +
                                        "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                                        "rev=${fed_rev}\n" +
                                        "repo=${fed_repo}\n" +
                                        "namespace=${fed_namespace}\n" +
                                        "username=fedora-atomic\n" +
                                        "test_guidance=''\n" +
                                        "status=success",

                                messageType: 'Custom',
                                overrides: [topic: "${topic}"],
                                providerName: 'fedora-fedmsg'

                        currentBuild.result = 'SUCCESS'
                    }
                }
            } catch (e) {
                // if any exception occurs, mark the build as failed
                currentBuild.result = 'FAILURE'
                throw e
            } finally {
                currentBuild.displayName = "Build# - ${env.BUILD_NUMBER}"
                currentBuild.description = "${currentBuild.result}"
                //emailext subject: "${env.JOB_NAME} - Build # ${env.BUILD_NUMBER} - STATUS = ${currentBuild.result}", to: "ari@redhat.com", body: "This pipeline was a ${currentBuild.result}"
                step([$class: 'ArtifactArchiver', allowEmptyArchive: true, artifacts: '**/logs/**,*.txt,*.groovy,**/job.*,**/inventory.*', excludes: '**/*.example', fingerprint: true])
            }
        }
    }
}

def allocDuffy(stage) {
    echo "Currently in stage: ${stage}"
    env.ORIGIN_WORKSPACE="${env.WORKSPACE}/${stage}"
    env.ORIGIN_BUILD_TAG="${env.BUILD_TAG}-${stage}"
    env.ORIGIN_CLASS="builder"
    env.DUFFY_JOB_TIMEOUT_SECS="3600"

    sh '''
        #!/bin/bash
        set -xeuo pipefail

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
    '''
}

def convertProps(file1, file2) {
    def command = $/awk -F'=' '{print "env."$1"=\""$2"\""}' ${file1} > ${file2}/$
    sh command
}

def setupStage() {
    sh '''
        #!/bin/bash
        set -xeuo pipefail
        
        # Keep compatibility with earlier cciskel-duffy
        if test -f ${ORIGIN_WORKSPACE}/inventory.${ORIGIN_BUILD_TAG}; then
            ln -fs ${ORIGIN_WORKSPACE}/inventory.${ORIGIN_BUILD_TAG} ${WORKSPACE}/inventory
        fi

        if test -n "${playbook:-}"; then
            ansible-playbook -u root -i ${WORKSPACE}/inventory "${playbook}"
        else
            ansible -u root -i ${WORKSPACE}/inventory all -m ping
        fi
    '''
}

def rsyncResults(stage) {
    echo "Currently in stage: ${stage}"

    sh '''
        #!/bin/bash
        set -xeuo pipefail

        (echo -n "export RSYNC_PASSWORD=" && cat ~/duffy.key | cut -c '-13') > rsync-password.sh
        
        rsync -Hrlptv --stats -e ssh ${ORIGIN_WORKSPACE}/task.env rsync-password.sh builder@${DUFFY_HOST}:${JENKINS_JOB_NAME}
        for repo in ci-pipeline sig-atomic-buildscripts; do
            rsync -Hrlptv --stats --delete -e ssh ${repo}/ builder@${DUFFY_HOST}:${JENKINS_JOB_NAME}/${repo}
        done
        
        build_success=true
        if ! ssh -tt builder@${DUFFY_HOST} "pushd ${JENKINS_JOB_NAME} && . rsync-password.sh && . task.env && ./${task}"; then
            build_success=false
        fi
        
        rsync -Hrlptv --stats -e ssh builder@${DUFFY_HOST}:${JENKINS_JOB_NAME}/logs/ ${ORIGIN_WORKSPACE}/logs || true
        # Exit with code from the build
        if test "${build_success}" = "false"; then
            echo 'Build failed, see logs above'; exit 1
        fi
    '''

}

def checkLastImage() {
    sh '''
        prev=$( date --date="$( curl -I --silent http://artifacts.ci.centos.org/artifacts/fedora-atomic/${branch}/images/latest-atomic.qcow2 | grep Last-Modified | sed s'/Last-Modified: //' )" +%s )
        cur=$( date +%s )
        
        elapsed=$((cur - prev))
        if [ $elapsed -gt 86400 ]; then
            echo "Time for a new image since time elapsed is ${elapsed}"
            touch ${WORKSPACE}/NeedNewImage.txt
        else
            echo "No need for a new image not time yet since time elapsed is ${elapsed}"
        fi
    '''
}
