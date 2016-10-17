output "Swarm Details" {
  value = "Your management node: `https://${digitalocean_droplet.manager-primary.ipv4_address}:3375`\n\tYour certificates are located in `certs/`, ca.pem."
}
