---
name: terraform-with-fnox
description: Run Terraform commands in this repository with Proxmox and Cloudflare R2 credentials injected by fnox from 1Password. Use whenever Codex executes Terraform commands under `terraform/` that access the backend or provider, including `init`, `plan`, `apply`, `import`, `refresh`, `state`, and `destroy`.
---

# Terraform With Fnox

## Command Execution

- Run credentialed Terraform commands from `terraform/`.
- Prefix Terraform invocations with `fnox exec --`.
- Do not use `fnox activate` for agent command execution; it is for interactive user shells.
- Do not read, print, or export resolved Terraform credentials.

```sh
cd terraform
fnox exec -- terraform plan -no-color
fnox exec -- terraform apply
fnox exec -- terraform import '<address>' '<id>'
```

## Configuration

- Use `terraform/fnox.toml` as the credential map.
- Keep secret values in 1Password; commit only `op://` references.
- Treat `terraform plan` without `fnox exec --` as incomplete in non-interactive agent execution.
