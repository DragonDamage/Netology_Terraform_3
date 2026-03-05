## Основы работы с Terraform

### Решение 1
#### `main.tf`
```bash
terraform {
 required_providers {
   yandex = {
     source  = "yandex-cloud/yandex"
   }
 }
 required_version = ">= 1.13.0"
}

provider "yandex" {
 service_account_key_file = var.service_account_key_file
 cloud_id                 = var.cloud_id
 folder_id                = var.folder_id
}

resource "yandex_iam_service_account" "sa" {
 name        = "vm-creator-sa"
 folder_id   = var.folder_id
 description = "Service account for creating VMs"
}

resource "yandex_iam_service_account_key" "sa_key" {
 service_account_id = yandex_iam_service_account.sa.id
 description        = "Key for VM creator SA"
}

resource "yandex_vpc_network" "network" {
 name = "default-network"
}

resource "yandex_vpc_subnet" "subnet" {
 name           = "default-subnet"
 zone           = var.subnet_zone
 network_id     = yandex_vpc_network.network.id
 v4_cidr_blocks = ["10.0.0.0/16"]
}

resource "yandex_vpc_security_group" "allow_ssh" {
 name        = "allow-ssh"
 network_id  = yandex_vpc_network.network.id
 description = "Allow SSH access"

 ingress {
   protocol       = "TCP"
   description    = "Allow SSH from anywhere"
   from_port      = 22
   to_port        = 22
   v4_cidr_blocks = ["0.0.0.0/0"]
 }

 egress {
   protocol       = "ANY"
   description    = "Allow all egress traffic"
   from_port      = 0
   to_port        = 0
   v4_cidr_blocks = ["0.0.0.0/0"]
 }
}

resource "yandex_compute_instance" "vm" {
 name                      = "my-vm"
 hostname                  = "my-vm"
 folder_id                 = var.folder_id
 zone                      = var.subnet_zone
 platform_id               = "standard-v2"
 service_account_id        = yandex_iam_service_account.sa.id
 
 network_interface {
   subnet_id           = yandex_vpc_subnet.subnet.id
   nat                 = true 
 }

 metadata = {
   ssh-keys = "ubuntu:${file(var.vms_ssh_public_key_path)}"
 }

 boot_disk {
   initialize_params {
     image_id = "fd86rorl7r6l2nq3ate6" 
     size     = 30
     type     = "network-hdd"
   }
 }

 resources {
   memory = 2
   cores  = 2
 }

 scheduling_policy {
   preemptible = true 
 }
}

output "vm_external_ip" {
 description = "External IP address of the VM"
 value       = yandex_compute_instance.vm.network_interface[0].nat_ip_address
}

output "service_account_key" {
 description = "Service account key"
 value       = yandex_iam_service_account_key.sa_key.id
 sensitive   = true
}
```

#### `main.tf`
```bash
variable "service_account_key_file" {
  description = "Path to the service account key file"
  type        = string
}

variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
}

variable "subnet_zone" {
  description = "Zone for the VM and subnet"
  type        = string
  default     = "ru-central1-a"
}

variable "vms_ssh_public_key_path" {
  description = "Path to the public SSH key"
  type        = string
}
```

<img width="1115" height="163" alt="image" src="https://github.com/user-attachments/assets/97e14894-2c28-457e-b08d-3625749af14c" />

<img width="930" height="844" alt="image" src="https://github.com/user-attachments/assets/abeb20f3-0745-4e59-8d78-41d16b57b92d" />

<img width="745" height="287" alt="image" src="https://github.com/user-attachments/assets/8dbff96e-f41c-4261-8fea-01bd6e027b4e" />

<img width="347" height="47" alt="image" src="https://github.com/user-attachments/assets/8e3b48f4-a658-4929-96c3-6054ae14d10e" />

Вопрос: В чём заключается суть намеренно допущенных синтаксических ошибок?
Сложности возникли из-за комбинации намеренных ошибок и конфликтов версий:

