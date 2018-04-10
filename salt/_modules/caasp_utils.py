from __future__ import absolute_import


def __virtual__():
    return "caasp_utils"


def intersect(a, b):
    '''
    Return the intersection of two lists `a` and `b`
    '''
    return list(set(a) & set(b))


def issubset(a, b):
    '''
    Return True if `a` is a subset of `b`
    '''
    return set(a).issubset(set(b))
