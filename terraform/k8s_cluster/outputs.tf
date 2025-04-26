output "master_ips" {
  value = [for master in proxmox_vm_qemu.masters : master.default_ipv4_address]
}

output "worker_ips" {
  value = [for worker in proxmox_vm_qemu.workers : worker.default_ipv4_address]
}