Конфликт версий провайдера (v0.168.0): Исходный код использовал современный синтаксис (например, блок nat {}, аргумент security_groups внутри network_interface), который не поддерживался выбранной Terraform версией провайдера. Это потребовало ручной адаптации синтаксиса (например, использование nat = true и исключение привязки Security Group из блока ВМ).
Неправильные ссылки на ресурсы/атрибуты: Использование несуществующего ресурса yandex_compute_address для получения IP и некорректная ссылка на атрибут VPC default_route_table_id.
Некорректный ID образа: Использование короткого имени (image_id = "ubuntu-2004-lts") вместо image_id = "fd86rorl7r6l2nq3ate6" в блоке boot_disk, что приводило к ошибке API.


Вопрос: Как в процессе обучения могут пригодиться параметры preemptible = true и core_fraction=5 в параметрах ВМ?

preemptible = true: Экономия средств для тестовых и лабораторных сред (прерываемые ВМ значительно дешевле) и возможность изучения отказоустойчивости. Разработчик учится проектировать системы, способные корректно обрабатывать внезапное прекращение работы инстанса.
core_fraction=5: Используется для создания виртуальных машин с низкой гарантированной производительностью (Burstable VMs). Полезно для оптимизации затрат и для тестирования приложений в условиях ограниченных вычислительных ресурсов, что помогает определить минимально необходимые требования к CPU.

### Решение 2
#### `main.tf`
```bash
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 1.13.0"
}

provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
}

resource "yandex_iam_service_account" "sa" {
  name        = var.sa_name
  folder_id   = var.folder_id
  description = "Service account for creating VMs"
}

resource "yandex_iam_service_account_key" "sa_key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "Key for VM creator SA"
}

resource "yandex_vpc_network" "network" {
  name = var.network_name
}

resource "yandex_vpc_subnet" "subnet" {
  name           = var.subnet_name
  zone           = var.subnet_zone
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = var.subnet_cidr_blocks
}

resource "yandex_vpc_security_group" "allow_ssh" {
  name        = var.sg_name
  network_id  = yandex_vpc_network.network.id
  description = "Allow SSH access"

  ingress {
    protocol       = "TCP"
    description    = "Allow SSH from anywhere"
    from_port      = var.ssh_port
    to_port        = var.ssh_port
    v4_cidr_blocks = var.allowed_cidr_blocks_ssh
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all egress traffic"
    from_port      = 0
    to_port        = 0
    v4_cidr_blocks = var.allowed_cidr_blocks_ssh
  }
}

resource "yandex_compute_instance" "vm" {
  name                      = var.vm_web_name
  hostname                  = var.vm_web_name
  folder_id                 = var.folder_id
  zone                      = var.subnet_zone
  platform_id               = var.vm_web_platform_id
  service_account_id        = yandex_iam_service_account.sa.id
  
  network_interface {
    subnet_id           = yandex_vpc_subnet.subnet.id
    nat                 = true 
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.vms_ssh_public_key_path)}"
  }

  boot_disk {
    initialize_params {
      image_id     = var.vm_web_image_id
      size         = var.vm_web_disk_size
      type         = var.vm_web_disk_type
    }
  }

  resources {
    memory = var.vm_web_memory
    cores  = var.vm_web_cores
  }

  scheduling_policy {
    preemptible = true 
  }
}

output "vm_external_ip" {
  description = "External IP address of the VM"
  value       = yandex_compute_instance.vm.network_interface[0].nat_ip_address
}

output "service_account_key" {
  description = "Service account key"
  value       = yandex_iam_service_account_key.sa_key.id
  sensitive   = true
}
```

