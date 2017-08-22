/**
 * Wrapper around calling the different stages
 */
def call(body) {

    def config = [:]
    body.resolveStrategy = Closure.DELEGATE_FIRST
    body.delegate = config
    body()

    try {
        // Set defaults
        env.MAIN_TOPIC = env.MAIN_TOPIC ?: 'org.centos.prod'
        env.MSG_PROVIDER = env.MSG_PROVIDER ?: 'fedora-fedmsg'
        env.FEDORA_PRINCIPAL = env.FEDORA_PRINCIPAL ?: 'bpeck/jenkins-continuous-infra.apps.ci.centos.org@FEDORAPROJECT.ORG'
        env.HTTP_BASE = env.HTTP_BASE ?: 'http://artifacts.ci.centos.org/artifacts/fedora-atomic'
        env.RSYNC_USER = env.RSYNC_USER ?: 'fedora-atomic'
        env.RSYNC_SERVER = env.RSYNC_SERVER ?: 'artifacts.ci.centos.org'
        env.RSYNC_DIR = env.RSYNC_DIR ?: 'fedora-atomic'
        env.basearch = env.basearch ?: 'x86_64'
        env.OSTREE_BRANCH = env.OSTREE_BRANCH ?: ''
        env.commit = env.commit ?: ''
        env.image2boot = env.image2boot ?: ''
        env.image_name = env.image_name ?: ''

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
        ostreeBootSanity {}
        ostreeAtomcHostTests {}
    } catch (err) {
        echo err.getMessage()
        throw err
    }
}