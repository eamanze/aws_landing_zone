terraform {
  backend "s3" {
    # Supply backend configuration with -backend-config=backend.security.hcl.
    # Do not commit real bucket names, keys, account IDs, or role ARNs.
  }
}