#### `variables.tf`
```bash
variable "service_account_key_file" {
  description = "Path to the service account key file"
  type        = string
}

variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
}

variable "subnet_zone" {
  description = "Zone for the VM and subnet"
  type        = string
  default     = "ru-central1-a"
}

variable "vms_ssh_public_key_path" {
  description = "Path to the public SSH key"
  type        = string
}

variable "vm_web_name" {
  description = "Name for the web VM instance"
  type        = string
  default     = "my-vm"
}

variable "vm_web_platform_id" {
  description = "Platform ID for the VM"
  type        = string
  default     = "standard-v2"
}

variable "vm_web_image_id" {
  description = "Image ID or family for the boot disk"
  type        = string
  default     = "fd86rorl7r6l2nq3ate6"
}

variable "vm_web_disk_size" {
  description = "Size of the boot disk in GB"
  type        = number
  default     = 30
}

variable "vm_web_disk_type" {
  description = "Type of the network disk"
  type        = string
  default     = "network-hdd"
}

variable "vm_web_memory" {
  description = "Memory size in GB"
  type        = number
  default     = 2
}

variable "vm_web_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "sa_name" {
  description = "Name for the Service Account"
  type        = string
  default     = "vm-creator-sa"
}

variable "network_name" {
  description = "Name for the VPC Network"
  type        = string
  default     = "default-network"
}

variable "subnet_name" {
  description = "Name for the VPC Subnet"
  type        = string
  default     = "default-subnet"
}

variable "subnet_cidr_blocks" {
  description = "CIDR block for the subnet"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "sg_name" {
  description = "Name for the Security Group"
  type        = string
  default     = "allow-ssh"
}

variable "ssh_port" {
  description = "Port for SSH access"
  type        = number
  default     = 22
}

variable "allowed_cidr_blocks_ssh" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
```
<img width="543" height="805" alt="image" src="https://github.com/user-attachments/assets/059ae22f-ff70-4e8d-9a2e-06a20c19505a" />

### Решение 3
#### `main.tf`
```bash
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 1.13.0"
}

provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
}

resource "yandex_iam_service_account" "sa" {
  name        = var.sa_name
  folder_id   = var.folder_id
  description = "Service account for creating VMs"
}

resource "yandex_iam_service_account_key" "sa_key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "Key for VM creator SA"
}

resource "yandex_vpc_network" "network" {
  name = var.network_name
}

resource "yandex_vpc_subnet" "subnet" {
  name           = var.subnet_name
  zone           = var.subnet_zone
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = var.subnet_cidr_blocks
}

resource "yandex_vpc_security_group" "allow_ssh" {
  name        = var.sg_name
  network_id  = yandex_vpc_network.network.id
  description = "Allow SSH access"

  ingress {
    protocol       = "TCP"
    description    = "Allow SSH from anywhere"
    from_port      = var.ssh_port
    to_port        = var.ssh_port
    v4_cidr_blocks = var.allowed_cidr_blocks_ssh
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all egress traffic"
    from_port      = 0
    to_port        = 0
    v4_cidr_blocks = var.allowed_cidr_blocks_ssh
  }
}

resource "yandex_compute_instance" "vm_web" {
  name                      = var.vm_web_name
  folder_id                 = var.folder_id
  zone                      = var.subnet_zone
  platform_id               = var.vm_web_platform_id
  service_account_id        = yandex_iam_service_account.sa.id
  hostname                  = var.vm_web_name 
  
  network_interface {
    subnet_id           = yandex_vpc_subnet.subnet.id
    nat                 = true 
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.vms_ssh_public_key_path)}"
  }

  boot_disk {
    initialize_params {
      image_id     = var.vm_web_image_id
      size         = var.vm_web_disk_size
      type         = var.vm_web_disk_type
    }
  }

  resources {
    memory = var.vm_web_memory
    cores  = var.vm_web_cores
  }

  scheduling_policy {
    preemptible = true 
  }
}

resource "yandex_vpc_subnet" "subnet_db" {
  name           = "default-subnet-db"
  zone           = var.vm_db_zone
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"] 
}

resource "yandex_compute_instance" "vm_db" {
  name                      = var.vm_db_name
  folder_id                 = var.folder_id
  zone                      = var.vm_db_zone # ru-central1-b
  platform_id               = var.vm_db_platform_id
  service_account_id        = yandex_iam_service_account.sa.id
  hostname                  = var.vm_db_name 
  
  network_interface {
    subnet_id           = yandex_vpc_subnet.subnet_db.id 
    nat                 = true 
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.vms_ssh_public_key_path)}"
  }

  boot_disk {
    initialize_params {
      image_id     = var.vm_db_image_id
      size         = var.vm_db_disk_size
      type         = var.vm_db_disk_type
    }
  }

  resources {
    memory        = var.vm_db_memory
    cores         = var.vm_db_cores
    core_fraction = var.vm_db_core_fraction # core_fraction = 20
  }

  scheduling_policy {
    preemptible = false 
  }
}

output "vm_web_external_ip" {
  description = "External IP address of the WEB VM"
  value       = yandex_compute_instance.vm_web.network_interface[0].nat_ip_address
}

output "vm_db_external_ip" {
  description = "External IP address of the DB VM"
  value       = yandex_compute_instance.vm_db.network_interface[0].nat_ip_address
}
```

