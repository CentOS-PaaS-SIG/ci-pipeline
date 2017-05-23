# Fedora Atomic is a cloud-focused spin implementing the Project
# Atomic patterns.  Note that this replicates the same tree which can
# now be installed on bare metal.

# This image allocates most space to an LVM-managed thin pool
# dedicated for Docker containers, and uses docker-storage-setup to
# dynamically resize storage on boot.

text # don't use cmdline -- https://github.com/rhinstaller/anaconda/issues/931
lang en_US.UTF-8
keyboard us
timezone --utc Etc/UTC

auth --useshadow --passalgo=sha512
selinux --enforcing
rootpw --lock --iscrypted locked

firewall --disabled

bootloader --timeout=1 --append="no_timer_check console=tty1 console=ttyS0,115200n8 net.ifnames=0"

network --bootproto=dhcp --device=link --activate --onboot=on
services --enabled=sshd,cloud-init,cloud-init-local,cloud-config,cloud-final

zerombr
clearpart --all
# Atomic differs from cloud - we want LVM
part /boot --size=300 --fstype="ext4"
part pv.01 --grow
volgroup atomicos pv.01
logvol / --size=3000 --fstype="xfs" --name=root --vgname=atomicos

# Equivalent of %include fedora-repo.ks
ostreesetup --nogpg --osname=fedora-atomic --remote=fedora-atomic --url=https://kojipkgs.fedoraproject.org/compose/atomic/26/ --ref=fedora/26/x86_64/atomic-host

reboot

%post --erroronfail
# See https://github.com/projectatomic/rpm-ostree/issues/42
# we only need this for before f26 release where we are using a
# temporary "dev" repo url above. We want to change the remote
# we use to match where the repo will live for the entirety of f26.
ostree remote delete fedora-atomic
ostree remote add --set=gpg-verify=false fedora-atomic 'https://kojipkgs.fedoraproject.org/atomic/26/'

# older versions of livecd-tools do not follow "rootpw --lock" line above
# https://bugzilla.redhat.com/show_bug.cgi?id=964299
passwd -l root

# Work around https://bugzilla.redhat.com/show_bug.cgi?id=1193590
cp /etc/skel/.bash* /var/roothome

# Configure docker-storage-setup to resize the partition table on boot
# https://github.com/projectatomic/docker-storage-setup/pull/25
echo 'GROWPART=true' >> /etc/sysconfig/docker-storage-setup

echo -n "Getty fixes"
# although we want console output going to the serial console, we don't
# actually have the opportunity to login there. FIX.
# we don't really need to auto-spawn _any_ gettys.
sed -i '/^#NAutoVTs=.*/ a\
NAutoVTs=0' /etc/systemd/logind.conf

echo -n "Network fixes"
# initscripts don't like this file to be missing.
cat > /etc/sysconfig/network << EOF
NETWORKING=yes
NOZEROCONF=yes
EOF

# For cloud images, 'eth0' _is_ the predictable device name, since
# we don't want to be tied to specific virtual (!) hardware
rm -f /etc/udev/rules.d/70*
ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules

# simple eth0 config, again not hard-coded to the build hardware
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << EOF
DEVICE="eth0"
BOOTPROTO="dhcp"
ONBOOT="yes"
TYPE="Ethernet"
PERSISTENT_DHCLIENT="yes"
EOF

# generic localhost names
cat > /etc/hosts << EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

EOF
echo .


# Because memory is scarce resource in most cloud/virt environments,
# and because this impedes forensics, we are differing from the Fedora
# default of having /tmp on tmpfs.
echo "Disabling tmpfs for /tmp."
systemctl mask tmp.mount

# make sure firstboot doesn't start
echo "RUN_FIRSTBOOT=NO" > /etc/sysconfig/firstboot

# Uncomment this if you want to use cloud init but suppress the creation
# of an "ec2-user" account. This will, in the absence of further config,
# cause the ssh key from a metadata source to be put in the root account.
#cat <<EOF > /etc/cloud/cloud.cfg.d/50_suppress_ec2-user_use_root.cfg
#users: []
#disable_root: 0
#EOF

echo "Removing random-seed so it's not the same in every image."
rm -f /var/lib/systemd/random-seed

echo "Packages within this cloud image:"
echo "-----------------------------------------------------------------------"
rpm -qa
echo "-----------------------------------------------------------------------"
# Note that running rpm recreates the rpm db files which aren't needed/wanted
rm -f /var/lib/rpm/__db*

echo "Zeroing out empty space."
# This forces the filesystem to reclaim space from deleted files
dd bs=1M if=/dev/zero of=/var/tmp/zeros || :
rm -f /var/tmp/zeros
echo "(Don't worry -- that out-of-space error was expected.)"

# For trac ticket https://pagure.io/atomic-wg/issue/128
rm -f /etc/sysconfig/network-scripts/ifcfg-ens3

echo "Adding Developer Mode GRUB2 menu item."
/usr/libexec/atomic-devmode/bootentry add

# Disable network service here, as doing it in the services line
# fails due to RHBZ #1369794
/sbin/chkconfig network off

# Anaconda is writing an /etc/resolv.conf from the install environment.
# The system should start out with an empty file, otherwise cloud-init
# will try to use this information and may error:
# https://bugs.launchpad.net/cloud-init/+bug/1670052
truncate -s 0 /etc/resolv.conf

# Disable rhgb/quiet: https://bugzilla.redhat.com/show_bug.cgi?id=510523
# See also https://github.com/projectatomic/rpm-ostree/issues/594
for x in /boot/loader/entries/*.conf; do
    sed -i 's/rhgb quiet//' $x
done
grub2-mkconfig > /boot/loader/grub.cfg.new && mv /boot/loader/grub.cfg{.new,}

%end
