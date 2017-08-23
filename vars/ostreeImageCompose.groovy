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
    def current_stage = 'ostree-image-compose'

    try {
        stage(current_stage) {
            // Change display
            currentBuild.displayName = "Build#: ${env.BUILD_NUMBER} - Branch: ${env.branch} - Package: ${env.fed_repo}"
            currentBuild.description = "Stage: ${current_stage}"

            // Set groovy and env vars
            // Check if a new ostree image compose is needed
            if (fileExists("${env.WORKSPACE}/NeedNewImage.txt") || ("${env.GENERATE_IMAGE}" == "true")) {
                env.task = "./ci-pipeline/tasks/ostree-image-compose"
                env.playbook = "ci-pipeline/playbooks/rdgo-setup.yml"
                env.ANSIBLE_HOST_KEY_CHECKING = "False"

                // Send message org.centos.prod.ci.pipeline.image.running on fedmsg
                (topic, messageProperties, messageContent) = pipelineUtils.setMessageFields('image.running')
                env.topic = topic
                messageUtils.sendMessage([topic:"${env.topic}",
                                        provider:"${env.MSG_PROVIDER}",
                                        msgType:'custom',
                                        msgProps:messageProperties,
                                        msgContent:messageContent])

                // Provision resources
                env.DUFFY_OP = "--allocate"
                utils.duffyCciskel([stage:current_stage, duffyKey:'duffy-key', duffyOps:env.DUFFY_OP])

                echo "Duffy Allocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                     "ORIGIN_WORKSPACE=${env.ORIGIN_WORKSPACE}\r\n" +
                     "ORIGIN_BUILD_TAG=${env.ORIGIN_BUILD_TAG}\r\n" +
                     "ORIGIN_CLASS=${env.ORIGIN_CLASS}"

                def job_props = "${env.ORIGIN_WORKSPACE}/job.props"
                def job_props_groovy = utils.convertProps(job_props)
                load(job_props_groovy)

                // Stage resources - ostree image compose
                pipelineUtils.setupStage(current_stage, 'fedora-atomic-key')

                // Rsync Data - ostree image compose
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
                pipelineUtils.rsyncResults(current_stage, 'duffy-key')

                ostree_props = "${env.ORIGIN_WORKSPACE}/logs/ostree.props"
                def ostree_props_groovy = utils.convertProps(ostree_props)
                load(ostree_props_groovy)


            } else {
                echo "Not Generating a New Image"
            }
        }
    } catch (err) {
        echo "Error: Exception from " + current_stage + ":"
        echo err.getMessage()
        throw err
    } finally {
        if (fileExists("${env.WORKSPACE}/NeedNewImage.txt") || ("${env.GENERATE_IMAGE}" == "true")) {
            // Teardown resources
            env.DUFFY_OP = "--teardown"
            echo "Duffy Deallocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                 "RSYNC_PASSWORD=${env.RSYNC_PASSWORD}\r\n" +
                 "DUFFY_HOST=${env.DUFFY_HOST}"
            utils.duffyCciskel([stage: current_stage, duffyKey: 'duffy-key', duffyOps: env.DUFFY_OP])

            // Set Message Fields
            (topic, messageProperties, messageContent) = pipelineUtils.setMessageFields('image.complete')
            env.topic = topic
            // Send message org.centos.prod.ci.pipeline.image.complete on fedmsg
            messageUtils.sendMessage([topic     : "${env.topic}",
                                      provider  : "${env.MSG_PROVIDER}",
                                      msgType   : 'custom',
                                      msgProps  : messageProperties,
                                      msgContent: messageContent])
            env.MSG_PROPS = messageProperties
            env.MSG_CONTENTS = messageContent
        }
    }
}