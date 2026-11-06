# Terraform Remote State — Campus Notifier

This document records the shared Terraform backend setup and explains how
teammates should initialize it. The team uses one S3 state file, protected by
DynamoDB state locking, so changes to the shared infrastructure are coordinated.

## Backend configuration

The backend is configured in [`terraform/backend.tf`](./terraform/backend.tf).
## Drill 7 evidence (local track)

Inventory: `inventory.local.ini` (ignored by Git), built from `terraform output` on the local track.

- App box: `nairobi_pulse` at 127.0.0.1:22, user `devops`, private IP 10.0.0.3
- Database box: `database_box` at 127.0.0.1:2222, user `devops`, private IP 10.0.0.2
- Key filename: `~/.ssh/alu-devops` (private key not committed)

Command: `ansible -i inventory.local.ini all -m ping`

    nairobi_pulse | SUCCESS => "changed": false, "ping": "pong"
    database_box  | SUCCESS => "changed": false, "ping": "pong"

Fact gathered: `ansible_virtualization_type: docker`. Drill 9 uses this fact so the vfs storage-driver setting applies only on the local track.
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

### Per-account backend access

The configured bucket and lock table are owned by the account that created
them. Team members using separate AWS accounts need an account-local backend
unless the bucket owner explicitly grants cross-account access. This checkout's
AWS identity cannot read the configured shared bucket (S3 returns `403`), and
the configured lock table is absent from that account. For an account-local
backend, the bootstrap also creates a versioned, encrypted, public-access
blocked S3 bucket named for the AWS account. Use an ignored local backend
override; do not replace the team's checked-in backend values with personal
account details.

```sh
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap plan
terraform -chdir=terraform/bootstrap apply
```

Then create `terraform/backend.local.hcl` with the bucket and table names from
the bootstrap outputs and a state key unique to your account. That file is
ignored by Git. Initialize the main configuration with:

```sh
terraform -chdir=terraform init -reconfigure -backend-config=backend.local.hcl
```

## One-time lock table bootstrap

The bootstrap configuration is in [`terraform/bootstrap/main.tf`](./terraform/bootstrap/main.tf).
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

If your AWS account has access to the configured shared backend, initialize the
main Terraform directory in your own checkout:

```powershell
terraform -chdir=terraform init
```

Use the AWS CLI profile or credential environment configured for your own
account access. Never put AWS access keys, secret keys, session tokens, or
private SSH keys in Terraform files or Git.

For separate AWS accounts without shared-bucket access, use the account-local
backend override above so each account has its own remote state and lock table.
Do not initialize a different backend or manually edit state after resources
have been applied. If Terraform asks to migrate an existing local state, stop
and check with the team before answering; do not overwrite or migrate state
without agreement.

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

## Drill 5: Record your work

Use this section to record what your account actually did during the drill.
Each teammate runs infrastructure against their own AWS account, so record
your own result rather than copying another teammate's IP address or evidence.

For the database box / SSH work, record:

- The Terraform output or other source used to obtain your database host's
  public address (do not record credentials or private key contents).
- The SSH username and the key *filename* used locally. Keep the private key
  outside Git.
- The connectivity command and its result, including the Ansible `ping` result
  and facts gathered by the playbook.
- Any SSH error and the fix that resolved it.

Example evidence format (replace the placeholders with your own result):

```text
Database host: <your Terraform output name and public IP>
SSH user: <user>
Key filename: <local filename; key is not committed>
Command: ansible -i inventory.ini <database-group> -m ping
Result: <paste the successful ping response>
SSH issue/fix: <brief description>
```

## SSH setup and connectivity check

The committed inventory intentionally has a host-address placeholder and no
private-key path. Replace `REPLACE_WITH_TERRAFORM_PUBLIC_IP` in your own
checkout with the public IP for your server. Do not commit personal IPs or
private key paths if your team wants to keep account-specific values private.

Load your own key into `ssh-agent` (the key stays on your machine):

```sh
chmod 400 ~/.ssh/<your-key>.pem
ssh-add ~/.ssh/<your-key>.pem
ssh -i ~/.ssh/<your-key>.pem ubuntu@<your-public-ip>
```

After direct SSH works, verify Ansible connectivity and fact gathering:

