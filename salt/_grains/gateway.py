import socket, struct

def gateway():
    """Get the default gateway (and device)."""

    with open("/proc/net/route") as fh:
        for line in fh:
            fields = line.strip().split()
            if fields[1] != '00000000' or not int(fields[3], 16) & 2:
                continue

            # Some code for logic that sets grains like
            grains = {}
            grains['gateway_iface'] = fields[0]
            grains['gateway_ip'] = socket.inet_ntoa(struct.pack("<L", int(fields[2], 16)))
            return grains
