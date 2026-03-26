kubectl create secret generic order-management-mysql-secret\
 --from-literal=DATABASE=uat_order_management\
 --from-literal=HOST=nonprod-bm-rds1-cluster.cluster-c1esioioqpsf.af-south-1.rds.amazonaws.com\
 --from-literal=PASSWORD=P@ssw0rd01\
 --from-literal=USER=bm_app_user\
 -n uat-beyond-mobile

