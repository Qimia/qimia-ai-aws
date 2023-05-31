## Terraform init
````
terraform init -backend-config=dev.tfbackend -reconfigure -upgrade
````

## Terraform plan
````
 terraform plan -var-file=dev.tfvars
````
## Terraform apply
````
terraform apply -var-file=dev.tfvars
````
