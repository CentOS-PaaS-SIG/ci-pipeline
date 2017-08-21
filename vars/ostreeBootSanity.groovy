import org.centos.Utils
import org.centos.pipeline.PipelineUtils

def call(body) {

    def config = [:]
    body.resolveStrategy = Closure.DELEGATE_FIRST
    body.delegate = config
    body()

    def getUtils = new Utils()
    def getPipelineUtils = new PipelineUtils()
    def getMessage = new Messaging()
    def current_stage = 'ostree-boot-sanity'

    try {
        stage(current_stage) {
            // Change display
            currentBuild.displayName = "Build#: ${env.BUILD_NUMBER} - Branch: ${env.branch} - Package: ${env.fed_repo}"
            currentBuild.description = "Stage: ${current_stage}"

            // Set groovy and env vars
            env.task = "./ci-pipeline/tasks/ostree-boot-image"
            env.playbook = "ci-pipeline/playbooks/system-setup.yml"

            // Provision resources
            env.DUFFY_OP = "--allocate"
            getUtils.duffyCciskel([stage:current_stage, duffyKey:'duffy-key', duffyOps:env.DUFFY_OP])

            echo "Duffy Allocate ran for stage ${current_stage} with option ${env.DUFFY_OP}\r\n" +
                    "ORIGIN_WORKSPACE=${env.ORIGIN_WORKSPACE}\r\n" +
                    "ORIGIN_BUILD_TAG=${env.ORIGIN_BUILD_TAG}\r\n" +
                    "ORIGIN_CLASS=${env.ORIGIN_CLASS}"

            def job_props = "${env.ORIGIN_WORKSPACE}/job.props"
            def job_props_groovy = getUtils.convertProps(job_props)
            load(job_props_groovy)

            // Stage resources - ostree boot sanity
            getPipelineUtils.setupStage(current_stage, 'fedora-atomic-key')

            // Rsync Data - ostree boot sanity
            writeFile file: "${env.ORIGIN_WORKSPACE}/task.env",
                    text: "export branch=\"${branch}\"\n" +
                            "export fed_repo=\"${fed_repo}\"\n" +
                            "export image2boot=\"${image2boot}\"\n" +
                            "export commit=\"${commit}\"\n" +
                            "export JENKINS_JOB_NAME=\"${JOB_NAME}-${current_stage}\"\n" +
                            "export JENKINS_BUILD_TAG=\"${BUILD_TAG}-${current_stage}\"\n" +
                            "export OSTREE_BRANCH=\"${OSTREE_BRANCH}\"\n" +
                            "export ANSIBLE_HOST_KEY_CHECKING=\"False\"\n"

            getPipelineUtils.rsyncResults(current_stage, 'duffy-key')

            // Set Message Fields
            env.topic = "${MAIN_TOPIC}.ci.pipeline.compose.test.integration.queued"
            messageProperties = "topic=${topic}\n" +
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
                    "status=${currentBuild.currentResult}"
            messageContent = ''
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
        getUtils.duffyCciskel([stage:current_stage, duffyKey:'duffy-key', duffyOps:env.DUFFY_OP])

        // Send message org.centos.prod.ci.pipeline.compose.test.integration.queued on fedmsg
        env.topic = "${env.MAIN_TOPIC}.ci.pipeline.compose.test.integration.queued"
        getMessage.sendMessage([topic:"${env.topic}",
                                provider:"${env.MSG_PROVIDER}",
                                msgType:'custom',
                                msgProps:messageProperties,
                                msgContent:messageContent])
        env.MSG_PROPS = messageProperties
        env.MSG_CONTENTS = messageContent
    }
}