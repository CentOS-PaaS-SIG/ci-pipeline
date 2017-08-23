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
    def current_stage = 'atomic-host-tests'

    try {
        stage(current_stage) {
            // Change display
            currentBuild.displayName = "Build#: ${env.BUILD_NUMBER} - Branch: ${env.branch} - Package: ${env.fed_repo}"
            currentBuild.description = "Stage: ${current_stage}"
            // Set groovy and env vars
            env.task = "./ci-pipeline/tasks/atomic-host-tests"
            env.playbook = "ci-pipeline/playbooks/system-setup.yml"

            // Send integration test running message on fedmsg
            (topic, messageProperties, messageContent) = pipelineUtils.setMessageFields('test.integration.running')
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

            def job_props  = "${env.ORIGIN_WORKSPACE}/job.props"
            def job_props_groovy = utils.convertProps(job_props)
            load(job_props_groovy)

            // Run Setup - atomic host tests
            pipelineUtils.setupStage(current_stage, 'fedora-atomic-key')

            step([$class: 'XUnitBuilder',
                 thresholds: [[$class: 'FailedThreshold', unstableThreshold: '1']],
                 tools: [[$class: 'JUnitType', pattern: "**/**/*.xml"]]]
            )
        }
    } catch (err) {
        echo "Error: Exception from " + current_stage + ":"
        echo err.getMessage()
        throw err
    } finally {
        // Teardown resources
        env.DUFFY_OP = "--teardown"
        echo "Duffy Deallocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                "RSYNC_PASSWORD=${env.RSYNC_PASSWORD}\r\n" +
                "DUFFY_HOST=${env.DUFFY_HOST}"
        utils.duffyCciskel([stage:current_stage, duffyKey:'duffy-key', duffyOps:env.DUFFY_OP])

        // Set Message Fields
        (topic, messageProperties, messageContent) = pipelineUtils.setMessageFields('test.integration.complete')
        env.topic = topic
        // Send message org.centos.prod.ci.pipeline.compose.test.integration.complete on fedmsg
        messageUtils.sendMessage([topic:"${env.topic}",
                                  provider:"${env.MSG_PROVIDER}",
                                  msgType:'custom',
                                  msgProps:messageProperties,
                                  msgContent:messageContent])
        env.MSG_PROPS = messageProperties
        env.MSG_CONTENTS = messageContent
    }
}