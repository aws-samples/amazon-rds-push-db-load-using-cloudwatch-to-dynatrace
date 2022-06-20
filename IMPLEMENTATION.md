# Steps to implement this feature in your environment
- Open a command line and navigate to this project working directory
- [Configure your AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)
- [Initialize your working directory with Terraform](https://www.terraform.io/cli/commands/init)
- Update the variable values in the terraform.tfvars as needed (See README file for details on the input variables)
- Run the plan sub-command in Terraform to preview and validate the infrastructure changes
- Run the apply sub-command in Terraform to provision the infrastructure and the application code to AWS cloud
- Use a tool like pgBench to generate load on your Amazon RDS Postgres database and confirm the Performance Insights show up in your applicaiton monitoring tool 