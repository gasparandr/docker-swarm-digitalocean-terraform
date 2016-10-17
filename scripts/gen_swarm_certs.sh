#!/bin/bash

generate_CA () {
  type openssl >/dev/null 2>&1 || { echo >&2 "OpenSSL is required on your local machine to generate the CA."; exit 1; } && \
  openssl genrsa -out certs/ca-key.pem 2048 && \
  openssl req -x509 -new -nodes -key certs/ca-key.pem -days 10000 -out certs/ca.pem -subj "/CN=swarm-ca"
}

generate_swarm_certs () {
	type openssl >/dev/null 2>&1 || { echo >&2 "OpenSSL is required on your local machine to generate the CA."; exit 1; } && \
	openssl genrsa -out certs/swarm-primary-priv-key.pem 2048 && \
	openssl req -new -key certs/swarm-primary-priv-key.pem -out certs/swarm-primary.csr -subj "/CN=swarm" && \
  openssl x509 -req -days 1825 -in certs/swarm-primary.csr -CA certs/ca.pem -CAkey certs/ca-key.pem -CAcreateserial -out certs/swarm-primary-cert.pem -extensions v3_req -extfile tmp/swarm_openssl.cnf
	# openssl x509 -req -in certs/swarm-primary.csr -CA certs/ca.pem -CAkey certs/ca-key.pem -CAcreateserial -out certs/swarm-primary-cert.pem -days 365 v3_req -extfile tmp/openssl_manager.cnf
}

if [ -f certs/swarm-cert.pem ]; then
	echo "Swarm cert already exists..."
else
	# openssl genrsa -out certs/ca-priv-key.pem 2048 && \
	# openssl req -config /usr/lib/ssl/openssl.cnf -new -key certs/ca-priv-key.pem -x509 -days 1825 -out certs/ca.pem && \
	# openssl genrsa -out certs/swarm-priv-key.pem 2048 && \
	# openssl req -new -key certs/swarm-priv-key.pem -out certs/swarm.csr -subj "/C=./ST=./L=./O=./CN=swarm" && \
	# openssl x509 -req -days 1825 -in certs/swarm.csr -CA certs/ca.pem -CAkey certs/ca-priv-key.pem -CAcreateserial -out certs/swarm-cert.pem -extensions v3_req -extfile /usr/lib/ssl/openssl.cnf && \
	# openssl rsa -in certs/swarm-priv-key.pem -out certs/swarm-priv-key.pem
	echo "Creating CA certs, Swarm certs"
	generate_CA && \
	generate_swarm_certs
fi
