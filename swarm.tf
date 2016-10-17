variable "deployment_do_token" {
  description = "Read-Write API token used with Terraform to deploy your droplets."
}
variable "readonly_do_token" {
  description = "Read-Only DigitalOcean Token for use with Droplan (https://github.com/tam7t/droplan)"
}
variable "pub_key" {}
variable "pvt_key" {}
variable "ssh_fingerprint" {}
variable "region" {}
variable "size" {}
variable "master_replica_count" {}
variable "node_count" {}

provider "digitalocean" {
  token = "${var.deployment_do_token}"
}

resource "digitalocean_droplet" "manager-primary" {
  image = "docker"
  name = "docker-swarm-manager-primary"
  region = "${var.region}"
  size = "${var.size}"
  private_networking = true
  user_data     = "#cloud-config\n\nssh_authorized_keys:\n  - \"${file("${var.pub_key}")}\"\n"
  ssh_keys = [
    "${var.ssh_fingerprint}"
  ]
  connection {
    user = "root"
    type = "ssh"
    key_file = "${var.pvt_key}"
    timeout = "2m"
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir /certs"
    ]
  }
  provisioner "local-exec" {
    command = "sed -e \"s|TYPE|swarm|\" -e \"s|PUBLIC_IP|${self.ipv4_address}|\" -e \"s|PRIVATE_IP|${self.ipv4_address_private}|\" scripts/openssl.cnf > tmp/swarm_openssl.cnf"
  }
  provisioner "local-exec" {
    command = "chmod +x scripts/gen_swarm_certs.sh && ./scripts/gen_swarm_certs.sh"
  }
  provisioner "file" {
    source = "certs/ca.pem"
    destination = "/certs/ca.pem"
  }
  provisioner "file" {
    source = "certs/swarm-primary-priv-key.pem"
    destination = "/certs/swarm-priv-key.pem"
  }
  provisioner "file" {
    source = "certs/swarm-primary-cert.pem"
    destination = "/certs/swarm-cert.pem"
  }
  provisioner "remote-exec" {
    inline = [
      "apt-get update && apt-get install unzip -y && wget https://github.com/tam7t/droplan/releases/download/v1.2.0/droplan_1.2.0_linux_amd64.zip && unzip droplan_1.2.0_linux_amd64.zip && chmod +x droplan && mv droplan /usr/local/bin/droplan",
      "(crontab -l 2>/dev/null; echo \"*/5 * * * * root PATH=/sbin DO_KEY=${var.readonly_do_token} /usr/local/bin/droplan >/var/log/droplan.log 2>&1\") | crontab -",
      "docker run --restart=unless-stopped -d -h consul0 --name consul0 -v /mnt:/data -p ${self.ipv4_address_private}:8300:8300 -p ${self.ipv4_address_private}:8301:8301 -p ${self.ipv4_address_private}:8301:8301/udp -p ${self.ipv4_address_private}:8302:8302 -p ${self.ipv4_address_private}:8302:8302/udp -p ${self.ipv4_address_private}:8400:8400 -p ${self.ipv4_address_private}:8500:8500 -p 172.17.0.1:53:53/udp progrium/consul -server -advertise ${self.ipv4_address_private} -bootstrap-expect 3",
      "docker run --restart=unless-stopped -h mgr00 --name mgr00 -d -p 3375:2375 -v /certs:/certs:ro swarm manage --tlsverify --tlscacert=/certs/ca.pem --tlscert=/certs/swarm-cert.pem --tlskey=/certs/swarm-priv-key.pem --replication --advertise ${self.ipv4_address_private}:3375 consul://${self.ipv4_address_private}:8500/",
      "docker run -d --name registrator-00 -h registrator-00 -v /var/run/docker.sock:/tmp/docker.sock gliderlabs/registrator:latest consul://${self.ipv4_address_private}:8500"
    ]
  }
}

