#!/usr/bin/groovy
package org.centos.pipeline

import groovy.json.JsonSlurper

/**
 * Library to setup and configure the host the way ci-pipeline requires
 *
 * variables
 *  stage - current stage running
 *  sshKey - ssh file credential name stored in Jenkins credentials
 */
def setupStage(stage, sshKey) {
    echo "Currently in stage: ${stage} in setupStage"

    // TODO: Either remove sshKey arg, or determine how to invoke second credentialsID and variable name based on arg.
    // Currently having an sshKey isn't that useful as we're still hard-coding the public credentialsID entry
    withCredentials([file(credentialsId: sshKey, variable: 'FEDORA_ATOMIC_KEY'), file(credentialsId: 'fedora-atomic-pub-key', variable: 'FEDORA_ATOMIC_PUB_KEY')]) {
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

/**
 * Library to execute a task and rsync the logs back to artifacts.ci.centos.org
 *
 * variables
 *  stage - current stage running
 *  duffyKey - duffy file credential name stored in Jenkins credentials
 */
def runTaskAndReturnLogs(stage, duffyKey) {
    echo "Currently in stage: ${stage} in runTaskAndReturnLogs"

    withCredentials([file(credentialsId: duffyKey, variable: 'DUFFY_KEY'), file(credentialsId: 'fedora-keytab', variable: 'FEDORA_KEYTAB')]) {
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

/**
 * Library to check last image
 *
 * variables
 *  stage - current stage running
 *  checkRsyncDir - boolean to determine if our URL path will be the rsync dir or not. Defaults to true
 */
def checkLastImage(stage, checkRsyncDir=true) {
    echo "Currently in stage: ${stage} in checkLastImage"
    if (checkRsyncDir==true){
        env.url_path = "${HTTP_BASE}/${RSYNC_DIR}/${branch}/images/latest-atomic.qcow2"
    } else {
        env.url_path = "${HTTP_BASE}/${branch}/images/latest-atomic.qcow2"
    }

    sh '''
        prev=$( date --date="$( curl -I --silent ${url_path} | grep Last-Modified | sed s'/Last-Modified: //' )" +%s )
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

/**
 * Library to set message fields to be published
 *
 * variables
 *  messageType - ${MAIN_TOPIC}.ci.pipeline.<defined-in-README>
 */
def setMessageFields(messageType){
    topic = "${env.MAIN_TOPIC}.ci.pipeline.${messageType}"
    messageProperties = "topic=${topic}\n" +
                        "build_url=${env.BUILD_URL}\n" +
                        "build_id=${env.BUILD_ID}\n" +
                        "branch=${env.branch}\n" +
                        "compose_rev=${env.commit}\n" +
                        "namespace=${env.fed_namespace}\n" +
                        "ref=fedora/${env.branch}/${env.basearch}/atomic-host\n" +
                        "repo=${env.fed_repo}\n" +
                        "original_spec_nvr=${env.original_spec_nvr}\n" +
                        "nvr=${env.nvr}\n" +
                        "rev=${env.fed_rev}\n" +
                        "test_guidance=''\n" +
                        "username=${env.RSYNC_USER}\n" +
                        "status=${currentBuild.currentRelease}\n"
    messageContent=''

    if (messageType == 'compose.running') {
        messageProperties = messageProperties +
                "compose_url=${HTTP_BASE}/artifacts/${RSYNC_DIR}/${branch}/ostree\n"
                "compose_rev=''\n"
    } else if ((messageType == 'compose.complete') || (messageType == 'test.integration.queued') ||
            (messageType == 'test.integration.running') || (messageType == 'test.integration.complete')) {
        messageProperties = messageProperties +
            "compose_url=${HTTP_BASE}/artifacts/${RSYNC_DIR}/${branch}/ostree\n"
            "compose_rev=${commit}\n"
    } else if (messageType == 'image.running') {
            messageProperties = messageProperties +
                "compose_url=${HTTP_BASE}/artifacts/${RSYNC_DIR}/${branch}/ostree\n"
                "compose_rev=${commit}\n" +
                "image_url=''\n" +
                "image_name=''\n" +
                "type=qcow2\n"
    } else if ((messageType == 'image.complete') || (messageType == 'test.smoke.running') ||
            (messageType == 'test.smoke.compelete')) {
        messageProperties = messageProperties +
                "compose_url=${HTTP_BASE}/artifacts/${RSYNC_DIR}/${branch}/ostree\n"
                "compose_rev=${commit}\n" +
                "image_url=${image2boot}\n" +
                "image_name=${image_name}\n" +
                "type=qcow2\n"
    } else {
        return [ topic, messageProperties, messageContent ]
    }
    return [ topic, messageProperties, messageContent ]
}

/**
 * Library to send message
 *
 * variables
 *  msgProps - The message properties
 *  msgContent - The content of the message
 */
def sendMessage(msgProps, msgContent) {
    // TODO: Determine if this method can be removed. No usages seen in code.
    sendCIMessage messageContent: msgContent,
            messageProperties: msgProps,

            messageType: 'Custom',
            overrides: [topic: "${topic}"],
            providerName: "${MSG_PROVIDER}"
}

/**
 * Library to parse CI_MESSAGE and inject its key/value pairs as env variables.
 *
 */
def injectFedmsgVars() {

    // Parse the CI_MESSAGE into a Map
    def ci_data = new JsonSlurper().parseText(env.CI_MESSAGE)

    // If we have a 'commit' key in the CI_MESSAGE, for each key under 'commit', we
    // * prepend the key name with fed_
    // * replace any '-' with '_'
    // * truncate the value for the key at the first '\n' character
    // * replace any double-quote characters with single-quote characters in the value for the key.

    if (ci_data['commit']) {
        ci_data.commit.each { key, value ->
            env."fed_${key.toString().replaceAll('-', '_')}" =
                    value.toString().split('\n')[0].replaceAll('"', '\'')
        }
        if (env.fed_branch == 'master'){
            env.branch = 'rawhide'
        } else {
            env.branch = env.fedbranch
        }
    }
}

/**
 * Library to set default environmental variables. Performed once at start of Jenkinsfile
 */
def setDefaultEnvVars(){
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
    env.package_url = env.package_url ?: ''
    env.nvr = env.nvr ?: ''
    env.original_spec_nvr = env.original_spec_nvr ?: ''
    env.ANSIBLE_HOST_KEY_CHECKING = env.ANSIBLE_HOST_KEY_CHECKING ?: 'False'
}

/**
 * Library to set stage specific environmental variables
 *
 * variables
 *  currentStage - current stage running
 */
def setStageEnvVars(currentStage){
    // branch, basearch, fed_repo, & fed_rev should be accessible after calling injectFedmsgVars()

    def stages =
            ["ci-pipeline-rpmbuild"                : [
                    task                     : "./ci-pipeline/tasks/rpmbuild-test",
                    playbook                 : "ci-pipeline/playbooks/setup-rpmbuild-system.yml",
                    ref                      : "fedora/${branch}/${basearch}/atomic-host",
                    repo                     : "${fed_repo}",
                    rev                      : "${fed_rev}",
            ],
             "ci-pipeline-ostree-compose"          : [
                     task                     : "./ci-pipeline/tasks/ostree-compose",
                     playbook                 : "ci-pipeline/playbooks/rdgo-setup.yml",
                     ref                      : "fedora/${branch}/${basearch}/atomic-host",
                     repo                     : "${fed_repo}",
                     rev                      : "${fed_rev}",
                     basearch                 : "x86_64",
             ],
             "ci-pipeline-ostree-image-compose"    : [
                     task                     : "./ci-pipeline/tasks/ostree-image-compose",
                     playbook                 : "ci-pipeline/playbooks/rdgo-setup.yml",

             ],
             "ci-pipeline-ostree-image-boot-sanity": [
                     task                     : "./ci-pipeline/tasks/ostree-image-compose",
                     playbook                 : "ci-pipeline/playbooks/system-setup.yml",
             ],
             "ci-pipeline-ostree-boot-sanity"      : [
                     task    : "./ci-pipeline/tasks/ostree-boot-image",
                     playbook: "ci-pipeline/playbooks/system-setup.yml",
                     DUFFY_OP: "--allocate"
             ],
             "ci-pipeline-atomic-host-tests"       : [
                     task    : "./ci-pipeline/tasks/atomic-host-tests",
                     playbook: "ci-pipeline/playbooks/system-setup.yml",
             ]
            ]

    // Get the map of env var keys and values and write them to the env global variable
    stages.get(currentStage).each { key, value ->
        env."${key}" = value
    }
}

/**
 * Library to create text and write to file based on current stage and calls runTaskAndReturnLogs() which rsyncs
 * the logs produced from executing a task to artifacts.ci.centos.org
 *
 * variables
 *  currentStage - current stage running
 */
def rsyncData(currentStage){
    def text = "export JENKINS_JOB_NAME=\"${JOB_NAME}-${currentStage}\"\n" +
            "export RSYNC_USER=\"${RSYNC_USER}\"\n" +
            "export RSYNC_SERVER=\"${RSYNC_SERVER}\"\n" +
            "export RSYNC_DIR=\"${RSYNC_DIR}\"\n" +
            "export FEDORA_PRINCIPAL=\"${FEDORA_PRINCIPAL}\"\n" +
            "export JENKINS_BUILD_TAG=\"${BUILD_TAG}-${currentStage}\"\n" +
            "export OSTREE_BRANCH=\"${OSTREE_BRANCH}\"\n"

    if (currentStage in ['ci-pipeline-ostree-compose', 'ci-pipeline-ostree-iamge-compose',
                         'ci-pipeline-ostree-image-boot-sanity', 'ci-pipeline-ostree-boot-sanity']) {
        text = text +
                "export HTTP_BASE=\"${HTTP_BASE}\"\n" +
                "export branch=\"${branch}\"\n"
    }
    if (currentStage == 'ci-pipeline-rpmbuild') {
        text = text +
                "export fed_repo=\"${fed_repo}\"\n" +
                "export fed_branch=\"${fed_branch}\"\n" +
                "export fed_rev=\"${fed_rev}\"\n"

    } else if (currentStage == 'ci-pipeline-ostree-image-boot-sanity') {
        text = text +
                "export ANSIBLE_HOST_KEY_CHECKING=\"False\"\n"
    } else if (currentStage == 'ci-pipeline-ostree-boot-sanity') {
        text = text +
                "export fed_repo=\"${fed_repo}\"\n" +
                "export image2boot=\"${image2boot}\"\n" +
                "export commit=\"${commit}\"\n" +
                "export ANSIBLE_HOST_KEY_CHECKING=\"False\"\n"
    }

    writeFile file: "${env.ORIGIN_WORKSPACE}/task.env",
            text: text
    runTaskAndReturnLogs(currentStage)

}

/**
 * Library to provision resources used in the current stage
 *
 * variables
 *  currentStage - current stage running
 */
def provisionResources(currentStage){
    def duffyOp = "--allocate"
    allocDuffy(currentStage, duffyOp)

    echo "Duffy Allocate ran for stage ${currentStage} with option ${duffyOp}\r\n" +
            "ORIGIN_WORKSPACE=${ORIGIN_WORKSPACE}\r\n" +
            "ORIGIN_BUILD_TAG=${ORIGIN_BUILD_TAG}\r\n" +
            "ORIGIN_CLASS=${ORIGIN_CLASS}"

    job_props = "${ORIGIN_WORKSPACE}/job.props"
    job_props_groovy = "${ORIGIN_WORKSPACE}/job.groovy"
    convertProps(job_props, job_props_groovy)
    load(job_props_groovy)

}

/**
 * Library to teardown resources used in the current stage
 *
 * variables
 *   currentStage - current stage running
 */
def teardownResources(currentStage){
    def duffyOp = "--teardown"
    allocDuffy(currentStage, duffyOp)

    // DUFFY_HOST should exist as an env var from injecting the job props
    // generated by calling provisionResources() for currentStage
    echo "Duffy Deallocate ran for stage ${currentStage} with option ${duffyOp}\r\n" +
            "DUFFY_HOST=${DUFFY_HOST}"
}

/**
 * Library to provision or teardown resources based on the duffyOp
 *
 * variables
 *  stage - current stage running
 *  duffyOp - either "--allocate" or "--teardown"
 */

def allocDuffy(stage, duffyOp) {
    env.DUFFY_OP = duffyOp

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