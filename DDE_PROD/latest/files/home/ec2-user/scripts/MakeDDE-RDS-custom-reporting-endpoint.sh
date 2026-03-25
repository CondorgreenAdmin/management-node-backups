#!/bin/bash
#
#This cannot be done from the AWS console, only CLI


aws rds create-db-cluster-endpoint \
  --db-cluster-identifier prd-dde \
  --db-cluster-endpoint-identifier reporting-ro \
  --endpoint-type READER \
  --static-members prd-dde-reader prd-dde-writer