resource "digitalocean_droplet" "manager-replica" {
  depends_on = ["digitalocean_droplet.manager-primary"]
  image = "docker"
  name = "${format("docker-swarm-manager-replica-%02d", count.index)}"
  region = "${var.region}"
  size = "${var.size}"
  private_networking = true
  user_data     = "#cloud-config\n\nssh_authorized_keys:\n  - \"${file("${var.pub_key}")}\"\n"
  ssh_keys = [
    "${var.ssh_fingerprint}"
  ]
  connection {
    user = "root"
    type = "ssh"
    key_file = "${var.pvt_key}"
    timeout = "2m"
  }
  count         = "${var.master_replica_count}"
  provisioner "remote-exec" {
    inline = [
      "mkdir /certs"
    ]
  }
  provisioner "local-exec" {
    command = "sed -e \"s|TYPE|swarm|\" -e \"s|PUBLIC_IP|${self.ipv4_address}|\" -e \"s|PRIVATE_IP|${self.ipv4_address_private}|\" scripts/openssl.cnf > tmp/mgr${var.master_replica_count.index}_openssl.cnf"
  }
  provisioner "local-exec" {
    command = "chmod +x scripts/gen_swarm_certs.sh && ./scripts/gen_swarm_replica_certs.sh ${var.master_replica_count.index} ${self.ipv4_address} ${self.ipv4_address_private}"
  }
  provisioner "file" {
    source = "certs/ca.pem"
    destination = "/certs/ca.pem"
  }
  provisioner "file" {
    source = "certs/mgr${var.master_replica_count.index}-priv-key.pem"
    destination = "/certs/swarm-priv-key.pem"
  }
  provisioner "file" {
    source = "certs/mgr${var.master_replica_count.index}-cert.pem"
    destination = "/certs/swarm-cert.pem"
  }
  provisioner "remote-exec" {
    inline = [
      "apt-get update && apt-get install unzip -y && wget https://github.com/tam7t/droplan/releases/download/v1.2.0/droplan_1.2.0_linux_amd64.zip && unzip droplan_1.2.0_linux_amd64.zip && chmod +x droplan && mv droplan /usr/local/bin/droplan",
      "(crontab -l 2>/dev/null; echo \"*/5 * * * * root PATH=/sbin DO_KEY=${var.readonly_do_token} /usr/local/bin/droplan >/var/log/droplan.log 2>&1\") | crontab -",
      "docker run --restart=unless-stopped -d -h consul${count.index + 1} --name consul${count.index  + 1} -v /mnt:/data -p ${self.ipv4_address_private}:8300:8300 -p ${self.ipv4_address_private}:8301:8301 -p ${self.ipv4_address_private}:8301:8301/udp -p ${self.ipv4_address_private}:8302:8302 -p ${self.ipv4_address_private}:8302:8302/udp -p ${self.ipv4_address_private}:8400:8400 -p ${self.ipv4_address_private}:8500:8500 -p 172.17.0.1:53:53/udp progrium/consul -server -advertise ${self.ipv4_address_private} -join ${digitalocean_droplet.manager-primary.ipv4_address_private}",
      "docker run --restart=unless-stopped -h mgr${count.index + 1} --name mgr${count.index +1} -d -p 3375:2375 -v /certs:/certs:ro swarm manage --tlsverify --tlscacert=/certs/ca.pem --tlscert=/certs/swarm-mgr${count.index}.pem --tlskey=/certs/swarm-priv-key.pem --replication --advertise ${self.ipv4_address_private}:3375 consul://${self.ipv4_address_private}:8500/",
      "docker run -d --name registrator-${count.index +1} -h registrator-${count.index + 1} -v /var/run/docker.sock:/tmp/docker.sock gliderlabs/registrator:latest consul://${digitalocean_droplet.manager-primary.ipv4_address_private}:8500"

    ]
  }
}

resource "digitalocean_droplet" "node" {
  depends_on = ["digitalocean_droplet.manager-primary"]
  image = "docker"
  name = "${format("docker-swarm-node-%02d", count.index)}"
  region = "${var.region}"
  size = "${var.size}"
  private_networking = true
  user_data     = "#cloud-config\n\nssh_authorized_keys:\n  - \"${file("${var.pub_key}")}\"\n"
  ssh_keys = [
    "${var.ssh_fingerprint}"
  ]
  connection {
    user = "root"
    type = "ssh"
    key_file = "${var.pvt_key}"
    timeout = "2m"
  }
  count         = "${var.node_count}"
  provisioner "local-exec" {
    command = "sed -e \"s|TYPE|node${var.node_count.index}|\" -e \"s|PUBLIC_IP|${self.ipv4_address}|\" -e \"s|PRIVATE_IP|${self.ipv4_address_private}|\" scripts/openssl.cnf > tmp/node${var.node_count.index}_openssl.cnf"
  }
  provisioner "local-exec" {
    command = "chmod +x scripts/gen_node_certs.sh && ./scripts/gen_node_certs.sh ${var.node_count.index}"
  }
  provisioner "file" {
    source = "certs/ca.pem"
    destination = "ca.pem"
  }
  provisioner "file" {
    source = "certs/node${var.node_count.index}-priv-key.pem"
    destination = "node${var.node_count.index}-priv-key.pem"
  }
  provisioner "file" {
    source = "certs/node${var.node_count.index}-cert.pem"
    destination = "node${var.node_count.index}-cert.pem"
  }
  provisioner "remote-exec" {
    inline = [
      "apt-get update && apt-get install unzip -y && wget https://github.com/tam7t/droplan/releases/download/v1.2.0/droplan_1.2.0_linux_amd64.zip && unzip droplan_1.2.0_linux_amd64.zip && chmod +x droplan && mv droplan /usr/local/bin/droplan",
      "(crontab -l 2>/dev/null; echo \"*/5 * * * * root PATH=/sbin DO_KEY=${var.readonly_do_token} /usr/local/bin/droplan >/var/log/droplan.log 2>&1\") | crontab -",
      "sed -i 's/DOCKER_OPTS/#DOCKER_OPTS/g' /etc/default/docker && echo 'DOCKER_OPTS=\"--dns 8.8.8.8 --dns 8.8.4.4 -H tcp://${self.ipv4_address_private}:4243 -H unix:///var/run/docker.sock --tlsverify --tlscacert=/root/ca.pem --tlscert=/root/node${var.node_count.index}-cert.pem --tlskey=/root/node${var.node_count.index}-priv-key.pem\"' >> /etc/default/docker",
      "service docker restart",
      "docker run --restart=unless-stopped -d -h consul-agt${count.index} --name consul-agt${count.index} -p 8300:8300 -p 8301:8301 -p 8301:8301/udp -p 8302:8302 -p 8302:8302/udp -p 8400:8400 -p 8500:8500 -p 8600:8600/udp progrium/consul -rejoin -advertise ${self.ipv4_address_private} -join ${digitalocean_droplet.manager-primary.ipv4_address_private}",
      "docker run -d swarm join --advertise=${self.ipv4_address_private}:4243 consul://${self.ipv4_address_private}:8500/",
      "docker run -d --name registrator-${count.index + var.master_replica_count + 1} -h registrator-${count.index + var.master_replica_count + 1} -v /var/run/docker.sock:/tmp/docker.sock gliderlabs/registrator:latest consul://${digitalocean_droplet.manager-primary.ipv4_address_private}:8500"
    ]
  }
}
