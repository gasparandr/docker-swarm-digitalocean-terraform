#!/bin/bash

if [ ! -f certs/ca.pem ]; then
	echo "certs/ca.pem does not exist, run gen_swarm_certs.sh first."
else
	type openssl >/dev/null 2>&1 || { echo >&2 "OpenSSL is required on your local machine to generate the CA."; exit 1; } && \
	openssl genrsa -out certs/node${1}-priv-key.pem 2048 && \
	openssl req -new -key certs/node${1}-priv-key.pem -out certs/node${1}.csr -subj "/CN=swarm" && \
	openssl x509 -req -days 1825 -in certs/node${1}.csr -CA certs/ca.pem -CAkey certs/ca-key.pem -CAcreateserial -out certs/node${1}-cert.pem -extensions v3_req -extfile tmp/node${1}_openssl.cnf
fi
