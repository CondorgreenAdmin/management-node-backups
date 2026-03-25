kubectl logs dde-depl-75748cc754-stpds | egrep -v "Login|Logout|userRoles" | egrep "Roles|Email" | awk '{a=$0;getline;if (( $1 == "Roles:" )){print a,$0} else {print $0}}'
