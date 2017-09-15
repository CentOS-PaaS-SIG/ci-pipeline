import org.centos.pipeline.PipelineUtils

class pipelineUtils implements Serializable {

    def pipelineUtils = new PipelineUtils()

    def setupStage(stage, sshKey) {
        pipelineUtils.setupStage(stage, sshKey)
    }

    def checkLastImage(stage) {
        pipelineUtils.checkLastImage(stage)
    }

    def checkImageLastModifiedTime(stage) {
        pipelineUtils.checkImageLastModifiedTime(stage)
    }

    def setMessageFields(messageType) {
        pipelineUtils.setMessageFields(messageType)
    }

    def sendMessage(msgProps, msgContent) {
        pipelineUtils.sendMessage(msgProps, msgContent)
    }

    def injectFedmsgVars() {
        pipelineUtils.injectFedmsgVars()
    }

    def setDefaultEnvVars(envMap = null) {
        pipelineUtils.setDefaultEnvVars(envMap)
    }

    def setStageEnvVars(stage) {
        pipelineUtils.setStageEnvVars(stage)
    }

    def rsyncData(stage) {
        pipelineUtils.rsyncData(stage)
    }

    def verifyPod(openshiftProject, nodeName) {
        pipelineUtils.verifyPod(openshiftProject, nodeName)
    }

    def provisionResources(stage) {
        pipelineUtils.provisionResources(stage)
    }

    def prepareCredentials() {
        pipelineUtils.prepareCredentials()
    }
    def executeInContainer(stageName, containerName, script) {
        pipelineUtils.executeInContainer(stageName, containerName, script)
    }

    def teardownResources(stage) {
        pipelineUtils.teardownResources(stage)
    }

    def convertProps(file1, file2) {
        pipelineUtils.convertProps(file1, file2)
    }
}