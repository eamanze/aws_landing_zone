# Bootstrap State Migration

Bootstrap is the only environment initially permitted to use local state. The local state contains bucket policies, KMS policy data, account ID, and resource identifiers; treat it as confidential and migrate it immediately after the approved bootstrap apply.

## Preconditions

- The reviewed bootstrap plan was applied successfully under Gate E approval.
- `terraform output backend_configuration` returns the expected bucket, Region, KMS key ARN, encryption setting, and `use_lockfile = true`.
- The migration operator is an authorized bucket/KMS/state principal.
- S3 versioning, encryption, public-access blocking, bucket policy, and KMS rotation were validated independently.
- A protected backup of the local state exists outside Git and has a named recovery owner.

## Migration procedure

From `infra/environments/bootstrap`:

1. Copy `backend.s3.hcl.example` to ignored file `backend.s3.hcl` and replace typed placeholders with Terraform outputs.
2. Preserve a protected backup outside the repository:

   ```bash
   cp terraform.tfstate <SECURE_PATH:bootstrap_state_backup>
   ```

3. Replace `backend.tf` with the reviewed content of `backend.s3.tf.example`.
4. Reformat and review the code change.
5. Initialize migration:

   ```bash
   terraform init -migrate-state -backend-config=backend.s3.hcl
   ```

6. Confirm migration when Terraform prompts. Do not use `-force-copy` unless a recovery review explicitly requires it.
7. Verify the remote state and lock behavior:

   ```bash
   terraform state list
   terraform plan -detailed-exitcode
   ```

8. Confirm the S3 object exists at `bootstrap/terraform.tfstate`, is KMS encrypted, and has versioning.
9. Remove local state only after remote verification and secure-backup confirmation. `.gitignore` prevents accidental commit but is not a security boundary.
10. Commit the S3 backend declaration and `.terraform.lock.hcl`; never commit `backend.s3.hcl`, state, plans, or the secure backup.

## Rollback

If migration fails, stop all Terraform writers. Preserve local and any remote state versions, capture the full error and lock information, and determine which state has the newest correct lineage/serial before retrying. Do not delete a `.tflock` object or use force-unlock until confirming no active writer owns it.
