PVTOKEN_VC=$(cat ~/keys/gitlab_vc_nonprod.dat)
GROUP_VC="102347416"



curl --request PUT \
	--header "PRIVATE-TOKEN: $PVTOKEN_VC" \
	--header "Content-Type: application/json" \
	--data '{
	"value": "BBBBBBBBBBBBBBB",
	"protected": true,
	"masked": true,
	"environment_scope": "uat"}' \
	"https://gitlab.com/api/v4/groups/102347416/variables/test"
