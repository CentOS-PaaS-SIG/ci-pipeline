#!/bin/sh -x

set -x

CURRENTDIR=$(pwd)
if [ ${CURRENTDIR} == "/" ] ; then
    cd /home
    CURRENTDIR=/home
fi

base_dir="$(dirname $0)"

if [ "${branch}" = "rawhide" ]; then
    VERSION="rawhide"
else
    VERSION=$(echo $branch | sed -e 's/[a-zA-Z]*//')
fi

REF="fedora/${branch}/x86_64/atomic-host"

LOGDIR=${CURRENTDIR}/logs
mkdir -p "${LOGDIR}"
touch "${LOGDIR}/ostree.props"

mkdir -p $CURRENTDIR/config/ostree

if [[ ! -e $CURRENTDIR/output/ostree ]]; then
    mkdir -p $CURRENTDIR/output/ostree
    ostree --repo=$CURRENTDIR/output/ostree init --mode=archive-z2
fi

ostree --repo=$CURRENTDIR/output/ostree prune \
    --keep-younger-than='1 week ago' --refs-only

# get list of repos
repos=$(curl ${HTTP_BASE}/${branch}/repo/manifest.txt | cut -d' ' -f1)

f_repos=""
for repo in $repos; do
    if [ -z "$f_repos" ];then
        f_repos="\"${repo}\""
    else
        f_repos="$f_repos, \"${repo}\""
    fi
    cat << EOF > $CURRENTDIR/config/ostree/${repo}.repo
[${repo}]
name=Testing ${repo}
baseurl=${HTTP_BASE}/${branch}/repo/${repo}
enabled=1
gpgcheck=0
skip_if_unavailable=False
EOF
done

if [ "$VERSION" = "rawhide" ]; then
    fedora_repo="$VERSION"
else
    fedora_repo="fedora-$VERSION"
fi
cat << EOF > $CURRENTDIR/config/ostree/fedora-${VERSION}.repo
[fedora-${VERSION}]
name=Fedora ${branch}
failovermethod=priority
metalink=https://mirrors.fedoraproject.org/metalink?repo=${fedora_repo}&arch=x86_64
enabled=1
metadata_expire=7d
gpgcheck=0
skip_if_unavailable=False
EOF

cat << EOF > $CURRENTDIR/config/ostree/fedora-atomic-testing.json
{
    "include": "fedora-atomic-testing-docker-host.json",
    "ref": "fedora/${branch}/\${basearch}/atomic-host",
    "repos": ["fedora-${VERSION}", $f_repos],
    "automatic_version_prefix": "${VERSION}",
    "mutate-os-release": "${VERSION}"
}
EOF

ls -lR $CURRENTDIR/

rpm-ostree compose tree --repo=$CURRENTDIR/output/ostree $CURRENTDIR/config/ostree/fedora-atomic-testing.json || exit 1

ostree --repo=$CURRENTDIR/output/ostree summary -u

if ostree --repo=$CURRENTDIR/output/ostree rev-parse ${REF}^ >/dev/null 2>&1; then
    rpm-ostree db --repo=$CURRENTDIR/output/ostree diff ${REF}{^,} | tee ${LOGDIR}/packages.txt
fi

# Record the commit so we can test it later
commit=$(ostree --repo=$CURRENTDIR/output/ostree rev-parse ${REF})
cat << EOF > ${LOGDIR}/ostree.props
commit=$commit
EOF