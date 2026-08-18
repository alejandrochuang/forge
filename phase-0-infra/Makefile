.PHONY: init plan apply destroy scan creds fmt

init:
	terraform init

fmt:
	terraform fmt -recursive

scan:
	checkov --config-file .checkov.yaml --directory .

plan:
	terraform plan -out tfplan

apply:
	terraform apply tfplan

creds:
	az aks get-credentials \
		--resource-group $$(terraform output -raw resource_group) \
		--name $$(terraform output -raw aks_cluster_name) \
		--overwrite-existing

destroy:
	terraform destroy -auto-approve
