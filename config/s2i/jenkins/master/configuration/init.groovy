import java.util.logging.Logger
import jenkins.security.s2m.*
import jenkins.model.*;
import com.redhat.jenkins.plugins.ci.*
import com.redhat.jenkins.plugins.ci.messaging.*
import hudson.markup.RawHtmlMarkupFormatter
import hudson.model.*
import hudson.security.*
import hudson.model.ListView

def logger = Logger.getLogger("")
logger.info("Disabling CLI over remoting")
jenkins.CLI.get().setEnabled(false);
logger.info("Enable Slave -> Master Access Control")
Jenkins.instance.injector.getInstance(AdminWhitelistRule.class).setMasterKillSwitch(false);
Jenkins.instance.save()

// Set global and job read permissions
def strategy = Jenkins.instance.getAuthorizationStrategy()
strategy.add(hudson.model.Hudson.READ,'anonymous')
strategy.add(hudson.model.Item.READ,'anonymous')
Jenkins.instance.setAuthorizationStrategy(strategy)
// Set Markup Formatter to Safe HTML so PR hyperlinks work
Jenkins.instance.setMarkupFormatter(new RawHtmlMarkupFormatter(false))
Jenkins.instance.save()

logger.info("Setup fedora-fedmsg Messaging Provider")
FedMsgMessagingProvider fedmsg = new FedMsgMessagingProvider("fedora-fedmsg", "tcp://hub.fedoraproject.org:9940", "tcp://172.19.4.24:9941", "org.fedoraproject");
GlobalCIConfiguration.get().addMessageProvider(fedmsg)

logger.info("Setup fedora-fedmsg-stage Messaging Provider")
FedMsgMessagingProvider fedmsgStage = new FedMsgMessagingProvider("fedora-fedmsg-stage", "tcp://stg.fedoraproject.org:9940", "tcp://172.19.4.36:9941", "org.fedoraproject");
GlobalCIConfiguration.get().addMessageProvider(fedmsgStage)

logger.info("Setup fedora-fedmsg-devel Messaging Provider")
FedMsgMessagingProvider fedmsgDevel = new FedMsgMessagingProvider("fedora-fedmsg-devel", "tcp://fedmsg-relay.continuous-infra.svc:4001", "tcp://fedmsg-relay.continuous-infra.svc:2003", "org.fedoraproject");
GlobalCIConfiguration.get().addMessageProvider(fedmsgDevel)

logger.info("Setting Time Zone to be EST")
System.setProperty('org.apache.commons.jelly.tags.fmt.timeZone', 'America/New_York')

// Add views
// get Jenkins instance
Jenkins jenkins = Jenkins.getInstance()

// variables
def ciPipelineViewName = 'CI Pipeline'
def ciStagePipelineViewName = 'CI Stage Pipeline'
def linchpinViewName = 'Linchpin'
def allpkgsViewName = 'Fedora All Packages Pipeline'

// create the new view
jenkins.addView(new ListView(ciPipelineViewName))
jenkins.addView(new ListView(ciStagePipelineViewName))
jenkins.addView(new ListView(linchpinViewName))
jenkins.addView(new ListView(allpkgsViewName))

// get the view
ciPipelineView = hudson.model.Hudson.instance.getView(ciPipelineViewName)
ciStagePipelineView = hudson.model.Hudson.instance.getView(ciStagePipelineViewName)
linchpinView = hudson.model.Hudson.instance.getView(linchpinViewName)
allpkgsView = hudson.model.Hudson.instance.getView(allpkgsViewName)

// add a job by its name
ciPipelineView.doAddJobToView('continuous-infra/ci-pipeline-f26')
ciPipelineView.doAddJobToView('continuous-infra/ci-pipeline-f27')
ciPipelineView.setIncludeRegex('^ci-pipeline.*')

ciStagePipelineView.setIncludeRegex('^ci-stage-pipeline.*')

linchpinView.setIncludeRegex('^ci-linchpin.*')

allpkgsView.doAddJobToView('upstream-fedora-pipeline-gc')
allpkgsView.setIncludeRegex('^fedora-.*')

// save current Jenkins state to disk
jenkins.save()