#### `variables.tf`
```bash
variable "service_account_key_file" {
  description = "Path to the service account key file"
  type        = string
}

variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
}

variable "subnet_zone" {
  description = "Zone for the WEB VM and shared subnet (default ru-central1-a)"
  type        = string
  default     = "ru-central1-a"
}

variable "vms_ssh_public_key_path" {
  description = "Path to the public SSH key"
  type        = string
}

variable "sa_name" {
  description = "Name for the Service Account"
  type        = string
  default     = "vm-creator-sa"
}

variable "network_name" {
  description = "Name for the VPC Network"
  type        = string
  default     = "default-network"
}

variable "subnet_name" {
  description = "Name for the VPC Subnet"
  type        = string
  default     = "default-subnet"
}

variable "subnet_cidr_blocks" {
  description = "CIDR block for the subnet"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "sg_name" {
  description = "Name for the Security Group"
  type        = string
  default     = "allow-ssh"
}

variable "ssh_port" {
  description = "Port for SSH access"
  type        = number
  default     = 22
}

variable "allowed_cidr_blocks_ssh" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
```

#### `vms_platform.tf`
```bash
variable "vm_web_name" {
  description = "Name for the web VM instance"
  type        = string
  default     = "my-vm"
}

variable "vm_web_platform_id" {
  description = "Platform ID for the VM"
  type        = string
  default     = "standard-v2"
}

variable "vm_web_image_id" {
  description = "Image ID or family for the boot disk"
  type        = string
  default     = "fd86rorl7r6l2nq3ate6"
}

variable "vm_web_disk_size" {
  description = "Size of the boot disk in GB"
  type        = number
  default     = 30
}

variable "vm_web_disk_type" {
  description = "Type of the network disk"
  type        = string
  default     = "network-hdd"
}

variable "vm_web_memory" {
  description = "Memory size in GB"
  type        = number
  default     = 2
}

variable "vm_web_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "vm_db_name" {
  description = "Name for the DB VM instance"
  type        = string
  default     = "netology-develop-platform-db"
}

variable "vm_db_zone" {
  description = "Zone for the DB VM"
  type        = string
  default     = "ru-central1-b"
}

variable "vm_db_cores" {
  description = "Number of CPU cores for DB VM"
  type        = number
  default     = 2
}

variable "vm_db_memory" {
  description = "Memory size in GB for DB VM"
  type        = number
  default     = 2
}

variable "vm_db_core_fraction" {
  description = "Guaranteed core fraction for DB VM"
  type        = number
  default     = 20
}

variable "vm_db_platform_id" {
  description = "Platform ID for the DB VM (reuse standard-v2)"
  type        = string
  default     = "standard-v2"
}

variable "vm_db_image_id" {
  description = "Image ID or family for the DB boot disk"
  type        = string
  default     = "fd86rorl7r6l2nq3ate6"
}

variable "vm_db_disk_size" {
  description = "Size of the DB boot disk in GB"
  type        = number
  default     = 30
}

variable "vm_db_disk_type" {
  description = "Type of the DB network disk"
  type        = string
  default     = "network-hdd"
}
```

