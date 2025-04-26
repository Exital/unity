locals {
  # Split "192.168.0.210-192.168.0.225" into ["192.168.0.210", "192.168.0.225"]
  ip_parts = split("-", var.ip_range)

  # Extract base subnet (192.168.0) and start/end numbers (210, 225)
  subnet      = join(".", slice(split(".", local.ip_parts[0]), 0, 3)) # "192.168.0"
  start_ip    = tonumber(element(split(".", local.ip_parts[0]), 3))   # 210
  end_ip      = tonumber(element(split(".", local.ip_parts[1]), 3))   # 225

  # Generate list of available IPs from start to end
  available_ips = [for i in range(local.start_ip, local.end_ip + 1) : "${local.subnet}.${i}"]

  # Assign first N IPs to masters, next N to workers
  master_ips = slice(local.available_ips, 0, var.num_masters)
  worker_ips = slice(local.available_ips, var.num_masters, var.num_masters + var.num_workers)
}
