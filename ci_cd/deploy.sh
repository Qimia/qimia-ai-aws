die () {
    echo >&2 "$@"
    exit 1
}
[ "$#" -eq 1 ] || die "1 argument required, $# provided"
source ci_cd/init_terraform.sh $1
cd cloud-resources
export env=$1
terraform apply -input=false ../plan-artifacts/$env.tfplan
cd ..