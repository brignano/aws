locals {
  region = "us-east-1"
  domain_name = {
    default = "brignano.io"
    backup  = "anthonybrignano.com"
  }
  email_address = "anthonybrignano@gmail.com"
  log_level = "INFO"
  
  vercel_ip_address = "216.198.79.1"
  vercel_cname_record = "7db213ad1eff704d.vercel-dns-017.com"
}
