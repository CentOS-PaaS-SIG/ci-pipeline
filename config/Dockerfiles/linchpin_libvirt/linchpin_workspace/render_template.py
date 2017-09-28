#!/usr/bin/env python
import os
import sys
import jinja2
import subprocess

def render(tpl_path, context):
    path, filename = os.path.split(tpl_path)
    return jinja2.Environment(
        loader=jinja2.FileSystemLoader(path or './')
    ).get_template(filename).render(context)

def write_to_file(tpl_str, dest):
    open(dest, "w").write(tpl_str)
    return sys.exit(0)


context = {
    'IMAGE_URL': os.getenv('IMAGE_URL', default="https://pubmirror2.math.uh.edu/fedora-buffet/alt/atomic/stable/Fedora-Atomic-25-20170705.0/CloudImages/x86_64/images/Fedora-Atomic-25-20170705.0.x86_64.qcow2"),
}
result = render('/linchpin_workspace/linchpin_templates/example-topology.yml.j2',context)
write_to_file(result, '/linchpin_workspace/linchpin_workspace/topologies/example-topology.yml')
