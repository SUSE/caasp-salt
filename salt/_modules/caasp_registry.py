#!/usr/bin/env python
"""Determine which container images to use.

Either use the images provided by container-feeder or download them
directly from a registry.

Returns multiple grains related to the images:

- use_registry_images: True if registry images should be used.
- base_image_url: prefix for the container-images: <prefix>/<image>:<tag>
"""
import yaml


UNKNOWN_VERSION = (0, 0)
REGISTRY_CONFIGURATION_PATH = "/usr/share/caasp-container-manifests/config/registry/registry-config.yaml"


def __virtual__():
    return "caasp_registry"


def _registry_config():
    registry_config = {
        "use_registry": False,
        "host": "",
        "namespace": ""
    }
    try:
        with open(REGISTRY_CONFIGURATION_PATH) as config:
            try:
                registry_config = yaml.safe_load(config)
            except yaml.YAMLError:
                __utils__['caasp_log.warn']("Could not load registry configuration at %s",
                                            REGISTRY_CONFIGURATION_PATH)
    except IOError:
        __utils__['caasp_log.warn']("Could not read registry configuration file: %s",
                                    REGISTRY_CONFIGURATION_PATH)
    return registry_config


def _use_registry_images():
    """Return whether registry or packaged images are used."""
    return _registry_config()["use_registry"]


def _registry():
    """Registry to download images from."""
    return _registry_config()["host"]


def _namespace():
    """Base namespace the images can be found in the registry"""
    return _registry_config()["namespace"]


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
