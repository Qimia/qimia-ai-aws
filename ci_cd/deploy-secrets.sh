set -e
set -o allexport
source ".manual-secrets-config"
set +o allexport

Echo "Using key vault $KEY_VAULT_NAME"
[ ! -z "$EMAIL_PASSWORD" ] &&  az keyvault secret set --name email-password --vault-name "$KEY_VAULT_NAME" --value "$EMAIL_PASSWORD" --content-type "The email address password to the address defined in the secret 'email-address'." || echo "EMAIL_PASSWORD not set, skipping"
[ ! -z "$EMAIL_ADDRESS" ] &&  az keyvault secret set --name email-address --vault-name "$KEY_VAULT_NAME" --value "$EMAIL_ADDRESS" --content-type "The email address to communicate to the  users regarding activation and email resets etc."  || echo "EMAIL_ADDRESS not set, skipping"
[ ! -z "$SMTP_SEND_ADDRESS" ] &&  az keyvault secret set --name email-smtp --vault-name "$KEY_VAULT_NAME" --value "$SMTP_SEND_ADDRESS" --content-type "The smtp email send address for the email address defined in the secret 'email-address'."  || echo "SMTP_SEND_ADDRESS not set, skipping"
