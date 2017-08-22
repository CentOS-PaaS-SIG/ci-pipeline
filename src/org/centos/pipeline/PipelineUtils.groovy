#!/usr/bin/groovy
package org.centos.pipeline

/**
 * Library to setup and configure the host the way ci-pipeline requires
 *
 * variables
 *  stage - current stage running
 *  sshKey - ssh file credential name stored in Jenkins credentials
 */
def setupStage(stage, sshKey) {
    echo "Currently in stage: ${stage} in setupStage"

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
 * Library to rsync data back to artifacts.ci.centos.org
 *
 * variables
 *  stage - current stage running
 *  duffyKey - duffy file credential name stored in Jenkins credentials
 */
def rsyncResults(stage, duffyKey) {
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

/**
 * Library to check last image
 *
 * variables
 *  stage - current stage running
 */
def checkLastImage(stage) {
    echo "Currently in stage: ${stage} in checkLastImage"

    sh '''
        prev=$( date --date="$( curl -I --silent ${HTTP_BASE}/${RSYNC_DIR}/${branch}/images/latest-atomic.qcow2 | grep Last-Modified | sed s'/Last-Modified: //' )" +%s )
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
    topic = "${MAIN_TOPIC}.ci.pipeline.${messageType}"
    messageProperties = "topic=${topic}\n" +
                        "build_url=${BUILD_URL}\n" +
                        "build_id=${BUILD_ID}\n" +
                        "branch=${branch}\n" +
                        "compose_rev=${commit}\n" +
                        "namespace=${fed_namespace}\n" +
                        "ref=fedora/${branch}/${basearch}/atomic-host\n" +
                        "repo=${fed_repo}\n" +
                        "rev=${fed_rev}\n" +
                        "test_guidance=''\n" +
                        "username=${RSYNC_USER}\n" +
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