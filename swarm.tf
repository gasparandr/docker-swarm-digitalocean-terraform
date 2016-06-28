variable "do_token" {}
variable "pub_key" {}
variable "pvt_key" {}
variable "ssh_fingerprint" {}
variable "region" {}
variable "size" {}
variable "master_replica_count" {}
variable "node_count" {}

provider "digitalocean" {
  token = "${var.do_token}"
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
      "export PATH=$PATH:/usr/bin",
      "service docker start",
      "docker run --restart=unless-stopped -d -h consul00 --name consul00 -v /mnt:/data -p ${self.ipv4_address_private}:8300:8300 -p ${self.ipv4_address_private}:8301:8301 -p ${self.ipv4_address_private}:8301:8301/udp -p ${self.ipv4_address_private}:8302:8302 -p ${self.ipv4_address_private}:8302:8302/udp -p ${self.ipv4_address_private}:8400:8400 -p ${self.ipv4_address_private}:8500:8500 -p 172.17.0.1:53:53/udp progrium/consul -server -advertise ${self.ipv4_address_private} -bootstrap-expect 3",
      "docker run --restart=unless-stopped -h mgr00 --name mgr00 -d -p 3375:2375 swarm manage --replication --advertise ${self.ipv4_address_private}:3375 consul://${self.ipv4_address_private}:8500/"
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
      "export PATH=$PATH:/usr/bin",
      "service docker start",
      "docker run --restart=unless-stopped -d -h consul${count.index} --name consul${count.index} -v /mnt:/data -p ${self.ipv4_address_private}:8300:8300 -p ${self.ipv4_address_private}:8301:8301 -p ${self.ipv4_address_private}:8301:8301/udp -p ${self.ipv4_address_private}:8302:8302 -p ${self.ipv4_address_private}:8302:8302/udp -p ${self.ipv4_address_private}:8400:8400 -p ${self.ipv4_address_private}:8500:8500 -p 172.17.0.1:53:53/udp progrium/consul -server -advertise ${self.ipv4_address_private} -join ${digitalocean_droplet.manager-primary.ipv4_address_private}",
      "docker run --restart=unless-stopped -h mgr${count.index} --name mgr${count.index} -d -p 3375:2375 swarm manage --replication --advertise ${self.ipv4_address_private}:3375 consul://${self.ipv4_address_private}:8500/"
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
  provisioner "remote-exec" {
    inline = [
      "export PATH=$PATH:/usr/bin",
      "service docker start",
      "docker run --restart=unless-stopped -d -h consul-agt${count.index} --name consul-agt${count.index} -p 8300:8300 -p 8301:8301 -p 8301:8301/udp -p 8302:8302 -p 8302:8302/udp -p 8400:8400 -p 8500:8500 -p 8600:8600/udp progrium/consul -rejoin -advertise ${self.ipv4_address_private} -join ${digitalocean_droplet.manager-primary.ipv4_address_private}",
      "docker run -d swarm join --advertise=${self.ipv4_address_private}:2375 consul://${digitalocean_droplet.manager-primary.ipv4_address_private}:8500/"
    ]
  }
}
