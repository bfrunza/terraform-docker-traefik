data "local_file" "traefik-toml" {
    filename = "${path.module}/traefik.toml"
}
data "template_file" "traefik-toml" {
    template = "${file("${path.module}/traefik.toml")}"

    vars = {
        acme_email = "${var.acme_email}"
  }
}
resource "docker_config" "traefik-toml" {
  name = "traefik-toml-${replace(timestamp(),":", ".")}"
  data = "${base64encode(data.template_file.traefik-toml.rendered)}"

  lifecycle {
    ignore_changes = ["name"]
    create_before_destroy = true
  }
}

resource "docker_volume" "traefik_acme" {
  name = "traefik_acme"
  driver = "local-persist"
  driver_opts = {
      "mountpoint" = "${var.acme_volume_mountpoint}"
  }
}
resource "docker_service" "traefik" {
    name = "traefik-service"

    task_spec {
        container_spec {
            image = "traefik"

            labels {
                traefik.frontend.rule = "Host:${var.url}"
                traefik.port = 8080
                traefik.docker.network = "${var.traefik_network}"
                }

            configs = [
                {
                    config_id   = "${docker_config.traefik-toml.id}"
                    config_name = "${docker_config.traefik-toml.name}"
                    file_name = "/traefik.toml"
                },
            ]

            mounts = [
                {
                    target      = "/var/run/docker.sock"
                    source      = "/var/run/docker.sock"
                    type        = "bind"
                    read_only   = true
                },
                {
                    source      = "${docker_volume.traefik_acme.name}"
                    target      = "/etc/traefik/acme"   
                    type        = "volume"
                    read_only   = false
                },
                
            ]
        }
        networks     = ["${var.networks}"]
    }

    endpoint_spec {
      ports {
        target_port = "80"
        published_port = "80"
      }
      ports {
        target_port = "443"
        published_port = "443"
      }
    }
}