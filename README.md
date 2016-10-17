Docker Swarm on DigitalOcean
============================

Deploys a Docker Swarm cluster with TLS and secured Docker network via [Droplan](https://github.com/tam7t/droplan).

Usage
=====

Provide these variables (update examples to meet your requirements in `terraform.tfvars` or through stdin when you apply the configuration):

```
deployment_do_token = "<Read-Write DO Token>"
readonly_do_token = "<Read-Only DO Token; For use with Droplan>"
pub_key = "/path/to/do-key.pub"
pvt_key = "/path/to/do-key"
ssh_fingerprint = "<Your SSH Key Fingerprint"
master_replica_count = "2"
node_count = "3"
region = "nyc2"
size = "4gb"
```
then:

```bash
terraform apply
```

Docker Client
=============

Your certs will all be in your terraform project directory `cert/` subdirectory, you can connect with your Docker CLI using this format:

```bash
docker -H tcp://162.243.77.96:3375 --tlsverify --tlscacert=certs/ca.pem --tlscert=certs/swarm-primary-cert.pem --tlskey=certs/swarm-primary-priv-key.pem info
```

Bring your own certificates
===========================

Please your certificates in `certs/` using the naming scheme `swarm-primary` for your management node, `mgr0` through `mgrX` for management server replicas, and `node0` through `nodeX` for your Swarm nodes. The scripts will account for existing certificates and not create new ones.

For example:

```
ca-key.pem
ca.pem
mgr2-cert.pem
mgr2-priv-key.pem
node3-cert.pem
node3-priv-key.pem
swarm-primary-cert.pem
swarm-primary-priv-key.pem
```
