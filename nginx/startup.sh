#!/bin/bash

if [ ! -f /etc/nginx/ssl/default.crt ]; then
    openssl genrsa -out "/etc/nginx/ssl/default.key" 2048
    openssl req -new -key "/etc/nginx/ssl/default.key" -out "/etc/nginx/ssl/default.csr" -subj "/CN=default/O=default/C=UK"
    openssl x509 -req -days 365 -in "/etc/nginx/ssl/default.csr" -signkey "/etc/nginx/ssl/default.key" -out "/etc/nginx/ssl/default.crt"
    chmod 644 /etc/nginx/ssl/default.key
fi

if [ ${NGINX_SELF_SIGNED_SSL} = true ]; then
    # Generate root certificate
    if [ ! -f /etc/nginx/ssl/laradock-ca.pem ]; then
        openssl genrsa -des3 -passout pass:laradock -out "/etc/nginx/ssl/laradock-ca.key" 2048
        openssl req -x509 -new -nodes -passin pass:laradock -key "/etc/nginx/ssl/laradock-ca.key" -sha256 -days 825 -out "/etc/nginx/ssl/laradock-ca.pem" -subj "/CN=Laradock/O=Laradock/C=UK"
        chmod 644 /etc/nginx/ssl/laradock-ca.key
    fi

    # Generate self signed certificate
    for enabled_site in /etc/nginx/sites-available/*.conf
    do
        server_name=$(awk '$1=="server_name"{sub(/;/,""); print $2; exit}' $enabled_site)
        if [ ! -d /etc/nginx/ssl/$server_name ]; then
            mkdir /etc/nginx/ssl/$server_name

            # Generate a private key
            openssl genrsa -out "/etc/nginx/ssl/$server_name/$server_name.key" 2048

            # Create a certificate-signing request
            openssl req -new -key "/etc/nginx/ssl/$server_name/$server_name.key" -out "/etc/nginx/ssl/$server_name/$server_name.csr" -subj "/CN=$server_name/O=Laradock/C=UK"

            # Create the signed certificate
            openssl x509 -req -in "/etc/nginx/ssl/$server_name/$server_name.csr" -passin pass:laradock -CA "/etc/nginx/ssl/laradock-ca.pem" -CAcreateserial -CAkey "/etc/nginx/ssl/laradock-ca.key" -out "/etc/nginx/ssl/$server_name/$server_name.crt" -days 365 -sha256 -extfile <(printf "subjectAltName=DNS:$server_name,DNS:*.$server_name")

            chmod 644 /etc/nginx/ssl/$server_name/$server_name.key
        fi
    done
fi

# Start crond in background
crond -l 2 -b

# Start nginx in foreground
nginx
