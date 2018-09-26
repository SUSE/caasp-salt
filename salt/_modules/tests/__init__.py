import importlib
import os
import sys
sys.path.append(os.path.abspath(os.path.join(__file__, "../../../")))


def setUpModule():
    print('Starting tests.')


def tearDownModule():
    print('Tests done.')


class Utils(object):
    """Proxy module to simulate the __utils__[*] dictionary used in salt-code.

    Needed to test the salt-modules in isolation."""
    def __getitem__(self, key):
        package, function = key.rsplit(".")
        full_path_package = "_utils.{0}".format(package)
        module = importlib.import_module(full_path_package)
        return getattr(module, function)
