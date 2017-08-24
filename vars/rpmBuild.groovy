import org.centos.Messaging
import org.centos.Utils
import org.centos.pipeline.PipelineUtils

def call(body) {

    def config = [:]
    body.resolveStrategy = Closure.DELEGATE_FIRST
    body.delegate = config
    body()

    def utils = new Utils()
    def pipelineUtils = new PipelineUtils()
    def messageUtils = new Messaging()
    def current_stage = 'rpmbuild'

    try {
        stage(current_stage) {
            // Python script to parse the ${CI_MESSAGE} and write out a fedmsg_fields.groovy file
            writeFile file: "${env.WORKSPACE}/parse_fedmsg.py",
                    text: "#! /usr/bin/env python\n" +
                            "\n" +
                            "import json\n" +
                            "import os\n" +
                            "\n" +
                            "ci_message = json.loads(os.environ['CI_MESSAGE'], encoding='utf-8')\n" +
                            "\n" +
                            "if 'commit' in ci_message:\n" +
                            "    ci_message = ci_message.get('commit')\n" +
                            "\n" +
                            "    with open(\"{0}/fedmsg_fields.groovy\".format(os.environ['WORKSPACE']), 'wb') as f:\n" +
                            "        for k in ci_message:\n" +
                            "            if isinstance(ci_message[k], basestring):\n" +
                            "                ci_message[k] = ci_message[k].replace('\"', \"'\").encode('utf-8')\n" +
                            "            if k == 'message':\n" +
                            "                ci_message[k] = ci_message[k].split('\\n')[0]\n" +
                            "            f.write('env.fed_{0}=\"{1}\"\\n'.format(k.replace('-', '_', ci_message[k]))"

            // Chmod the python script to make it executable
            sh 'chmod +x ${WORKSPACE}/parse_fedmsg.py'

            // Execute the python script
            sh '${WORKSPACE}/parse_fedmsg.py'

            // Load fedmsg fields as environment variables
            def fedmsg_fields_groovy = "${env.WORKSPACE}/fedmsg_fields.groovy"
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
            def job_props_groovy = utils.convertProps(job_props)
            load(job_props_groovy)

            // Change display
            currentBuild.displayName = "Build#: ${env.BUILD_NUMBER} - Branch: ${env.branch} - Package: ${env.fed_repo}"
            currentBuild.description = "Stage: ${current_stage}"

            // Set groovy and env vars
            env.task = "./ci-pipeline/tasks/rpmbuild-test"
            env.playbook = "ci-pipeline/playbooks/setup-rpmbuild-system.yml"
            env.ref = "fedora/${branch}/${basearch}/atomic-host"
            env.repo = "${fed_repo}"
            env.rev = "${fed_rev}"
            env.ANSIBLE_HOST_KEY_CHECKING = "False"

            // Send message org.centos.prod.ci.pipeline.package.running on fedmsg
            (topic, messageProperties, messageContent) = pipelineUtils.setMessageFields('package.running')
            env.topic = topic
            messageUtils.sendMessage([topic:"${env.topic}",
                                    provider:"${env.MSG_PROVIDER}",
                                    msgType:'custom',
                                    msgProps:messageProperties,
                                    msgContent:messageContent])

            // Provision of resources
            env.DUFFY_OP = "--allocate"
            utils.duffyCciskel([stage:current_stage, duffyKey:'duffy-key', duffyOps:env.DUFFY_OP])

            echo "Duffy Allocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                 "ORIGIN_WORKSPACE=${env.ORIGIN_WORKSPACE}\r\n" +
                 "ORIGIN_BUILD_TAG=${env.ORIGIN_BUILD_TAG}\r\n" +
                 "ORIGIN_CLASS=${env.ORIGIN_CLASS}"

            job_props = "${env.ORIGIN_WORKSPACE}/job.props"
            job_props_groovy = utils.convertProps(job_props)
            load(job_props_groovy)

            // Stage resources - RPM build
            pipelineUtils.setupStage(current_stage, 'fedora-atomic-key')

            // Rsync Data - RPM build
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
            pipelineUtils.rsyncResults(current_stage, 'duffy-key')

            def package_props = "${env.ORIGIN_WORKSPACE}/logs/package_props.txt"
            def package_props_groovy = utils.convertProps(package_props)
            load(package_props_groovy)
        }
    } catch (err) {
        echo "Error: Exception from " + current_stage + ":"
        echo err.getMessage()
        throw err
    } finally {
        // Teardown resources
        env.DUFFY_OP = "--teardown"
        echo "Duffy Deallocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
             "DUFFY_HOST=${env.DUFFY_HOST}"
        utils.duffyCciskel([stage:current_stage, duffyKey:'duffy-key', duffyOps:env.DUFFY_OP])

        // Set Message Fields
        (topic, messageProperties, messageContent) = pipelineUtils.setMessageFields('package.complete')
        env.topic = topic
        // Send message org.centos.prod.ci.pipeline.package.complete on fedmsg
        messageUtils.sendMessage([topic:"${env.topic}",
                                  provider:"${env.MSG_PROVIDER}",
                                  msgType:'custom',
                                  msgProps:messageProperties,
                                  msgContent:messageContent])
        env.MSG_PROPS = messageProperties
        env.MSG_CONTENTS = messageContent
    }
}