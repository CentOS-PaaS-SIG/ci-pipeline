#!/bin/bash
set -ex

if [ -z "${imageName}" ]; then
    echo "imageName variable not provided. Exiting..."
    exit 1
fi

if [ -z "${increase}" ]; then
    echo "increase variable not provided. Exiting..."
    exit 1
fi

if [ -z "${partition}" ]; then
    # Resize the partition with biggest filesystem
    partition=$(LIBGUESTFS_BACKEND=direct virt-filesystems --partitions --long -a ${imageName} | grep partition | sort -nk4 | tail -n 1 | awk '{print$1}')
fi

qemu-img resize ${imageName} +${increase}

cp ${imageName} orig_${imageName}

LIBGUESTFS_BACKEND=direct virt-resize --expand ${partition} orig_${imageName} ${imageName}

qemu-img check ${imageName}

rm -f orig_${imageName}

# Compresss qcow2
qemu-img convert -c -O qcow2 ${imageName} compressed_${imageName}

qemu-img check compressed_${imageName}

mv -f compressed_${imageName} ${imageName}

qemu-img info ${imageName}
