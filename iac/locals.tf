locals {
  region = "us-east-1"
  domain_name = {
    default = "brignano.io"
    backup  = "anthonybrignano.com"
  }
  email_address = "anthonybrignano@gmail.com"
  log_level = "INFO"
  
  # todo: remove
  vercel_ip_address = "76.76.21.21"
}
