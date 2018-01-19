from __future__ import absolute_import

import time

import salt.exceptions
import salt.utils


def run(name,
        onlyif=None,
        unless=None,
        creates=None,
        cwd=None,
        runas=None,
        shell=None,
        env=None,
        stateful=False,
        umask=None,
        output_loglevel='debug',
        quiet=False,
        timeout=None,
        ignore_timeout=False,
        use_vt=False,
        retry={},
        **kwargs):
    '''
    Run a command if certain circumstances are met.  Use ``cmd.wait`` if you
    want to use the ``watch`` requisite.

    name
        The command to execute, remember that the command will execute with the
        path and permissions of the salt-minion.

    onlyif
        A command to run as a check, run the named command only if the command
        passed to the ``onlyif`` option returns true

    unless
        A command to run as a check, only run the named command if the command
        passed to the ``unless`` option returns false

    cwd
        The current working directory to execute the command in, defaults to
        /root

    runas
        The user name to run the command as

    shell
        The shell to use for execution, defaults to the shell grain

    env
        A list of environment variables to be set prior to execution.
        Example:

        .. code-block:: yaml

            script-foo:
              caasp_cmd.run:
                - env:
                  - BATCH: 'yes'

        .. warning::

            The above illustrates a common PyYAML pitfall, that **yes**,
            **no**, **on**, **off**, **true**, and **false** are all loaded as
            boolean ``True`` and ``False`` values, and must be enclosed in
            quotes to be used as strings. More info on this (and other) PyYAML
            idiosyncrasies can be found :ref:`here <yaml-idiosyncrasies>`.

        Variables as values are not evaluated. So $PATH in the following
        example is a literal '$PATH':

        .. code-block:: yaml

            script-bar:
              caasp_cmd.run:
                - env: "PATH=/some/path:$PATH"

        One can still use the existing $PATH by using a bit of Jinja:

        .. code-block:: yaml

            {% set current_path = salt['environ.get']('PATH', '/bin:/usr/bin') %}

            mycommand:
              caasp_cmd.run:
                - name: ls -l /
                - env:
                  - PATH: {{ [current_path, '/my/special/bin']|join(':') }}

    stateful
        The command being executed is expected to return data about executing
        a state. For more information, see the :ref:`stateful-argument` section.

    umask
        The umask (in octal) to use when running the command.

    output_loglevel
        Control the loglevel at which the output from the command is logged.
        Note that the command being run will still be logged (loglevel: DEBUG)
        regardless, unless ``quiet`` is used for this value.

    quiet
        The command will be executed quietly, meaning no log entries of the
        actual command or its return data. This is deprecated as of the
        **2014.1.0** release, and is being replaced with
        ``output_loglevel: quiet``.

    timeout
        If the command has not terminated after timeout seconds, send the
        subprocess sigterm, and if sigterm is ignored, follow up with sigkill

    ignore_timeout
        Ignore the timeout of commands, which is useful for running nohup
        processes.

        .. versionadded:: 2015.8.0

    creates
        Only run if the file or files specified by ``creates`` do not exist.

        .. versionadded:: 2014.7.0

    use_vt
        Use VT utils (saltstack) to stream the command output more
        interactively to the console and the logs.
        This is experimental.

    bg
        If ``True``, run command in background and do not await or deliver it's
        results.

        .. versionadded:: 2016.3.6

    .. note::

        caasp_cmd.run supports the usage of ``reload_modules``. This functionality
        allows you to force Salt to reload all modules. You should only use
        ``reload_modules`` if your caasp_cmd.run does some sort of installation
        (such as ``pip``), if you do not reload the modules future items in
        your state which rely on the software being installed will fail.

        .. code-block:: yaml

            getpip:
              caasp_cmd.run:
                - name: /usr/bin/python /usr/local/sbin/get-pip.py
                - unless: which pip
                - require:
                  - pkg: python
                  - file: /usr/local/sbin/get-pip.py
                - reload_modules: True

    retry
        This allows you to provide `attempts` and `interval`, what will retry the command as much
        ``attempts`` times, separated by `interval` seconds. If 'until' is provided,
        verify we must not try again after running the command successfully
        by runing the `until` condition.

    '''
    # NOTE: The keyword arguments in **kwargs are passed directly to the
    # ``cmd.run_all`` function and cannot be removed from the function
    # definition, otherwise the use of unsupported arguments in a
    # ``caasp_cmd.run`` state will result in a traceback.

    retry_ = {'attempts': 1,
              'interval': 1,
              'until': None}
    retry_.update(retry)

    ret = None

    for attempt in xrange(retry_['attempts']):
        ret = __states__['cmd.run'](name=name,
                                    onlyif=onlyif,
                                    unless=unless,
                                    creates=creates,
                                    cwd=cwd,
                                    runas=runas,
                                    shell=shell,
                                    env=env,
                                    stateful=stateful,
                                    umask=umask,
                                    output_loglevel=output_loglevel,
                                    quiet=quiet,
                                    timeout=timeout,
                                    ignore_timeout=ignore_timeout,
                                    use_vt=use_vt,
                                    **kwargs)

        if ret['result']:
            ret_success = {'name': name,
                           'changes': ret['changes'],
                           'result': True,
                           'comment': "Command executed succesfully after {0} retries. Last output: {1}".format(attempt + 1, ret['comment'])}

            # command run successful
            if not retry_['until']:
                return ret_success

            # check if we are really done
            retry_until_ret = __states__['cmd.run'](name=retry_['until'],
                                                    cwd=cwd,
                                                    runas=runas,
                                                    shell=shell,
                                                    env=env,
                                                    umask=umask,
                                                    output_loglevel=output_loglevel,
                                                    quiet=quiet,
                                                    timeout=timeout,
                                                    ignore_timeout=ignore_timeout,
                                                    use_vt=use_vt,
                                                    **kwargs)
            if retry_until_ret['result']:
                return ret_success

            # append the 'until' command output, so we can have some debugging info...
            ret['comment'] = ret['comment'] + \
                "(until: " + retry_until_ret['comment'] + ")"

        if attempt + 1 == retry_['attempts']:
            break

        if retry_['interval'] > 0:
            time.sleep(retry_['interval'])

    return {'name': name,
            'changes': ret['changes'],
            'result': False,
            'comment': "Command failed after {0} retries. Last output: {1}".format(retry_['attempts'], ret['comment'])}
