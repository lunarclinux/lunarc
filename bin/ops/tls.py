"""TLS to appliances: always checked, never switched off.

Appliances usually have a self-signed certificate. At connect we look at it,
show its fingerprint and, once the person says it's theirs, pin it: every
later connection must present exactly that certificate, before any key is
sent. A certificate the system already trusts for that name (a real one) is
checked the normal way instead.
"""

import hashlib
import socket
import ssl

from .core import OpsError


def split_address(address, default_port=443):
    if address.startswith("["):
        host, _, rest = address[1:].partition("]")
        port = rest[1:] if rest.startswith(":") else ""
    else:
        host, _, port = address.partition(":")
    return host, int(port) if port else default_port


def fingerprint(der):
    h = hashlib.sha256(der).hexdigest().upper()
    return ":".join(h[i:i + 2] for i in range(0, len(h), 2))


def system_trusts(host, port, timeout=10):
    ctx = ssl.create_default_context()
    try:
        with socket.create_connection((host, port), timeout=timeout) as s:
            with ctx.wrap_socket(s, server_hostname=host):
                return True
    except ssl.SSLError:
        return False
    except OSError as e:
        raise OpsError(f"can't reach {host}:{port}: {e}")


def probe(address):
    """The appliance's certificate: (fingerprint, trusted by the system)."""
    host, port = split_address(address)
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    try:
        with socket.create_connection((host, port), timeout=10) as s:
            with ctx.wrap_socket(s, server_hostname=host) as t:
                der = t.getpeercert(binary_form=True)
    except OSError as e:
        raise OpsError(f"can't reach {host}:{port} over HTTPS: {e}")
    return fingerprint(der), system_trusts(host, port)


def sslopt(tls):
    """Options for the connection, from the saved {"mode": "system"|"pin", "pin": fp}."""
    if tls.get("mode") == "system":
        return {"cert_reqs": ssl.CERT_REQUIRED, "check_hostname": True}
    # Pinned: the chain isn't checked (it's self-signed); the exact
    # certificate is, in check_pin(), before anything is sent.
    return {"cert_reqs": ssl.CERT_NONE, "check_hostname": False}


def check_pin(sock, tls, name):
    if tls.get("mode") == "system":
        return
    der = sock.getpeercert(binary_form=True)
    if not der or fingerprint(der) != tls.get("pin"):
        raise OpsError(
            f"'{name}' presented a different certificate than the one you trusted, so nothing was sent. "
            f"If you replaced its certificate, connect again to trust the new one; otherwise, something "
            f"between here and the appliance may be listening in.")
