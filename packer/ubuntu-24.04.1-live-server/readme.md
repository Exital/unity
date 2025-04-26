# Packer Build Instructions

This project builds an Ubuntu Server Noble image using Packer v1.11.2.

## Prerequisites

* Packer `v1.11.2`
* Proxmox credentials
* Network access (if needed)
  
## Setup

Fill in all missing fields in all of the files.

## Validate the configuration:
```bash
packer validate .
```

## Initialize
Initialize packer:
```bash
packer init .
```
## Build the image:
```bash
packer build ubuntu-server-noble.pkr.hcl
```
(Optionally add -var-file=variables.pkrvars.hcl if needed.)

## Notes

* Keep credentials secure (e.g., use .auto.pkrvars.hcl files not tracked by git).
* Use PACKER_LOG=1 for detailed logs during troubleshooting.
