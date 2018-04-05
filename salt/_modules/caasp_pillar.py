from __future__ import absolute_import


def __virtual__():
    return "caasp_pillar"


def get(name, default=''):
    '''
    A sanitized version of pillar.get() that

    * will return `default` (or `''`) instead of `None` or `''`
    * will return `True`/`False` instead of `"true"`/`"false"`

    The rationale is that, if pillar[x] can return None,
    we can get a nasty "None" when replacing {{pillar[x]}} in a
    jinja template. In other words, `None`s are annoying when used
    in Salt/Jinja...
    '''
    res = __salt__['pillar.get'](name, None)
    if res is None:
        res = default

    if isinstance(res, basestring):
        try:
            return int(res)
        except ValueError:
            pass

        if res.lower() in ["true", "yes", "on"]:
            return True
        elif res.lower() in ["false", "no", "off"]:
            return False

    return res
