# we can add certificates for particular registries like this:
#
# registries:
#   - url: http://my.reg.url
#   - url: http://my.reg.url.port:5000
#   - url: my.reg.port:5000
#   - url: https://my.reg.port.cert:5000
#     cert: |
#         >> the certificate for "my.reg.port.cert:5000" <<
#   - url: weird.port.cert:8888
#     cert: |
#         >> the certificate for "weird.port.cert:8888" <<
#   - url: http://my.mirrored.registry:5000
#     mirrors:
#     - url: https://local.mirror.lan:5000
#       cert: |
#           >> the certificate for "local.mirror.lan:5000" <<
#     - url: mirror.with.no.port
#       cert: |
#           >> the certificate for "mirror.with.no.port" <<
#
# NOTE: secure (https://) is the default, adding http:// to the name will mark it insecure
#
registries: []

# TODO: remove once we don't need the "suse_registry_mirror" exception
suse_registry_url: 'https://registry.suse.com'
