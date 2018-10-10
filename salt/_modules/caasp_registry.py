#!/usr/bin/env python
"""Determine which container images to use.

Either use the images provided by container-feeder or download them
directly from a registry.

Returns multiple grains related to the images:

- use_registry_images: True if registry images should be used.
- base_image_url: prefix for the container-images: <prefix>/<image>:<tag>
"""
import sys


UNKNOWN_VERSION = (0, 0)


def __virtual__():
    return "caasp_registry"


def _use_registry_images():
    """Return whether registry or packaged images are used."""
    return False if sys.version_info < (3,) else True


def _registry():
    """Registry to download images from."""
    return "registry.suse.de"


def _namespace():
    """Base namespace the images can be found in the registry"""
    return "devel/casp/3.0/controllernode/images_container_base/sles12"


def caasp_version():
    # Python 3 does not allow comparing list & tuples, so force a tuple:
    version = tuple(__salt__['grains.get']('osrelease_info', UNKNOWN_VERSION))
    return version


def use_registry_images():
    return _use_registry_images()


def base_image_url():
    """Return the prefix of the container image to use.

    <prefix>/<image>:<tag>
    """
    if _use_registry_images():
        return "{0}/{1}".format(_registry(), _namespace())
    else:
        return "sles12"
