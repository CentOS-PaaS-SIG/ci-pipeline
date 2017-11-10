import org.centos.pipeline.PipelineUtils
import org.centos.Utils

/**
 * A class of methods used in the Jenkinsfile pipeline.
 * These methods are wrappers around methods in the ci-pipeline library.
 */
class pipelineUtils implements Serializable {

    def pipelineUtils = new PipelineUtils()
    def utils = new Utils()

    /**
     * Method to setup and configure the host the way ci-pipeline requires
     *
     * @param stage Current stage
     * @param sshKey Name of ssh key to use
     * @return
     */
    def setupStage(String stage, String sshKey) {
        pipelineUtils.setupStage(stage, sshKey)
    }

    /**
     * Method to to check last image modified time
     * @param stage Current stage
     * @return
     */
    def checkLastImage(String stage) {
        pipelineUtils.checkLastImage(stage)
    }

    /**
     * Method to to find RSYNC_BRANCH to use on artifacts server
     * @return
     */
    def getRsyncBranch() {
        pipelineUtils.getRsyncBranch()
    }

    /**
     * Method to set message fields to be published
     * @param messageType ${MAIN_TOPIC}.ci.pipeline.<defined-in-README>
     * @return
     */
    def setMessageFields(String messageType) {
        pipelineUtils.setMessageFields(messageType)
    }

    /**
     * Method to send message
     * @param msgProps The message properties in key=value form, one key/value per line ending in '\n'
     * @param msgContent Message content.
     * @return
     */
    def sendMessage(String msgProps, String msgContent) {
        pipelineUtils.sendMessage(msgProps, msgContent)
    }

    /**
     * Method to send message and store an audit
     * @param msgProps The message properties in key=value form, one key/value per line ending in '\n'
     * @param msgContent Message content.
     * @param msgAuditFile - File containing all past messages. It will get appended to.
     * @param fedmsgRetryCount number of times to keep trying.
     * @return
     */
    def sendMessageWithAudit(String msgProps, String msgContent, String msgAuditFile, fedmsgRetryCount) {
        pipelineUtils.sendMessageWithAudit(msgProps, msgContent, msgAuditFile, fedmsgRetryCount)
    }

    /**
     * Method to parse message and inject its key/value pairs as env variables.
     * @param message message from dist-git to parse
     * @return
     */
    def injectFedmsgVars(String message) {
        pipelineUtils.injectFedmsgVars(message)
    }

    /**
     * Method to set default environmental variables. Performed once at start of Jenkinsfile
     * @param envMap Key/value pairs which will be set as environmental variables.
     * @return
     */
    def setDefaultEnvVars(Map envMap = null) {
        pipelineUtils.setDefaultEnvVars(envMap)
    }

    /**
     * Method to set stage specific environmental variables.
     * @param stage Current stage
     * @return
     */
    def setStageEnvVars(String stage) {
        pipelineUtils.setStageEnvVars(stage)
    }

    /**
     * Method to create a text string which is written to the file 'task.env' in the {env.ORIGIN_WORKSPACE} and call
     * runTaskAndReturnLogs()
     * @param stage Current stage
     * @return
     */
    def rsyncData(String stage) {
        pipelineUtils.rsyncData(stage)
    }

    /**
     * Method to provision resources used in the stage
     * @param stage Current stage
     * @return
     */
    def provisionResources(String stage) {
        pipelineUtils.provisionResources(stage)
    }

    /**
     * Method to teardown resources used in the stage
     * @param stage Current stage
     * @return
     */
    def teardownResources(String stage) {
        pipelineUtils.teardownResources(stage)
    }

    /**
     *
     * @param openshiftProject name of openshift namespace/project.
     * @param nodeName podName we are going to get container logs from.
     * @return
     */
    def getContainerLogsFromPod(String openshiftProject, String nodeName) {
        pipelineUtils.getContainerLogsFromPod(openshiftProject, nodeName)
    }

    def verifyPod(openshiftProject, nodeName) {
        pipelineUtils.verifyPod(openshiftProject, nodeName)
    }

    def prepareCredentials() {
        pipelineUtils.prepareCredentials()
    }

    def executeInContainer(stageName, containerName, script) {
        pipelineUtils.executeInContainer(stageName, containerName, script)
    }

    /**
     * Method to prepend 'env.' to the keys in source file and write them in a format of env.key=value in the destination file.
     * @param sourceFile The file to read from
     * @param destinationFile The file to write to
     * @return
     */
    def convertProps(String sourceFile, String destinationFile) {
        utils.convertProps(sourceFile, destinationFile)
    }

    /**
     * Send comment to GH about image operations.
     * @param imageOperationsList list of image operation messages
     * @return
     */
    def sendPRCommentforTags(imageOperationsList) {
        pipelineUtils.sendPRCommentforTags(imageOperationsList)
    }

    /**
     * info about tags to be used
     * @param map
     */
    def printLabelMap(map) {
        pipelineUtils.printLabelMap(map)
    }

    /**
     * Setup container templates in openshift
     * @param openshiftProject Openshift Project
     * @return
     */
    def setupContainerTemplates(String openshiftProject) {
        return pipelineUtils.setupContainerTemplates(openshiftProject)
    }

    /**
     * Build image in openshift
     * @param openshiftProject Openshift Project
     * @param buildConfig
     * @return
     */
    def buildImage(String openshiftProject, String buildConfig) {
        return pipelineUtils.buildImage(openshiftProject, buildConfig)
    }

    /**
     * Build stable image in openshift
     * @param openshiftProject Openshift Project
     * @param buildConfig
     * @return
     */
    def buildStableImage(String openshiftProject, String buildConfig) {
        return pipelineUtils.buildStableImage(openshiftProject, buildConfig)
    }

    /**
     * Using the currentBuild, get a string representation
     * of the changelog.
     * @return String of changelog
     */
    @NonCPS
    def getChangeLogFromCurrentBuild() {
        pipelineUtils.getChangeLogFromCurrentBuild()
    }

    /**
     * Sets the Build displayName and Description based on whether it
     * is a PR or a prod run.
     */
    def setBuildDisplayAndDescription() {
        pipelineUtils.setBuildDisplayAndDescription()
    }

    /**
     * Update the Build displayName and Description based on whether it
     * is a PR or a prod run.
     * Used at start of pipeline to decorate the build with info
     */
    def updateBuildDisplayAndDescription() {
        pipelineUtils.updateBuildDisplayAndDescription()
    }

/**
 * Check data grepper for presence of a message
 * @param messageID message ID to track.
 * @param retryCount number of times to keep trying.
 * @return
 */
    def trackMessage(String messageID, int retryCount) {
        pipelineUtils.trackMessage(messageID, retryCount)
    }

    /**
     * Initialize message audit file
     * @param auditFile audit file for messages
     * @return
     */
    def initializeAuditFile(String auditFile) {
        pipelineUtils.initializeAuditFile(auditFile)
    }

/**
 * Watch for messages
 * @param msg_provider jms-messaging message provider
 * @param message trigger message
 */
    def watchForMessages(String msg_provider, String message) {
        pipelineUtils.watchForMessages(msg_provider, message)
    }

/**
 *
 * @param nick nickname to connect to IRC with
 * @param channel channel to connect to
 * @param message message to send
 * @param ircServer optional IRC server defaults to irc.freenode.net:6697
 * @return
 */
    def sendIRCNotification(String nick, String channel, String message, String ircServer="irc.freenode.net:6697") {
        pipelineUtils.sendIRCNotification(nick, channel, message, ircServer)
    }

}