```sh
ansible campus_notifier -m ping
ansible database -m ping
ansible-playbook playbook.yml --syntax-check
ansible-playbook playbook.yml --check
```

`ansible.cfg` accepts a host key on first contact and checks it on later
connections. If the server was rebuilt and its IP now has a different host
key, remove only that stale host entry with `ssh-keygen -R <your-public-ip>`
and reconnect so SSH can learn the new key. Do not turn off host-key checking
globally.

The playbook gathers facts before making changes and checks the Debian-family
fact. Record the successful `ansible ... -m ping` output in your team's
evidence notes. Run commands against your own server only.

## Drill 4: Database box

`terraform/database.tf` defines a small Ubuntu 22.04 EC2 host in the default
VPC. SSH is restricted to one administrator IPv4 address (`/32`), the root
volume is encrypted, and instance metadata requires IMDSv2. The database port
is not open to the internet. If the app security-group ID is available, pass
it as `app_security_group_id` to allow that group to reach the configured
database port.

Set your account-specific values in your shell; do not add your address or
key path to tracked files:

```sh
export TF_VAR_ssh_public_key_path="$HOME/.ssh/<your-key>.pub"
export TF_VAR_db_admin_cidr="<your-public-ip>/32"
```

After creating the account-local backend described above, create and review a
plan before applying:

```sh
terraform -chdir=terraform init -reconfigure -backend-config=backend.local.hcl
terraform -chdir=terraform plan
terraform -chdir=terraform apply
terraform -chdir=terraform output -raw database_public_ip
```

Put the output in the ignored `inventory.local.ini` overlay in your local
checkout, then test SSH and Ansible ping. Add the actual result to the Drill 5
notes. After the session, destroy your account's resources as required by the
assignment.

### Drill 5 evidence (this account)

- Database host: `database_box` at `13.61.104.186` (Terraform instance
  `i-070cd56ea69dc04aa`).
- Bootstrap: account-local encrypted/versioned S3 state bucket and DynamoDB
  lock table created; main Terraform initialized against that backend.
- Database host apply: `3 added, 0 changed, 0 destroyed`.
- SSH: `ssh -i ~/.ssh/alu-devops ubuntu@13.61.104.186` returned `SSH_OK`.
- Ansible: `ansible -i inventory.local.ini database -m ping` returned
  `database_box | SUCCESS`, `changed: false`, `ping: pong`.
- SSH fix: registered the public key in EC2, loaded the private key locally,
  limited inbound SSH to the current client `/32`, and enabled `accept-new`
  host-key handling in Ansible.

## Database box status

The database box is provisioned in this account and its SSH and Ansible
connectivity are verified above. The checked-in shared backend still points to
a bucket this account cannot access, so this checkout uses the ignored
`terraform/backend.local.hcl` override and account-local state bucket. Keep the
local backend override and inventory out of Git; do not put credentials in
Terraform variables committed to Git.
## Drill 8 evidence (local track)

Added a second play to `playbook.yml` that configures Postgres on the `database` host:
installs Postgres, listens on the network, allows only the app server's private IP in
`pg_hba.conf`, keeps Postgres running, and creates the `campus` user and database.
The password comes from `secrets.yml`, which Git ignores.

Second run of `ansible-playbook -i inventory.local.ini playbook.yml --limit database`:

    database_box : ok=9  changed=0  unreachable=0  failed=0  skipped=0

Check: `psql -lqt` shows the `campus` database owned by `campus`.

Fix: creating the user first failed with `chmod: invalid mode: 'A+user:postgres:rx:allow'`,
because becoming the unprivileged `postgres` user needs the `acl` package. Added `acl`
to the install task.
## Drill 9 evidence (local track)

Added a task that writes `/etc/docker/daemon.json` with `"storage-driver": "vfs"`, plus a
`Restart docker` handler. It only runs when `ansible_facts['virtualization_type'] == "docker"`
(the fact found in drill 7), so it applies on the local track and is skipped on AWS VMs.
Docker is still installed with the `apt` module and started with the `service` module.

First run: Install Docker, the vfs task and the Restart docker handler reported `changed`.
Check: `docker info | grep 'Storage Driver'` returns `Storage Driver: vfs`.

Note for drill 10: the health check called `http://127.0.0.1:3000/health`, but the Campus
Notifier image listens on 8000 and serves `/health/`, so group_vars needs updating.
