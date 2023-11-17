# aws_terraform

## Authentication of the CI Pipeline to deploy AWS services
We create a role that the Gitlab CI pipeline assumes the role {ENV}-qimia-ai-infra with OIDC.
The trust relationship of the role looks as below:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::906856305748:oidc-provider/gitlab.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "gitlab.com:aud": "https://gitlab.com"
                },
                "StringLike": {
                    "gitlab.com:sub": "project_path:qimiaio/qimia-ai-dev/infra*"
                }
            }
        }
    ]
}
```
An identity provider called gitlab.com is required.

# Folders
## ci_cd
This directory includes the bash scripts to automate deployment.
## cloud-resources
The Terraform templates to create the AWS resources are put here.


# CI/CD pipeline
The pipeline consists of three steps.
## version
This stage gives a version ID to the deployment. 
If the pipeline isn't merged to main yet, you'll get the commit ID as the version.
Otherwise, semantic versioning will be used to set the current version.
## plan
The `plan` stages are environment specific. 
Using Terraform templates under cloud-resources directory, the changes will be detected and exported to an output file.
No changes will be applied to the AWS stack at this stage.
## deploy
The `deploy` stages are also environment specific but are triggered manually unlike the plan stages. 

## Setting up the pipeline
Several variables need to be set in the repo's CI pipelin variable as follows:
* `AWS_ACCOUNT`: The AWS account ID
* `AWS_ROLE_ARN`: The AWS Role ARN that Terraform will assume.
* `TERRAFORM_VARIABLES`: Needs to be defined as a file. Several variables are defined under this file in the `.tfvars` file format. Example is as follows:
  ```hcl
    model_machine_type  = "g4dn.xlarge"
    model_object_key    = "ggml-vicuna-13b-v1.5/ggml-model-q4_1.gguf"
    model_num_threads   = 2
    use_gpu             = true
    account             = 906856305748
    app_dns             = "qimiaai.com"
    backend_dns         = "api.qimiaai.com"
    frontend_dns        = "chat.qimiaai.com"
  ```

  * In your CI implementation, during the plan and deploy stages, the file that contains these variables must be copied to the [cloud-resources/terraform.tfvars](cloud-resources/terraform.tfvars). 
  * Alternatively, these can be defined as CI variables with the name prefix `TF_VAR`. For example, the terraform variable `model_machine_type` can be defined as `TF_VAR_model_machine_type` instead. 