### Решение 4
#### `outputs.tf`
```bash
output "vms_details" {
  description = "Detailed information for all created VMs (name, IP, FQDN)"
  value = {
    vm_web = {
      instance_name = yandex_compute_instance.vm_web.name
      external_ip   = yandex_compute_instance.vm_web.network_interface[0].nat_ip_address
      fqdn          = yandex_compute_instance.vm_web.fqdn
    }
    vm_db = {
      instance_name = yandex_compute_instance.vm_db.name
      external_ip   = yandex_compute_instance.vm_db.network_interface[0].nat_ip_address
      fqdn          = yandex_compute_instance.vm_db.fqdn
    }
  }
}
```

Вывод команды `terraform output`
```bash
vms_details = {
  "vm_db" = {
    "external_ip" = "89.169.185.190"
    "fqdn" = "netology-develop-platform-db.ru-central1.internal"
    "instance_name" = "netology-develop-platform-db"
  }
  "vm_web" = {
    "external_ip" = "62.84.126.13"
    "fqdn" = "my-vm.ru-central1.internal"
    "instance_name" = "my-vm"
  }
}
```

### Решение 5

Вывод команды `terraform apply`

```bash
Apply complete! Resources: 2 added, 1 changed, 2 destroyed.

Outputs:

vms_details = {
  "vm_db" = {
    "external_ip" = "89.169.181.216"
    "fqdn" = "netology-develop-platform-db-ru-central1-b.ru-central1.internal"
    "instance_name" = "netology-develop-platform-db-ru-central1-b"
  }
  "vm_web" = {
    "external_ip" = "89.169.159.204"
    "fqdn" = "my-vm-ru-central1-a-b1ga.ru-central1.internal"
    "instance_name" = "my-vm-ru-central1-a-b1ga"
  }
}
```

#### `locals.tf`
```bash
locals {
  vm_web_full_name = "${var.vm_web_name}-${var.subnet_zone}-${substr(var.folder_id, 0, 4)}"
  vm_db_full_name = "${var.vm_db_name}-${var.vm_db_zone}"
}
```

#### `main.tf`
```bash
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 1.13.0"
}

provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
}

resource "yandex_iam_service_account" "sa" {
  name        = var.sa_name
  folder_id   = var.folder_id
  description = "Service account for creating VMs"
}

resource "yandex_iam_service_account_key" "sa_key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "Key for VM creator SA"
}

resource "yandex_vpc_network" "network" {
  name = var.network_name
}

resource "yandex_vpc_subnet" "subnet" {
  name           = var.subnet_name
  zone           = var.subnet_zone
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = var.subnet_cidr_blocks
}

resource "yandex_vpc_security_group" "allow_ssh" {
  name        = var.sg_name
  network_id  = yandex_vpc_network.network.id
  description = "Allow SSH access"

  ingress {
    protocol       = "TCP"
    description    = "Allow SSH from anywhere"
    from_port      = var.ssh_port
    to_port        = var.ssh_port
    v4_cidr_blocks = var.allowed_cidr_blocks_ssh
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all egress traffic"
    from_port      = 0
    to_port        = 0
    v4_cidr_blocks = var.allowed_cidr_blocks_ssh
  }
}

resource "yandex_compute_instance" "vm_web" {
  name                      = local.vm_web_full_name
  hostname                  = local.vm_web_full_name
  folder_id                 = var.folder_id
  zone                      = var.subnet_zone
  platform_id               = var.vm_web_platform_id
  service_account_id        = yandex_iam_service_account.sa.id
  
  network_interface {
    subnet_id           = yandex_vpc_subnet.subnet.id
    nat                 = true 
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.vms_ssh_public_key_path)}"
  }

  boot_disk {
    initialize_params {
      image_id     = var.vm_web_image_id
      size         = var.vm_web_disk_size
      type         = var.vm_web_disk_type
    }
  }

  resources {
    memory = var.vm_web_memory
    cores  = var.vm_web_cores
  }

  scheduling_policy {
    preemptible = true 
  }
}

resource "yandex_vpc_subnet" "subnet_db" {
  name           = "default-subnet-db"
  zone           = var.vm_db_zone
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"] 
}

resource "yandex_compute_instance" "vm_db" {
  name                      = local.vm_db_full_name
  hostname                  = local.vm_db_full_name
  folder_id                 = var.folder_id
  zone                      = var.vm_db_zone # ru-central1-b
  platform_id               = var.vm_db_platform_id
  service_account_id        = yandex_iam_service_account.sa.id
  
  network_interface {
    subnet_id           = yandex_vpc_subnet.subnet_db.id 
    nat                 = true 
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.vms_ssh_public_key_path)}"
  }

  boot_disk {
    initialize_params {
      image_id     = var.vm_db_image_id
      size         = var.vm_db_disk_size
      type         = var.vm_db_disk_type
    }
  }

  resources {
    memory        = var.vm_db_memory
    cores         = var.vm_db_cores
    core_fraction = var.vm_db_core_fraction # core_fraction = 20
  }

  scheduling_policy {
    preemptible = false 
  }
}
```

