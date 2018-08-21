from __future__ import absolute_import

import datetime
from subprocess import Popen, STDOUT


def __virtual__():
    return "caasp_txupdate"


def migration():
    '''
    run transactional-update migration in a shell and write the result to a logfile
    '''

    date = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M")
    log_path = '/var/log/migration_' + date
    logfile = open(log_path, "w")
    cmd = "transactional-update migration -n salt"

    p = Popen(cmd, shell=True, stdout=logfile, stderr=STDOUT)
    ret_code = p.wait()
    logfile.flush()

    return ret_code == 0
