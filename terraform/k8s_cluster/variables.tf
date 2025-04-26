variable "ansible_user" {
  description = "The user to run the ansible with"
  type        = string
  default     = "rozen"
} 

variable "ip_range" {
  description = "IP range for the nodes"
  type        = string
  default     = "192.168.0.210-192.168.0.225"
}

variable "num_masters" {
  description = "Number of master nodes"
  type        = number
  default     = 1
}

variable "num_workers" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "gateway" {
  default = "192.168.0.1"
}

variable "vm_template" {
  default = "k8s-node-ubuntu-24.04" # Change to your Proxmox VM template name
}

variable "vm_node" {
  default = "pve-rick" # Change to your Proxmox node name
}

variable "vm_storage" {
  default = "local-lvm" # Adjust to your storage
}

variable "network_bridge" {
  default = "vmbr0" # Change if needed
}

variable "cpu" {
  default = "2"
}

variable "memory" {
  default = "4096"
}
