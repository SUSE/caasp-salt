certificate_information:
  subject_properties:
    C: DE
    Email:
    GN:
    L: Nuremberg
    O: system:nodes
    OU: Containers Team
    SN:
    ST: Bavaria
  days_valid:
    ca_certificate: 3650
    certificate: 100
  days_remaining:
    ca_certificate: 90
    certificate: 90

# we can add certificates for particular registries like this:
#
# registries:
#  - "something.com:5000": |
#    <CA contents>
#  - "some-other.com:6000": |
#    <CA contents>
#
registries: []
