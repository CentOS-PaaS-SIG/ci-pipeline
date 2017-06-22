import java.util.logging.Logger
import jenkins.security.s2m.*
import jenkins.model.*;
import com.redhat.jenkins.plugins.ci.*
import com.redhat.jenkins.plugins.ci.messaging.*

def logger = Logger.getLogger("")
logger.info("Disabling CLI over remoting")
jenkins.CLI.get().setEnabled(false);
logger.info("Enable Slave -> Master Access Control")
Jenkins.instance.injector.getInstance(AdminWhitelistRule.class).setMasterKillSwitch(false);
Jenkins.instance.save()

logger.info("Setting Time Zone to be EST")
System.setProperty('org.apache.commons.jelly.tags.fmt.timeZone', 'America/New_York')

logger.info("Setup fedora-fedmsg Messaging Provider")
FedMsgMessagingProvider fedmsg = new FedMsgMessagingProvider("fedora-fedmsg", "tcp://hub.fedoraproject.org:9940", "tcp://hub.fedoraproject.org:9940", "org.fedoraproject");
try {
  GlobalCIConfiguration.get().addMessageProvider(fedmsg)
} catch (Exception e) {
  logger.info(e.getMessage())
}