#### `outputs.tf`
```bash
output "vms_details" {
  description = "Detailed information for all created VMs (name, IP, FQDN)"
  value = {
    vm_web = {
      instance_name = yandex_compute_instance.vm_web.name
      external_ip   = yandex_compute_instance.vm_web.network_interface[0].nat_ip_address
      fqdn          = yandex_compute_instance.vm_web.fqdn
    }
    vm_db = {
      instance_name = yandex_compute_instance.vm_db.name
      external_ip   = yandex_compute_instance.vm_db.network_interface[0].nat_ip_address
      fqdn          = yandex_compute_instance.vm_db.fqdn
    }
  }
}
```

#### `variables.tf`
```bash
variable "service_account_key_file" {
  description = "Path to the service account key file"
  type        = string
}

variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
}

variable "subnet_zone" {
  description = "Zone for the WEB VM and shared subnet (default ru-central1-a)"
  type        = string
  default     = "ru-central1-a"
}

variable "vms_ssh_public_key_path" {
  description = "Path to the public SSH key"
  type        = string
}

variable "sa_name" {
  description = "Name for the Service Account"
  type        = string
  default     = "vm-creator-sa"
}

variable "network_name" {
  description = "Name for the VPC Network"
  type        = string
  default     = "default-network"
}

variable "subnet_name" {
  description = "Name for the VPC Subnet"
  type        = string
  default     = "default-subnet"
}

variable "subnet_cidr_blocks" {
  description = "CIDR block for the subnet"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "sg_name" {
  description = "Name for the Security Group"
  type        = string
  default     = "allow-ssh"
}

variable "ssh_port" {
  description = "Port for SSH access"
  type        = number
  default     = 22
}

variable "allowed_cidr_blocks_ssh" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
```

#### `vms_platform.tf`
```bash
variable "vm_web_name" {
  description = "Name for the web VM instance"
  type        = string
  default     = "my-vm"
}

variable "vm_web_platform_id" {
  description = "Platform ID for the VM"
  type        = string
  default     = "standard-v2"
}

variable "vm_web_image_id" {
  description = "Image ID or family for the boot disk"
  type        = string
  default     = "fd86rorl7r6l2nq3ate6"
}

variable "vm_web_disk_size" {
  description = "Size of the boot disk in GB"
  type        = number
  default     = 30
}

variable "vm_web_disk_type" {
  description = "Type of the network disk"
  type        = string
  default     = "network-hdd"
}

variable "vm_web_memory" {
  description = "Memory size in GB"
  type        = number
  default     = 2
}

variable "vm_web_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "vm_db_name" {
  description = "Name for the DB VM instance"
  type        = string
  default     = "netology-develop-platform-db"
}

variable "vm_db_zone" {
  description = "Zone for the DB VM"
  type        = string
  default     = "ru-central1-b"
}

variable "vm_db_cores" {
  description = "Number of CPU cores for DB VM"
  type        = number
  default     = 2
}

variable "vm_db_memory" {
  description = "Memory size in GB for DB VM"
  type        = number
  default     = 2
}

variable "vm_db_core_fraction" {
  description = "Guaranteed core fraction for DB VM"
  type        = number
  default     = 20
}

variable "vm_db_platform_id" {
  description = "Platform ID for the DB VM (reuse standard-v2)"
  type        = string
  default     = "standard-v2"
}

variable "vm_db_image_id" {
  description = "Image ID or family for the DB boot disk"
  type        = string
  default     = "fd86rorl7r6l2nq3ate6"
}

variable "vm_db_disk_size" {
  description = "Size of the DB boot disk in GB"
  type        = number
  default     = 30
}

variable "vm_db_disk_type" {
  description = "Type of the DB network disk"
  type        = string
  default     = "network-hdd"
}
```

