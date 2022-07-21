
locals {
  cloud_id = "b1gj0lkqgjr1me8s1in8"
  folder_id = "b1g1kjojfaduldiklc0o"
  service_account_id = "aje1ccbvogtjcv59e0l9"
}

# Provider
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "tf-back-korsh-diplom"
    region     = "ru-central1"
    key        = "backend-s3/terraform.tfstate"
    access_key = "..."
    secret_key = "..."
    skip_region_validation      = true
    skip_credentials_validation = true
  }
}

provider "yandex" {
  service_account_key_file = "key.json"
  cloud_id  = local.cloud_id
  folder_id = local.folder_id
}

######### # Создаем публичную DNS зону
resource "yandex_dns_zone" "dns-avkorsh" {
  name             = "avkorsh-zone"
  zone             = "avkorsh.ru."
  public           = true
}

resource "yandex_dns_recordset" "main-a-record-avkorsh" {
  zone_id = yandex_dns_zone.dns-avkorsh.id
  name    = "avkorsh.ru."
  type    = "A"
  ttl     = 600
  data    = ["62.84.126.100"]
}


resource "yandex_dns_recordset" "wild-avkorsh-record" {
  zone_id = yandex_dns_zone.dns-avkorsh.id
  name    = "*"
  type    = "A"
  ttl     = 600
  data    = ["62.84.126.100"]
}


resource "yandex_vpc_network" "tf-korsh-net" {
  name = "korsh-net"
}

resource "yandex_vpc_subnet" "tf-korsh-subnet-a" {
  name = "korsh-subnet-a"
  zone           = "ru-central1-a"
  network_id     = "${yandex_vpc_network.tf-korsh-net.id}"
  v4_cidr_blocks = ["192.168.101.0/24"]
  route_table_id = "${yandex_vpc_route_table.my-nat.id}"
}

resource "yandex_vpc_subnet" "tf-korsh-subnet-b" {
  name = "korsh-subnet-b"
  zone           = "ru-central1-b"
  network_id     = "${yandex_vpc_network.tf-korsh-net.id}"
  v4_cidr_blocks = ["192.168.102.0/24"]
  route_table_id = "${yandex_vpc_route_table.my-nat.id}"
}

resource "yandex_vpc_subnet" "tf-korsh-subnet-c" {
  name = "korsh-subnet-c"
  zone           = "ru-central1-c"
  network_id     = "${yandex_vpc_network.tf-korsh-net.id}"
  v4_cidr_blocks = ["192.168.103.0/24"]
  route_table_id = "${yandex_vpc_route_table.my-nat.id}"
}

### маршрут на прокси
resource "yandex_vpc_route_table" "my-nat" {
  network_id = "${yandex_vpc_network.tf-korsh-net.id}"

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = "192.168.101.100"
  }
}

### виртуалки

resource "yandex_compute_instance" "node-nginx" {
  hostname                      = "nginx"
  zone                      = "ru-central1-a"
  name                  = "nginx"
  allow_stopping_for_update = true

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      #image_id    = "${var.centos-7-base}"
      #взял  из доступных стандартных образов ubuntu 2.04  yc compute image list --folder-id standard-images
	  image_id    = "fd8fte6bebi857ortlja"
	  name        = "root-node-nginx"
      type        = "network-ssd"
      size        = "20"
    }
  }

  network_interface {
    subnet_id = "${yandex_vpc_subnet.tf-korsh-subnet-a.id}"
    ip_address = "192.168.101.100" 
    nat       = true
    nat_ip_address    = "62.84.126.100"
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "db01-master" {
  zone                      = "ru-central1-a"
  hostname                  = "db01"
  name                  = "db01"
  allow_stopping_for_update = true

  resources {
    cores  = 2
    memory = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
          image_id    = "fd8fte6bebi857ortlja"
           size        = "10"
    }
  }

  network_interface {
    subnet_id = "${yandex_vpc_subnet.tf-korsh-subnet-a.id}"
    ip_address       = "192.168.101.101"
#    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "db02-slave" {
  zone                      = "ru-central1-b"
  hostname                  = "db02"
  name                  = "db02"
  allow_stopping_for_update = true

  resources {
    cores  = 2
    memory = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
          image_id    = "fd8fte6bebi857ortlja"
           size        = "10"
    }
  }

  network_interface {
    subnet_id = "${yandex_vpc_subnet.tf-korsh-subnet-b.id}"
    ip_address       = "192.168.102.101"
#    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "app-korsh" {
  zone                      = "ru-central1-a"
  hostname                  = "app"
  name                  = "app"
  allow_stopping_for_update = true

  resources {
    cores  = 4
    memory = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
          image_id    = "fd8fte6bebi857ortlja"
           size        = "10"
    }
  }

  network_interface {
    subnet_id = "${yandex_vpc_subnet.tf-korsh-subnet-a.id}"
    ip_address       = "192.168.101.102"
 #   nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "git-korsh" {
  hostname                  = "gitlab"
  name                  = "gitlab"
  zone                      = "ru-central1-a"
  allow_stopping_for_update = true

  resources {
    cores  = 4
    memory = 12
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
          image_id    = "fd8fte6bebi857ortlja"
           size        = "15"
    }
  }

  network_interface {
    subnet_id = "${yandex_vpc_subnet.tf-korsh-subnet-a.id}"
    ip_address       = "192.168.101.103"
  #  nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "korsh-mon" {
  hostname                  = "monitoring"
  name                  = "monitoring"
  zone                      = "ru-central1-a"
  allow_stopping_for_update = true

  resources {
    cores  = 2
    memory = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
           image_id    = "fd8fte6bebi857ortlja"
           size        = "10"
    }
  }

  network_interface {
    subnet_id = "${yandex_vpc_subnet.tf-korsh-subnet-a.id}"
    ip_address       = "192.168.101.104"
   # nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

