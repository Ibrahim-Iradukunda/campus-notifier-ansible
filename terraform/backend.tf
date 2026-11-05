terraform {
  backend "s3" {
    bucket         = "ibragold-terraform-lab-2026"
    key            = "campus-notifier/terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "campus-notifier-terraform-locks"
  }
}
