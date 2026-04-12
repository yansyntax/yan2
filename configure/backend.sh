#!/bin/bash
clear

cat > /etc/haproxy/haproxy.cfg <<-EOF
global
    daemon
    tune.ssl.default-dh-param 2048

defaults
    mode tcp
    option dontlognull
    option tcp-smart-accept
    option tcp-smart-connect
    timeout connect 30s
    timeout client 300s
    timeout server 300s

# ================= HTTP =================
frontend http
    bind *:80 tfo
    bind *:8080 tfo
    bind *:8880 tfo
    bind *:2082 tfo
    mode tcp

    tcp-request inspect-delay 1s
    tcp-request content accept if HTTP

    acl is_ws hdr(Upgrade) -i websocket

    use_backend xray_ws if is_ws
    default_backend ssh


# ================= SSH TLS =================
frontend tls
    bind *:2083 ssl crt /etc/haproxy/hap.pem tfo
    mode tcp

    tcp-request inspect-delay 1s
    tcp-request content accept if { req.ssl_hello_type 1 }

    acl is_ws hdr(Upgrade) -i websocket

    use_backend xray_ws if is_ws
    default_backend ssh


# ================= BACKEND =================

backend ssh
    mode tcp
    server s1 127.0.0.1:109

backend xray_ws
    mode tcp
    server s1 127.0.0.1:10000
EOF


systemctl daemon-reload

systemctl enable haproxy
systemctl restart haproxy

systemctl enable xray
systemctl restart xray
