import os
import socket
import random
import ipaddress

def is_tor_running(port=9050):
    """Check if Tor SOCKS5 proxy is listening on the local port."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(1.0)
        s.connect(('127.0.0.1', port))
        s.close()
        return True
    except Exception:
        return False

def rotate_tor_ip(control_port=9051, password=None):
    """Send NEWNYM signal to Tor control port to request a new IP address."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(2.0)
        s.connect(('127.0.0.1', control_port))
        
        # Authenticate with the Tor control port
        auth_cmd = f'AUTHENTICATE "{password}"\r\n' if password else 'AUTHENTICATE\r\n'
        s.send(auth_cmd.encode())
        response = s.recv(1024).decode()
        
        if '250 OK' in response:
            # Signal Tor to get a new IP address
            s.send(b'SIGNAL NEWNYM\r\n')
            response = s.recv(1024).decode()
            s.close()
            if '250 OK' in response:
                print("DEBUG - Tor IP successfully rotated.")
                return True
        s.close()
    except Exception as e:
        print(f"DEBUG - Could not rotate Tor IP: {e}")
    return False

def generate_random_ipv6(prefix):
    """Generate a random IPv6 address within the specified network prefix."""
    try:
        network = ipaddress.IPv6Network(prefix)
        net_addr = int(network.network_address)
        # Generate a random 64-bit host part for /64 prefix
        host_addr = random.getrandbits(128 - network.prefixlen)
        random_ip = ipaddress.IPv6Address(net_addr | host_addr)
        return str(random_ip)
    except Exception as e:
        print(f"DEBUG - Error generating random IPv6: {e}")
        return None

def get_spotdl_proxy_args(attempt=1):
    """
    Returns a list of command line arguments for spotdl depending on proxy availability.
    If attempt > 1, it will try to rotate/change settings.
    """
    args = []
    
    # 1. Tor Proxy Configuration
    # On server deployments (Docker/VPS), Tor might run on 127.0.0.1:9050
    if is_tor_running(9050):
        if attempt > 1:
            # Try to get a new Tor IP
            rotate_tor_ip(9051)
        print("DEBUG - Tor proxy is running. Using SOCKS5 proxy.")
        args.extend(['--proxy', 'socks5://127.0.0.1:9050'])
        return args

    # 2. IPv6 Range Rotation
    ipv6_prefix = os.environ.get('IPV6_PREFIX')
    if ipv6_prefix:
        random_ip = generate_random_ipv6(ipv6_prefix)
        if random_ip:
            print(f"DEBUG - Using generated random IPv6: {random_ip}")
            # Bind spotdl/yt-dlp to the random IPv6 address
            args.extend(['--yt-dlp-args', f'--source-address {random_ip}'])
            return args

    # 3. Fallback to SPOTDL_PROXY environment variable
    env_proxy = os.environ.get('SPOTDL_PROXY')
    if env_proxy:
        print(f"DEBUG - Using environment variable proxy: {env_proxy}")
        args.extend(['--proxy', env_proxy])
        
    return args
