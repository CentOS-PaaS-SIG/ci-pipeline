#!/bin/sh -x

set -x

base_dir="$(pwd)"
mkdir -p $base_dir/logs

{ #group for tee

if [ "${branch}" = "rawhide" ]; then
    VERSION="rawhide"
else
    VERSION=$(echo $branch | sed -e 's/[a-zA-Z]*//')
fi

REF="fedora/${branch}/x86_64/atomic-host"

touch $base_dir/logs/ostree.props

if [[ ! -e $base_dir/ostree ]]; then
    mkdir $base_dir/ostree
    ostree --repo=$base_dir/ostree init --mode=archive-z2
fi

ostree --repo=$base_dir/ostree prune \
    --keep-younger-than='1 week ago' --refs-only

# get list of repos
repos=$(curl ${HTTP_BASE}/${RSYNC_BRANCH}/repo/manifest.txt | cut -d' ' -f1)

f_repos=""
for repo in $repos; do
    if [ -z "$f_repos" ];then
        f_repos="\"${repo}\""
    else
        f_repos="$f_repos, \"${repo}\""
    fi
    cat << EOF > $base_dir/ci-pipeline/config/ostree/${repo}.repo
[${repo}]
name=Testing ${repo}
baseurl=${HTTP_BASE}/${RSYNC_BRANCH}/repo/${repo}
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

cat << EOF > $base_dir/ci-pipeline/config/ostree/fedora-${VERSION}.repo
[fedora-${VERSION}]
name=Fedora ${branch}
failovermethod=priority
metalink=https://mirrors.fedoraproject.org/metalink?repo=${fedora_repo}&arch=x86_64
enabled=1
metadata_expire=7d
gpgcheck=0
skip_if_unavailable=False
EOF


if [ "$branch" != "rawhide" ]; then
    fedora_updates_repo="updates-released-${branch}"

cat << EOF > $base_dir/ci-pipeline/config/ostree/fedora-${VERSION}-updates.repo
[fedora-${VERSION}-updates]
name=Fedora ${VERSION} Updates
failovermethod=priority
metalink=https://mirrors.fedoraproject.org/metalink?repo=${fedora_updates_repo}&arch=x86_64
enabled=1
metadata_expire=7d
gpgcheck=0
skip_if_unavailable=False
EOF
fi

# Get our latest fedora-atomic-testing.json and fedora-atomic-host-base file and write it to $base_dir/logs/
curl -o $base_dir/logs/fedora-atomic-host.json https://pagure.io/fedora-atomic/raw/${branch}/f/fedora-atomic-host.json
curl -o $base_dir/logs/fedora-atomic-host-base.json https://pagure.io/fedora-atomic/raw/${branch}/f/fedora-atomic-host-base.json

cat << EOF > $base_dir/ci-pipeline/config/ostree/fedora-atomic-testing.json
{
    "include": "${base_dir}/logs/fedora-atomic-host.json",
    "ref": "fedora/${branch}/\${basearch}/atomic-host",
    "repos": ["fedora-${VERSION}"],
    "automatic_version_prefix": "${VERSION}",
    "mutate-os-release": "${VERSION}"
}
EOF

rpm-ostree compose tree --repo=$base_dir/ostree $base_dir/ci-pipeline/config/ostree/fedora-atomic-testing.json || exit 1

ostree --repo=$base_dir/ostree summary -u

if ostree --repo=$base_dir/ostree rev-parse ${REF}^ >/dev/null 2>&1; then
    rpm-ostree db --repo=$base_dir/ostree diff ${REF}{^,} | tee $base_dir/logs/packages.txt
fi

# Record the commit so we can test it later
commit=$(ostree --repo=$base_dir/ostree rev-parse ${REF})
ostree_version=$(ostree --repo=${base_dir}/ostree show --print-metadata-key=version $REF| sed -e "s/'//g")
ostree_shortsha=$(ostree --repo=${base_dir}/ostree rev-parse $REF| cut -c -15)
cat << EOF > $base_dir/logs/ostree.props
commit=$commit
ostree_version=$ostree_version
ostree_shortsha=$ostree_shortsha
imgname=fedora-atomic-$ostree_version-$ostree_shortsha
EOF

} 2>&1 | tee $base_dir/logs/console.log  #group for tee