### Решение 6

#### `locals.tf`
```bash
locals {
  vm_web_full_name = "${var.vm_web_name}-${var.subnet_zone}-${substr(var.folder_id, 0, 4)}"
  vm_db_full_name = "${var.vm_db_name}-${var.vm_db_zone}"
}
```

#### `main.tf`
```bash
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 1.13.0"
}

provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
}

resource "yandex_iam_service_account" "sa" {
  name        = var.sa_name
  folder_id   = var.folder_id
  description = "Service account for creating VMs"
}

resource "yandex_iam_service_account_key" "sa_key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "Key for VM creator SA"
}

resource "yandex_vpc_network" "network" {
  name = var.network_name
}

resource "yandex_vpc_subnet" "subnet" {
  name           = var.subnet_name
  zone           = var.subnet_zone
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = var.subnet_cidr_blocks
}

resource "yandex_vpc_security_group" "allow_ssh" {
  name        = var.sg_name
  network_id  = yandex_vpc_network.network.id
  description = "Allow SSH access"

  ingress {
    protocol       = "TCP"
    description    = "Allow SSH from anywhere"
    from_port      = var.ssh_port
    to_port        = var.ssh_port
    v4_cidr_blocks = var.allowed_cidr_blocks_ssh
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all egress traffic"
    from_port      = 0
    to_port        = 0
    v4_cidr_blocks = var.allowed_cidr_blocks_ssh
  }
}

resource "yandex_compute_instance" "vm_web" {
  name                      = local.vm_web_full_name
  folder_id                 = var.folder_id
  zone                      = var.subnet_zone
  platform_id               = var.vm_web_platform_id
  service_account_id        = yandex_iam_service_account.sa.id
  hostname                  = local.vm_web_full_name
  
  network_interface {
    subnet_id           = yandex_vpc_subnet.subnet.id
    nat                 = true 
  }

  metadata = merge(
    var.metadata_config, 
    {
      "ssh-keys" = "ubuntu:${file(var.vms_ssh_public_key_path)}"
    }
  )
  boot_disk {
    initialize_params {
      image_id     = var.vm_web_image_id
      size         = var.vms_resources["web"].disk_size
      type         = var.vms_resources["web"].disk_type
    }
  }

  resources {
    memory        = var.vms_resources["web"].memory
    cores         = var.vms_resources["web"].cores
    core_fraction = var.vms_resources["web"].core_fraction
  }

  scheduling_policy {
    preemptible = true 
  }
}

resource "yandex_vpc_subnet" "subnet_db" {
  name           = "default-subnet-db"
  zone           = var.vm_db_zone
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"] 
}

resource "yandex_compute_instance" "vm_db" {
  name                      = local.vm_db_full_name
  folder_id                 = var.folder_id
  zone                      = var.vm_db_zone # ru-central1-b
  platform_id               = var.vm_db_platform_id
  service_account_id        = yandex_iam_service_account.sa.id
  hostname                  = local.vm_db_full_name
  
  network_interface {
    subnet_id           = yandex_vpc_subnet.subnet_db.id 
    nat                 = true 
  }

  metadata = merge(
    var.metadata_config, 
    {
      "ssh-keys" = "ubuntu:${file(var.vms_ssh_public_key_path)}"
    }
  )

  boot_disk {
    initialize_params {
      image_id     = var.vm_db_image_id
      size         = var.vms_resources["db"].disk_size
      type         = var.vms_resources["db"].disk_type
    }
  }

  resources {
    memory        = var.vms_resources["db"].memory
    cores         = var.vms_resources["db"].cores
    core_fraction = var.vms_resources["db"].core_fraction
  }

  scheduling_policy {
    preemptible = false 
  }
}
```

