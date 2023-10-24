set -e
set -o allexport
source ".manual-secrets-config"
set +o allexport

put_secret () {
  FIELD_NAME=$1
  FIELD_VALUE=$2
  [ ! -z "$FIELD_VALUE" ] && echo "Putting $FIELD_NAME" || return
  secret_full_arn=$(aws secretsmanager describe-secret --secret-id "arn:aws:secretsmanager:$REGION:$AWS_ACCOUNT_ID:secret:/qimia-ai/$ENV/$FIELD_NAME" --query 'ARN' --output text)
  echo "Putting the value '$FIELD_VALUE' to secret $secret_full_arn"
  res=$(aws secretsmanager put-secret-value --secret-id "$secret_full_arn" --secret-string "$FIELD_VALUE")
  echo $res
}

put_secret "email_password" "$EMAIL_PASSWORD"
put_secret "email_address" "$EMAIL_ADDRESS"
put_secret "email_smtp_send_address" "$SMTP_SEND_ADDRESS"
put_secret "admin_email_address" "$ADMIN_EMAIL"
put_secret "admin_email_password" "$ADMIN_PASSWORD"
