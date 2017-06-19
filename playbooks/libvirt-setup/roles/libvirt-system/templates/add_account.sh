useradd -m -p '{{ item.value.admin_passwd }}' -G wheel admin
mkdir -p /home/admin/.ssh
cat <<'EOF' >> /home/admin/.ssh/authorized_keys
{{ item.value.admin_ssh_rsa }}
EOF
chown -R admin:admin /home/admin/.ssh
chmod -R 0700 /home/admin/.ssh
