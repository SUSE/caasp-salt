import logging
import subprocess

import salt.log

log = logging.getLogger(__name__)

def caasp_containers():
    # NOTE: containers that are not running will have an entry in
    #       the "containers" dictionary anyway, but it will be empty:
    #       this way we can check if the value is empty (easy) instead of
    #       a missing key in a grain dictionary (hard).
    containers = {
        'haproxy': '',
        'velum': ''
    }

    try:
        domain = __pillar__["internal_infra_domain"]
        regexp = "k8s_haproxy.*\." + domain.replace(".", "\.") + "_kube-system_"
        cmd = "docker ps | grep -E '{}' | awk '{print $1}'".format(regexp)
        log.debug('Getting haproxy container: {}'.format(cmd))
        out = subprocess.check_output([cmd], shell=True).strip(" \n\t")
        log.debug('output: {}'.format(out))
        containers['haproxy'] = out
    except subprocess.CalledProcessError as e:
        log.debug("haproxy container not running: " + e.output)

    try:
        cmd = "docker ps | grep 'velum-dashboard' | awk '{print $1}'"
        log.debug('Getting velum container: {}'.format(cmd))
        out = subprocess.check_output([cmd], shell=True).strip(" \n\t")
        log.debug('output: {}'.format(out))
        containers['velum'] = out
    except subprocess.CalledProcessError as e:
        log.debug("Velum container not running: " + e.output)

    return {'containers': containers}