#### `outputs.tf`
```bash
output "vms_details" {
  description = "Detailed information for all created VMs (name, IP, FQDN)"
  value = {
    vm_web = {
      instance_name = yandex_compute_instance.vm_web.name
      external_ip   = yandex_compute_instance.vm_web.network_interface[0].nat_ip_address
      fqdn          = yandex_compute_instance.vm_web.fqdn
    }
    vm_db = {
      instance_name = yandex_compute_instance.vm_db.name
      external_ip   = yandex_compute_instance.vm_db.network_interface[0].nat_ip_address
      fqdn          = yandex_compute_instance.vm_db.fqdn
    }
  }
}
```

#### `variables.tf`
```bash
variable "service_account_key_file" {
  description = "Path to the service account key file"
  type        = string
}

variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
}

variable "subnet_zone" {
  description = "Zone for the WEB VM and shared subnet (default ru-central1-a)"
  type        = string
  default     = "ru-central1-a"
}

variable "vms_ssh_public_key_path" {
  description = "Path to the public SSH key"
  type        = string
}

variable "sa_name" {
  description = "Name for the Service Account"
  type        = string
  default     = "vm-creator-sa"
}

variable "network_name" {
  description = "Name for the VPC Network"
  type        = string
  default     = "default-network"
}

variable "subnet_name" {
  description = "Name for the VPC Subnet"
  type        = string
  default     = "default-subnet"
}

variable "subnet_cidr_blocks" {
  description = "CIDR block for the subnet"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "sg_name" {
  description = "Name for the Security Group"
  type        = string
  default     = "allow-ssh"
}

variable "ssh_port" {
  description = "Port for SSH access"
  type        = number
  default     = 22
}

variable "allowed_cidr_blocks_ssh" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vms_resources" {
  description = "Map of resource configurations (cores, memory, disk) for all VMs"
  type = map(object({
    cores         = number
    memory        = number
    core_fraction = number
    disk_size     = number
    disk_type     = string
  }))
  default = {
    web = {
      cores         = 2
      memory        = 2
      core_fraction = 100 
      disk_size     = 30
      disk_type     = "network-hdd"
    }
    db = {
      cores         = 2
      memory        = 2
      core_fraction = 20 
      disk_size     = 30
      disk_type     = "network-hdd"
    }
  }
}

variable "metadata_config" {
  description = "Static metadata configuration common to all VMs"
  type        = map(string)
  default = {
    serial-port-enable = "1"
    ssh-keys           = "placeholder" 
  }
}
```

#### `vms_platform.tf`
```bash
variable "vm_web_name" {
  description = "Name for the web VM instance"
  type        = string
  default     = "my-vm"
}

variable "vm_web_platform_id" {
  description = "Platform ID for the VM"
  type        = string
  default     = "standard-v2"
}

variable "vm_web_image_id" {
  description = "Image ID or family for the boot disk"
  type        = string
  default     = "fd86rorl7r6l2nq3ate6"
}

variable "vm_db_name" {
  description = "Name for the DB VM instance"
  type        = string
  default     = "netology-develop-platform-db"
}

variable "vm_db_zone" {
  description = "Zone for the DB VM"
  type        = string
  default     = "ru-central1-b"
}

variable "vm_db_platform_id" {
  description = "Platform ID for the DB VM (reuse standard-v2)"
  type        = string
  default     = "standard-v2"
}

variable "vm_db_image_id" {
  description = "Image ID or family for the DB boot disk"
  type        = string
  default     = "fd86rorl7r6l2nq3ate6"
}
```



<img width="662" height="824" alt="image" src="https://github.com/user-attachments/assets/1b269d0f-4cf1-4198-a17e-055dfefb75d4" />


