die () {
    echo >&2 "$@"
    exit 1
}
[ "$#" -eq 1 ] || die "1 argument required, $# provided"
source ci_cd/init_terraform.sh $1
mkdir -p plan-artifacts
cd cloud-resources
export TF_VAR_env="$1"
terraform --version
terraform plan -out="../plan-artifacts/$1.tfplan"
cd ..