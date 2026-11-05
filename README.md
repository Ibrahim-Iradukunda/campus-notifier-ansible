# Terraform Remote State — Campus Notifier

This document records the shared Terraform backend setup and explains how
teammates should initialize it. The team uses one S3 state file, protected by
DynamoDB state locking, so changes to the shared infrastructure are coordinated.

## Backend configuration

The backend is configured in [`backend.tf`](./backend.tf).

| Setting | Value |
|---|---|
| Backend | Amazon S3 |
| Existing S3 bucket | `ibragold-terraform-lab-2026` |
| AWS region | `eu-north-1` (Europe/Stockholm) |
| State object key | `campus-notifier/terraform.tfstate` |
| S3 backend encryption | Enabled |
| Locking mechanism | DynamoDB |
| DynamoDB lock table | `campus-notifier-terraform-locks` |

The S3 bucket already existed and was reused. The DynamoDB table was created
separately because the S3 backend requires the lock table to exist before
initialization.

## One-time lock table bootstrap

The bootstrap configuration is in [`bootstrap/main.tf`](./bootstrap/main.tf).
It creates the DynamoDB lock table in `eu-north-1` with:

- Partition key: `LockID` (String)
- Billing mode: `PAY_PER_REQUEST`
- Table name: `campus-notifier-terraform-locks`

The bootstrap was run with:

```powershell
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap plan
terraform -chdir=terraform/bootstrap apply
```

The first apply was blocked because the AWS identity did not have the required
DynamoDB permissions. After the required permissions were added, the apply
succeeded:

```text
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

The bootstrap uses local Terraform state. Keep the bootstrap state files safe
and do not commit them. The lock table is a shared, one-time resource: teammates
should **not** run the bootstrap to create another table.

## Initialize the shared backend

The main backend was initialized successfully after the lock table was created:

```powershell
terraform -chdir=terraform init
```

Each teammate should use their own AWS identity and initialize the main
Terraform directory in their own checkout:

```powershell
terraform -chdir=terraform init
```

Use the AWS CLI profile or credential environment configured for your own
account access. Never put AWS access keys, secret keys, session tokens, or
private SSH keys in Terraform files or Git.

All teammates must use the same backend bucket, key, region, and lock table.
This makes Terraform operate on the shared team state rather than separate
local copies. Do not initialize a different backend or manually edit the state.
If Terraform asks to migrate an existing local state, stop and check with the
team before answering; do not overwrite or migrate state without agreement.

## State and credential hygiene

- Do not commit `*.tfstate`, `*.tfstate.*`, `.terraform/`, or credential files.
- Do not share personal AWS credentials or private keys with teammates.
- Use Terraform's plan output and review it with the team before applying
  infrastructure changes.
- Keep the bootstrap configuration and its local state separate from the
  shared infrastructure state.

## Drill 1 completion

- Configured the existing S3 bucket as the remote state location.
- Enabled backend encryption and configured DynamoDB state locking.
- Created the DynamoDB lock table through the separate bootstrap configuration.
- Successfully applied the bootstrap (`1 added, 0 changed, 0 destroyed`).
- Successfully initialized the shared S3 backend.

This README documents **Drill 1 (remote state)** only. Application networking,
security-group rules, EC2 instances, and Terraform outputs are separate tasks.
