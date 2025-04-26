# Ubuntu Server Noble (24.04.x)
# ---
# Packer Template to create an Ubuntu Server (Noble 24.04.x) on Proxmox


# Variable Definitions
variable "proxmox_api_url" {
    type = string
}

variable "proxmox_api_token_id" {
    type = string
}

variable "proxmox_api_token_secret" {
    type = string
    sensitive = true
}

variable "k8s_version" {
  default = "v1.30"
  description = "Kubernetes version to be configured in the provisioner"
}

# Resource Definiation for the VM Template
source "proxmox-iso" "ubuntu-server-noble" {
 
    # Proxmox Connection Settings
    proxmox_url = "${var.proxmox_api_url}"
    username = "${var.proxmox_api_token_id}"
    token = "${var.proxmox_api_token_secret}"
    # (Optional) Skip TLS Verification
    insecure_skip_tls_verify = true
    
    # VM General Settings
    node = "pve-rick" # Proxmox node name
    vm_id = "201" # Not used VM ID for the packer to spin new VM
    vm_name = "k8s-node-ubuntu-24.04" # Name of the VM that will be created
    template_description = "Ubuntu Server with k8s installed"

    # VM OS Settings
    # (Option 1) Local ISO File
    # iso_file = "local:iso/ubuntu-24.04-live-server-amd64.iso"
    # - or -
    # (Option 2) Download ISO
    # iso_url = "https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso"
    # iso_checksum = "e240e4b801f7bb68c20d1356b60968ad0c33a41d00d828e74ceb3364a0317be9"
    # iso_storage_pool = "local"
    boot_iso {
        # iso_url      = "https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso" # downloading ISO from url
        iso_file = "local:iso/ubuntu-24.04.1-live-server-amd64.iso" # Using ISO file from local storage on proxmox
        iso_checksum = "sha256:e240e4b801f7bb68c20d1356b60968ad0c33a41d00d828e74ceb3364a0317be9"
        iso_storage_pool = "local"
    }

    # VM System Settings
    qemu_agent = true

    # VM Hard Disk Settings
    scsi_controller = "virtio-scsi-pci"

    disks {
        disk_size = "20G"
        format = "raw"
        storage_pool = "local-lvm"
        type = "virtio"
    }

    # VM CPU Settings
    cores = "2"
    
    # VM Memory Settings
    memory = "4096" 

    # VM Network Settings
    network_adapters {
        model = "virtio"
        bridge = "vmbr0"
        firewall = "false"
    } 

    # VM Cloud-Init Settings
    cloud_init = true
    cloud_init_storage_pool = "local-lvm"

    # PACKER Boot Commands
    boot_command = [
        "<esc><wait>",
        "e<wait>",
        "<down><down><down><end>",
        "<bs><bs><bs><bs><wait>",
        "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
        "<f10><wait>"
    ]

    boot                    = "c"
    boot_wait               = "10s"
    communicator            = "ssh"

    # PACKER Autoinstall Settings
    http_directory          = "http" 
    # (Optional) Bind IP Address and Port
    # http_bind_address       = "0.0.0.0"
    # http_port_min           = 8802
    # http_port_max           = 8802

    ssh_username            = "rozen" # SSH User

    # (Option 1) Add your Password here
    # ssh_password        = "my_cool_password"
    # - or -
    # (Option 2) Add your Private SSH KEY file here
    ssh_private_key_file    = "~/.ssh/id_rsa" # SSH Private key

    # Raise the timeout, when installation takes longer
    ssh_timeout             = "30m"
    ssh_pty                 = true
}

# Build Definition to create the VM Template
build {

    name = "ubuntu-server-noble"
    sources = ["source.proxmox-iso.ubuntu-server-noble"]

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #1
    provisioner "shell" {
        inline = [
            "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
            "sudo rm /etc/ssh/ssh_host_*",
            "sudo truncate -s 0 /etc/machine-id",
            "sudo apt -y autoremove --purge",
            "sudo apt -y clean",
            "sudo apt -y autoclean",
            "sudo cloud-init clean",
            "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
            "sudo rm -f /etc/netplan/00-installer-config.yaml",
            "sudo sync"
        ]
    }

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #2
    provisioner "file" {
        source = "files/99-pve.cfg"
        destination = "/tmp/99-pve.cfg"
    }

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #3
    provisioner "shell" {
        inline = [ "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg" ]
    }

    # Provisioning the VM Template with Docker Installation #4
    provisioner "shell" {
        inline = [
            "sudo apt-get install -y ca-certificates curl gnupg lsb-release",
            "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
            "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
            "sudo apt-get -y update",
            "sudo apt-get install -y docker-ce docker-ce-cli containerd.io",
            "sudo containerd config default | sudo tee /etc/containerd/config.toml",
            "sudo sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml",
            "sudo systemctl restart containerd.service"
        ]
    }

    provisioner "shell" {
        inline = [
            # Load necessary kernel modules
            "echo 'overlay' | sudo tee /etc/modules-load.d/k8s.conf",
            "echo 'br_netfilter' | sudo tee -a /etc/modules-load.d/k8s.conf",
            "sudo modprobe overlay",
            "sudo modprobe br_netfilter",

            # Apply sysctl parameters required for Kubernetes setup
            "echo 'net.bridge.bridge-nf-call-iptables = 1' | sudo tee /etc/sysctl.d/k8s.conf",
            "echo 'net.bridge.bridge-nf-call-ip6tables = 1' | sudo tee -a /etc/sysctl.d/k8s.conf",
            "echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/k8s.conf",

            # Apply the sysctl settings without reboot
            "sudo sysctl --system"
        ]
    }

    # Provisioning the VM Template with Kubernetes Components #4
    provisioner "shell" {
        inline = [
            "echo \"deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${var.k8s_version}/deb/ /\" | sudo tee /etc/apt/sources.list.d/kubernetes.list",
            "curl -fsSL https://pkgs.k8s.io/core:/stable:/${var.k8s_version}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg",
            "sudo apt update",
            "sudo apt install -y kubelet kubeadm kubectl",
            "sudo apt-mark hold kubelet kubeadm kubectl",
            "sudo swapoff -a",
            "sudo sed -i '/ swap / s/^\\(.*\\)$/#\\1/g' /etc/fstab"
        ]
    }
}
