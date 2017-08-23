#!/bin/sh -x

set -x

base_dir="$(dirname $0)"

if [ "${branch}" = "rawhide" ]; then
    VERSION="rawhide"
else
    VERSION=$(echo $branch | sed -e 's/[a-zA-Z]*//')
fi

REF="fedora/${branch}/x86_64/atomic-host"

mkdir -p /home/output/logs
touch /home/output/logs/ostree.props

if [[ ! -e /home/output/ostree ]]; then
    mkdir /home/output/ostree
    ostree --repo=/home/output/ostree init --mode=archive-z2
fi

ostree --repo=/home/output/ostree prune \
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
    cat << EOF > $base_dir/config/ostree/${repo}.repo
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
cat << EOF > $base_dir/config/ostree/fedora-${VERSION}.repo
[fedora-${VERSION}]
name=Fedora ${branch}
failovermethod=priority
metalink=https://mirrors.fedoraproject.org/metalink?repo=${fedora_repo}&arch=x86_64
enabled=1
metadata_expire=7d
gpgcheck=0
skip_if_unavailable=False
EOF

cat << EOF > $base_dir/config/ostree/fedora-atomic-testing.json
{
    "include": "fedora-atomic-testing-docker-host.json",
    "ref": "fedora/${branch}/\${basearch}/atomic-host",
    "repos": ["fedora-${VERSION}", $f_repos],
    "automatic_version_prefix": "${VERSION}",
    "mutate-os-release": "${VERSION}"
}
EOF

rpm-ostree compose tree --repo=/home/output/ostree $base_dir/config/ostree/fedora-atomic-testing.json || exit 1

ostree --repo=/home/output/ostree summary -u

if ostree --repo=/home/output/ostree rev-parse ${REF}^ >/dev/null 2>&1; then
    rpm-ostree db --repo=/home/output/ostree diff ${REF}{^,} | tee /home/output/logs/packages.txt
fi

# Record the commit so we can test it later
commit=$(ostree --repo=/home/output/ostree rev-parse ${REF})
cat << EOF > /home/output/logs/ostree.props
commit=$commit
EOF