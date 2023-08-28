echo 'This script needs to be run with a single argument that is the environment "dev", "preprod", or "prod".'
cd cloud-resources
env="$1"
terraform init -backend-config="$env.tfbackend"
cd ..