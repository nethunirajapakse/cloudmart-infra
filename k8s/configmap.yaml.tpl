apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudmart-config
data:
  AWS_REGION: "us-east-1"
  STORE_BACKEND: "dynamodb"
  DYNAMODB_TABLE: "cloudmart-products"
  DB_BACKEND: "postgres"
  DB_HOST: "${db_host}"
  DB_PORT: "5432"
  DB_NAME: "cloudmart"
  DB_USER: "cloudmart"
  QUEUE_BACKEND: "sqs"
  SQS_QUEUE_URL: "${sqs_queue_url}"
  EMAIL_BACKEND: "ses"
  SES_FROM_EMAIL: "you@example.com"
  NOTIFICATION_EMAIL_OVERRIDE: ""
  POLL_INTERVAL_MS: "10000"
  PRODUCT_SERVICE_URL: "http://product-service:8001"
  ORDER_SERVICE_URL: "http://order-service:8002"
  USER_SERVICE_URL: "http://user-service:8003"
