#!/usr/bin/groovy
package org.centos.pipeline

/**
 * Library to setup the to configure the host to be configured the way we want
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
 * Library to setup the to configure the host to be configured the way we want
 *
 * variables
 *  stage - current stage running
 *  duffyKey - duffy file credential name stored in Jenkins credentials
 */
def rsyncResults(stage, duffyKey) {
    echo "Currently in stage: ${stage} in rsyncResults"

    withCredentials([file(credentialsId: duffyKey, variable: 'DUFFY_KEY')]) {
        sh '''
            #!/bin/bash
            set -xeuo pipefail
    
            cp ${DUFFY_KEY} ~/duffy.key
            chmod 600 ~/duffy.key
    
            source ${ORIGIN_WORKSPACE}/task.env
            (echo -n "export RSYNC_PASSWORD=" && cat ~/duffy.key | cut -c '-13') > rsync-password.sh
            
            rsync -Hrlptv --stats -e ssh ${ORIGIN_WORKSPACE}/task.env rsync-password.sh builder@${DUFFY_HOST}:${JENKINS_JOB_NAME}
            for repo in ci-pipeline sig-atomic-buildscripts; do
                rsync -Hrlptv --stats --delete -e ssh ${repo}/ builder@${DUFFY_HOST}:${JENKINS_JOB_NAME}/${repo}
            done
            
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
 * Library to setup the to configure the host to be configured the way we want
 *
 * variables
 *  stage - current stage running
 *  duffyKey - duffy file credential name stored in Jenkins credentials
 */
def checkLastImage(stage) {
    echo "Currently in stage: ${stage} in checkLastImage"

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
        exit
    '''
}