from __future__ import absolute_import

import salt.utils.files


def managed(name, **kwargs):
    '''
    Manage a given file, this function allows for a file to be downloaded from
    the salt master and potentially run through a templating system.

    This is a wrapper on the standard :py:func:`file.managed <salt.states.file.managed>`
    state where we can specify a `work_dir` that will be used for creating the temporary
    file, as the standard version creates a temporary file in the same directory as `name`,
    and that can lead to some problems with programs/daemons that are watching that
    directory (like the kubelet with `/etc/kubernetes/manifests`).

    work_dir
        A directory for creating temporary files.

    For a full list of arguments see :py:func:`file.managed <salt.states.file.managed>`
    '''
    def debug(s):
        __utils__['caasp_log.debug']('CaaS: caasp_file.managed: {}: '.format(name) + s)

    def error(s):
        return dict(naame=name, result=False, comment=s, changes={})

    work_dir = kwargs.pop('work_dir', None)
    if not work_dir:
        # if no work_dir has been specified, invoke the regular `managed`
        return __states__['file.managed'](name=name, **kwargs)

    debug('using working dir {} for managed file {}'.format(work_dir, name))

    # 1. create a temporary file, <tmp_filename>, in <tmp_dir>
    tmp_filename = salt.utils.files.mkstemp(dir=work_dir)

    try:
        # 2. if there is an existing file <name>, copy it to this <tmp_filename>
        if __salt__['file.file_exists'](name):
            debug('copying existing {} to temporary file {}'.format(name, tmp_filename))
            try:
                # copy the existing file to /tmp/<name>
                __salt__['file.copy'](name, tmp_filename)
            except Exception as exc:
                return error('Unable to copy file {0} to {1}: {2}'.format(name, tmp_filename, exc))

        # 3. manage the <tmp_filename>
        debug('creating temporary file {}'.format(tmp_filename))
        ret_managed = __states__['file.managed'](name=tmp_filename, **kwargs)
        if not ret_managed['result']:
            return error('Error when creating temporary file {} for {}'.format(tmp_filename, name))
        changes_managed = ret_managed['changes']

        # 4. finally, copy the  <tmp_filename> to the final destination <name>
        debug('copying temporary file {} to {}'.format(tmp_filename, name))
        ret_copy = __states__['file.copy'](name=name,
                                           source=tmp_filename,
                                           force=True,
                                           makedirs=False,
                                           preserve=True,
                                           subdir=False)
        if not ret_copy['result']:
            return error('Error when creating temporary file {} for {}'.format(tmp_filename, name))

        # 5. return the `managed` we run in the tmp_filename, but tweaking some things
        return {
            'name': name,
            'changes': changes_managed,
            'result': True,
            'comment': ret_managed['comment'].replace(tmp_filename, name)
        }

    finally:
        debug('removing temporary file {}'.format(tmp_filename))
        salt.utils.files.remove(tmp_filename)
