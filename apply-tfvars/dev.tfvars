region                = "us-east-1"
env_name              = "dev"
source_repo           = "https://github.com/mattbarlow-sg/backstage-aws-walkthrough"
application_name      = "backstage"
docker_image          = "ghcr.io/mattbarlow-sg/backstage:latest"
vpc_cidr_octet        = 10
allowed_cidr          = "10.0.0.1/32"
backstage_domain_name = "mydomain.com"
