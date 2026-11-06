# Team Notes - Drills 10-12 Completion

## Person 4: Drills 10-12 Implementation

### Drill 10: Deploy
**Completed**: Added pinned tag `v1.0.0`, environment variables (NODE_ENV, DATABASE_URL, PORT, APP_SECRET), and maintained existing restart_policy and published ports. Health check uses ansible.builtin.uri with retries as required.

### Drill 11: Idempotence
**Changes made for idempotence**:
1. Added pinned image tag `v1.0.0` to prevent Docker from pulling `latest` on each run
2. Already had `cache_valid_time: 3600` in apt task from teammates' work
3. All tasks use proper Ansible modules (no shell/command tasks)

**Idempotence explanation**: The pinned image tag ensures Docker doesn't pull new versions on subsequent runs, and cache_valid_time prevents unnecessary apt cache updates. These changes make the second playbook run show `changed=0` while keeping the app healthy.

### Drill 12: Data Check
**Implemented**: Added Docker volume `app-data:/app/data` to preserve application data across playbook reruns. The named volume persists independently of container lifecycle.

## Commands to Run

### Initial Setup
```bash
# 1. Pull latest code and create branch
git pull
git checkout -b drills-10-12

# 2. Test connectivity (requires SSH key loaded in ssh-agent)
ansible -i inventory.ini all -m ping
```

### Drill 10-12 Verification
```bash
# 1. First playbook run (should show changes)
ansible-playbook -i inventory.ini playbook.yml

# 2. Second playbook run (should show changed=0)
ansible-playbook -i inventory.ini playbook.yml

# 3. Verify health endpoint
curl http://<your-server-ip>:3000/health

# 4. Test data persistence
# Write data through app, then rerun playbook
ansible-playbook -i inventory.ini playbook.yml
# Verify data still exists
```

### Security Checks
```bash
# Verify no secrets in Git
git status
git diff --cached

# Verify no .tfstate files
find . -name "*.tfstate*" -type f
find . -name ".terraform" -type d
```

### Cleanup
```bash
# Destroy Terraform resources
terraform -chdir=terraform destroy

# Verify all resources destroyed
terraform -chdir=terraform show
```

## Evidence Checklist
- [ ] PR created and reviewed for drills 10-12 changes
- [ ] Second playbook run shows `changed=0`
- [ ] Health endpoint returns 200 after both runs
- [ ] Data persists through playbook rerun
- [ ] No secrets committed to Git
- [ ] No .tfstate files committed
- [ ] team-notes.md updated with evidence
- [ ] Terraform destroy completed on personal servers

## Notes
- Secrets should be managed via ansible-vault or environment variables
- Database URL and app secret should not be hardcoded
- Use `ansible-vault create group_vars/vault.yml` for sensitive data
- Set environment variables: `export DATABASE_URL=...` and `export APP_SECRET=...`