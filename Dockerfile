# Original credit: https://github.com/jpetazzo/dockvpn
# Updated for OpenVPN 2.6+ with DCO (Data Channel Offload) support

FROM ubuntu:24.04

LABEL maintainer="Kyle Manna <kyle@kylemanna.com>"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openvpn easy-rsa iptables bash iproute2 \
        libpam-google-authenticator pamtester libqrencode4 && \
    ln -s /usr/share/easy-rsa/easyrsa /usr/local/bin && \
    rm -rf /var/lib/apt/lists/*

ENV OPENVPN=/etc/openvpn
ENV EASYRSA=/usr/share/easy-rsa \
    EASYRSA_CRL_DAYS=3650 \
    EASYRSA_PKI=$OPENVPN/pki

VOLUME ["/etc/openvpn"]

EXPOSE 1194/udp

CMD ["ovpn_run"]

ADD ./bin /usr/local/bin
RUN chmod a+x /usr/local/bin/*

ADD ./otp/openvpn /etc/pam.d/
