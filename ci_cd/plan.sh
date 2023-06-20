die () {
    echo >&2 "$@"
    exit 1
}
[ "$#" -eq 1 ] || die "1 argument required, $# provided"
env="$1"

source ci_cd/init_terraform.sh $env
mkdir -p plan-artifacts
cd cloud-resources
export TF_VAR_env="$env"
terraform --version
terraform plan -out="../plan-artifacts/$env.tfplan" -var-file="$env.tfvars"
cd ..