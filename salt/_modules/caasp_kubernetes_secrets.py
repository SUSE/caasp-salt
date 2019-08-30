from __future__ import absolute_import

from base64 import b64encode
from hashlib import sha1

secret_template = """apiVersion: v1
kind: Secret
metadata:
  name: {name}
  namespace: {namespace}
type: Opaque
data:
  {secret_key}: {secret_contents}
"""


def __virtual__():
    return "caasp_kubernetes_secrets"


def kubectl(command, **kwargs):
    return __salt__['caasp_kubernetes_kubectl.kubectl'](command, **kwargs)


def name_by_content(prefix, content):
    return prefix + sha1(content).hexdigest()


def present_with_contents(secret_key, secret_contents, secret_name_prefix=None, secret_name=None, namespace="kube-system"):
    secret_name = name_by_content(secret_contents) if secret_name is None else secret_name
    if secret_name_prefix is not None:
        secret_name = secret_name_prefix + secret_name
    secret_definition = secret_template.format(name=secret_name,
                                               namespace=namespace,
                                               secret_key=secret_key,
                                               secret_contents=b64encode(secret_contents))
    ret, _, _ = kubectl('apply -f -', stdin=secret_definition)
    return ret == 0
