# TCP Protocol

## TCP vs. UDP - Pros & Cons
By default, OpenVPN is configured to use the UDP protocol.  Because UDP incurs minimal protocol overhead (for example, no acknowledgment is required upon successful packet receipt), it can sometimes result in slightly faster throughput.  However, in situations where VPN service is needed over an unreliable connection, the user experience can benefit from the extra diagnostic features of the TCP protocol.

As an example, users connecting from an airplane wifi network may experience high packet drop rates, where the error detection and sliding window control of TCP can more readily adjust to the inconsistent connection.

Another example would be trying to open a VPN connection from within a very restrictive network. In some cases port 1194, or even UDP traffic on any port, may be restricted by network policy. Because TCP traffic on port 443 is used for normal TLS (https) web browsing, it is very unlikely to be blocked.

## Using TCP
The primary way to use TCP is to configure OpenVPN to listen on a specific TCP port. This section details two common scenarios for using TCP port 443. For guidance on using other custom ports, or for a more detailed explanation of port configuration, see the "Using Custom Ports" section below.

### Example: Using TCP on Port 443 (Client Connection) with Internal Port 1194
This is a common setup to bypass restrictive firewalls, as TCP traffic on port 443 (HTTPS) is rarely blocked. In this configuration, the OpenVPN daemon inside the container continues to listen on its default port `1194/tcp`, but clients connect to the host on port `443/tcp`.

1.  **Generate Configuration**:
    This command tells clients to connect to `VPN.SERVERNAME.COM` on port `443` using TCP. The internal OpenVPN daemon port is not changed here and remains `1194`.
    ```bash
    docker run -v $OVPN_DATA:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u tcp://VPN.SERVERNAME.COM:443
    ```
2.  **Initialize PKI (if not already done)**:
    ```bash
    docker run -v $OVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki
    ```
3.  **Start the OpenVPN Server**:
    Map the host's port `443` to the container's internal port `1194`.
    ```bash
    docker run -v $OVPN_DATA:/etc/openvpn -d -p 443:1194/tcp --cap-add=NET_ADMIN kylemanna/openvpn
    ```

### Example: Using TCP on Port 443 (Client and Internal)
Alternatively, you might want the OpenVPN daemon inside the container to also listen on port 443. This keeps the external (client-facing) and internal (daemon) ports consistent.

1.  **Generate Configuration**:
    Set both the client connection port (via `-u`) and the internal OpenVPN daemon port (via `-e`) to `443`.
    ```bash
    docker run -v $OVPN_DATA:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u tcp://VPN.SERVERNAME.COM:443 -e 'port 443'
    ```
2.  **Initialize PKI (if not already done)**:
    ```bash
    docker run -v $OVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki
    ```
3.  **Start the OpenVPN Server**:
    Map the host's port `443` to the container's internal port `443`.
    ```bash
    docker run -v $OVPN_DATA:/etc/openvpn -d -p 443:443/tcp --cap-add=NET_ADMIN kylemanna/openvpn
    ```

## Using Custom Ports
When configuring OpenVPN to use TCP with a port other than the default 1194 or the common 443, or to understand port configuration in more detail, it's important to grasp how different port settings interact. There are three main aspects to consider:
1.  **Client Connection Port**: This is the port on your `VPN.SERVERNAME.COM` that clients will use to connect. It's defined in the client `.ovpn` configuration files.
2.  **OpenVPN Daemon Listening Port (Internal)**: This is the port the OpenVPN process listens on *inside* the Docker container. By default, this is `1194` for both UDP and TCP.
3.  **Host Port Mapping**: This is the mapping between a port on your host machine and the OpenVPN daemon's listening port inside the container. This is configured with the `-p` flag in the `docker run` command.

The `-u tcp://VPN.SERVERNAME.COM:PORT` parameter in `ovpn_genconfig` primarily sets the remote address, port, and protocol in the generated client `.ovpn` files. It tells the client where to connect.

To change the actual listening port of the OpenVPN daemon *inside* the container, you need to pass the `port` directive to OpenVPN. This is done using the `-e` option in `ovpn_genconfig`. For example: `ovpn_genconfig -e 'port NEW_PORT_NUMBER'`.

If you change the OpenVPN daemon's internal listening port, you **must** update the `-p` flag in your `docker run` command to map the desired host port to this new internal port. For example, if the OpenVPN daemon is configured to listen on `NEW_PORT_NUMBER`, your `docker run` command should include `-p NEW_PORT_NUMBER:NEW_PORT_NUMBER/tcp`.

### Example: Using Custom TCP Port 2613
Here's how to set up OpenVPN to listen on TCP port 2613 for both client connections and internally within the container:

1.  **Generate Configuration**:
    Use `ovpn_genconfig` to set the client connection parameters and the internal OpenVPN daemon port.
    ```bash
    docker run -v $OVPN_DATA:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u tcp://VPN.SERVERNAME.COM:2613 -e 'port 2613'
    ```
2.  **Initialize PKI (if not already done)**:
    ```bash
    docker run -v $OVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki
    ```
3.  **Start the OpenVPN Server**:
    Map the host port 2613 to the container's internal port 2613.
    ```bash
    docker run -v $OVPN_DATA:/etc/openvpn -d -p 2613:2613/tcp --cap-add=NET_ADMIN kylemanna/openvpn
    ```

In this setup:
*   Clients will connect to `VPN.SERVERNAME.COM` on port `2613` using TCP.
*   The OpenVPN daemon inside the Docker container will listen on port `2613/tcp`.
*   The host machine will map its port `2613/tcp` to the container's port `2613/tcp`.

## Running a Second Fallback TCP Container
Instead of choosing between UDP and TCP, you can use both. A single instance of OpenVPN can only listen for a single protocol on a single port, but this image makes it easy to run two instances simultaneously. After building, configuring, and starting a standard container listening for UDP traffic on 1194, you can start a second container listening for tcp traffic on port 443:

    docker run -v $OVPN_DATA:/etc/openvpn --rm -p 443:1194/tcp --cap-add=NET_ADMIN kylemanna/openvpn ovpn_run --proto tcp

`ovpn_run` will load all the values from the default config file, and `--proto tcp` will override the protocol setting.

This allows you to use UDP most of the time, but fall back to TCP on the rare occasion that you need it.

Note that you will need to configure client connections manually. At this time it is not possible to generate a client config that will automatically fall back to the TCP connection.

## Forward HTTP/HTTPS connection to another TCP port
You might run into cases where you want your OpenVPN server listening on TCP port 443 to allow connection behind a restricted network, but you already have a webserver on your host running on that port. OpenVPN has a built-in option named `port-share` that allow you to proxy incoming traffic that isn't OpenVPN protocol to another host and port.

First, change the listening port of your existing webserver (for instance from 443 to 4433).

Then initialize the data container by specifying the TCP protocol, port 443 and the port-share option:

    docker run -v $OVPN_DATA:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig \
    -u tcp://VPN.SERVERNAME.COM:443 \
    -e 'port-share VPN.SERVERNAME.COM 4433'
    
Then proceed to initialize the pki, create your users and start the container as usual.
    
This will proxy all non OpenVPN traffic incoming on TCP port 443 to TCP port 4433 on the same host. This is currently only designed to work with HTTP or HTTPS protocol.
