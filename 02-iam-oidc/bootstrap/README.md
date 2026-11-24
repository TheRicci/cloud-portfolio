# Bootstrap state backends

Bootstrap is the sole stage that begins with local Terraform state. Apply each root only from the owner's MFA-protected administrative session, then migrate the resulting state to the backend it created. Confirm that no `terraform.tfstate` or backup remains after a successful migration.

This folder creates durable, low-cost state storage; it does not create application infrastructure.

## AWS

The AWS root creates a versioned S3 bucket with public access blocked, server-side encryption, ownership controls, and a policy that rejects non-TLS requests. The eventual S3 backend uses `use_lockfile=true`; the plan/apply roles need access only to their state object and its `.tflock` companion.

## Azure

The Azure root creates a private StorageV2 account and private `tfstate` blob container. State access uses Microsoft Entra data-plane authorization, not account keys. The bootstrap root gives the current MFA-authenticated operator `Storage Blob Data Contributor` on that storage account because Azure Owner alone does not grant blob data-plane access. The future CI identities receive the same role at the narrower container scope.
