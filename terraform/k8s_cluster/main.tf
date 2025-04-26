# reference https://github.com/ChristianLempa/boilerplates/blob/main/terraform/proxmox/vmqemu.tf

terraform {
  required_version = ">= 0.13.0"

  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.1-rc6"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.3.0"
    }
  }
}

provider "proxmox" {
  pm_api_url      = "https://192.168.0.110:8006/api2/json"
  pm_api_token_id = "root@pam!a1"
  pm_api_token_secret = ""
  pm_tls_insecure = true # Set to false if using valid SSL certs
}


resource "proxmox_vm_qemu" "masters" {
  count       = var.num_masters
  name        = "master-${count.index + 1}"
  target_node = var.vm_node
  clone       = var.vm_template
  full_clone  = true

  cores   = var.cpu
  memory  = var.memory
  sockets = 1

  agent = 1
  onboot = true 
  startup = ""  # <-- (Optional) Change startup and shutdown behavior
  automatic_reboot = false  # <-- Automatically reboot the VM after config change

  network {
    id = 0
    bridge = var.network_bridge
    model  = "virtio"
  }

  disks {  # <-- ! changed in 3.x.x
    ide {
      ide0 {
        cloudinit {
          storage = var.vm_storage
        }
      }
    }
    virtio {
      virtio0 {
        disk {
          storage = var.vm_storage
          size = "20G"  # <-- Change the desired disk size, ! since 3.x.x size change will trigger a disk resize
          iothread = true  # <-- (Optional) Enable IOThread for better disk performance in virtio-scsi-single
          replicate = false  # <-- (Optional) Enable for disk replication
        }
      }
    }
  }

  os_type    = "cloud-init"
  ipconfig0 = "ip=${local.master_ips[count.index]}/24,gw=${var.gateway}"
}


resource "proxmox_vm_qemu" "workers" {
  count       = var.num_workers
  name        = "worker-${count.index + 1}"
  target_node = var.vm_node
  clone       = var.vm_template
  full_clone  = true

  cores   = var.cpu
  memory  = var.memory
  sockets = 1

  agent = 1
  onboot = true 
  startup = ""  # <-- (Optional) Change startup and shutdown behavior
  automatic_reboot = false  # <-- Automatically reboot the VM after config change

  network {
    id     = 0  # <-- ! required since 3.x.x
    bridge = var.network_bridge
    model  = "virtio"
  }

  disks {  # <-- ! changed in 3.x.x
    ide {
      ide0 {
        cloudinit {
          storage = var.vm_storage
        }
      }
    }
    virtio {
      virtio0 {
        disk {
          storage = var.vm_storage
          size = "20G"  # <-- Change the desired disk size, ! since 3.x.x size change will trigger a disk resize
          iothread = true  # <-- (Optional) Enable IOThread for better disk performance in virtio-scsi-single
          replicate = false  # <-- (Optional) Enable for disk replication
        }
      }
    }
  }

  os_type    = "cloud-init"
  ipconfig0 = "ip=${local.worker_ips[count.index]}/24,gw=${var.gateway}"
}

resource "null_resource" "get_user" {
  provisioner "local-exec" {
    command = "whoami"
    interpreter = ["bash", "-c"]
  }

  triggers = {
    always_run = timestamp()
  }
}

resource "local_file" "ansible_inventory" {
  filename = "./ansible/inventory.ini"
  content  = <<EOT
[masters]
%{for i, ip in local.master_ips ~}
master-${i + 1} ansible_host=${ip}
%{endfor}

[workers]
%{for i, ip in local.worker_ips ~}
worker-${i + 1} ansible_host=${ip}
%{endfor}

[all:vars]
ansible_user=${var.ansible_user}
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOT
}

resource "null_resource" "run_ansible" {
  depends_on = [local_file.ansible_inventory, proxmox_vm_qemu.masters, proxmox_vm_qemu.workers]

  provisioner "local-exec" {
    command = "ansible-playbook -i ./ansible/inventory.ini ./ansible/configure_cluster.yml"
  }

  triggers = {
    always_run = timestamp()
  }
}
