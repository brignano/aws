locals {
  # Retained only because provider.tf references it. Every resource that used
  # the other locals (domain names, forwarding address, Vercel targets) was
  # destroyed in the 2026-08-23 decommission.
  region = "us-east-1"
}
