aws rds describe-db-cluster-endpoints \
  --db-cluster-endpoint-identifier reporting-ro \
  --query 'DBClusterEndpoints[0].{Endpoint:Endpoint,EndpointType:EndpointType,CustomEndpointType:CustomEndpointType,StaticMembers:StaticMembers,ExcludedMembers:ExcludedMembers,Status:Status}' \
  --output json
