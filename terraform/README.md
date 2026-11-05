# Terraform remote state

The shared Terraform state uses the existing S3 bucket `ibragold-terraform-lab-2026`
in `eu-north-1`. The state object key is `campus-notifier/terraform.tfstate`.
State locking uses the DynamoDB table `campus-notifier-terraform-locks`.

## One-time lock table setup

The S3 backend cannot create its DynamoDB lock table. Bootstrap it first from this
directory, using your own AWS CLI profile or the standard AWS credential
environment. Do not put credentials in Terraform files or Git.

```powershell
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap plan
terraform -chdir=terraform/bootstrap apply
```

Review the plan before applying. This configuration creates only the DynamoDB
table used for state locking; it does not create or modify the S3 bucket.
Bootstrap state is local by design, so do not delete the `terraform/bootstrap`
directory's local state until the lock table is no longer needed.

## Initialize the shared backend

After the lock table exists, initialize the team's main Terraform directory:

```powershell
terraform -chdir=terraform init
```

If a local state file already exists in that directory, Terraform will ask
whether to copy it to S3. Confirm migration only after checking that the bucket
and key are the intended team state location. If there is no local state yet,
initialization should configure the backend without migrating state.

Each teammate must initialize Terraform in their own checkout. Never commit
Terraform state files, AWS credentials, or private keys.
