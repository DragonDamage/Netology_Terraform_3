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
