region                = "us-east-1"
env_name              = "dev"
source_repo           = "https://github.com/StratusGrid/backstage-aws-walkthrough"
application_name      = "backstage"
docker_image          = "public.ecr.aws/r1z1c0k6/backstage:latest"
vpc_cidr_octet        = 10
allowed_cidr          = "10.0.0.1/32"
backstage_domain_name = "mydomain.com"
