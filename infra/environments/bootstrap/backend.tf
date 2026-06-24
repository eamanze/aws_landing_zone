terraform {
  # Bootstrap is the only environment initially allowed to use local state.
  # Replace this block with backend.s3.tf.example only after the protected
  # bucket exists and the migration procedure in MIGRATION.md is approved.
  backend "local" {
    path = "terraform.tfstate"
  }
}
