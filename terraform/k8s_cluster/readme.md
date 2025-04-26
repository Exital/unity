# Terraform Deployment Guide

Terraform `v1.5.7`

## 1. Configure Variables

Before running Terraform, review and update the variable values in your Terraform files:

Edit any *.tf files as needed.

## 2. Initialize Terraform

Initialize the Terraform working directory. This will download any necessary provider plugins.
```bash
terraform init
```
## 3. Review the Execution Plan

Generate and review the Terraform plan to see what changes will be made.
```bash
terraform plan
```
## 4. Apply the Changes

Apply the planned changes to provision or update infrastructure.
```bash
terraform apply
```

> Confirm when prompted (or use -auto-approve if you want to skip the prompt):
```bash
terraform apply -auto-approve
```

## 5. Destroy the Infrastructure (Optional)

If you need to tear down all resources created by this Terraform project:
```bash
terraform destroy
```
> Confirm when prompted (or use -auto-approve):
```bash
terraform destroy -auto-approve
```
