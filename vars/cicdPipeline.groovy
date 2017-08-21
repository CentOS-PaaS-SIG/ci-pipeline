import org.centos.Utils

def call(body) {

    def config = [:]
    body.resolveStrategy = Closure.DELEGATE_FIRST
    body.delegate = config
    body()

    try {
        env.basearch = "x86_64"

        // Set defaults
        if ((env.MAIN_TOPIC == null) || ("${env.MAIN_TOPIC}" == "")) {
            env.MAIN_TOPIC = "org.centos.prod"
        }
        if ((env.MSG_PROVIDER == null) || ("${env.MSG_PROVIDER}" == "")) {
            env.MSG_PROVIDER = "fedora-fedmsg"
        }
        if (env.OSTREE_BRANCH == null) {
            env.OSTREE_BRANCH = ""
        }
        if (env.commit == null) {
            env.commit = ""
        }
        if (env.image2boot == null) {
            env.image2boot = ""
        }

        // SCM
        dir('ci-pipeline') {
            git 'https://github.com/CentOS-PaaS-SIG/ci-pipeline'
        }
        dir('cciskel') {
            git 'https://github.com/cgwalters/centos-ci-skeleton'
        }
        dir('sig-atomic-buildscripts') {
            git 'https://github.com/CentOS/sig-atomic-buildscripts'
        }

        rpmBuild {}
        ostreeCompose {}
        ostreeImageCompose {}
        ostreeImageBootSanity {}
        ostreeImageBootSanity {}
        ostreeAtomcHostTests {}
    } catch (err) {
        echo err.getMessage()
        throw err
    }
}