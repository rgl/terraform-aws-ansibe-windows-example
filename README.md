# About

[![Lint](https://github.com/rgl/terraform-aws-ansibe-windows-example/actions/workflows/lint.yml/badge.svg)](https://github.com/rgl/terraform-aws-ansibe-windows-example/actions/workflows/lint.yml)

Terraform, Ansible, and Windows integration AWS playground.

This will:

* Create a VPC.
  * Configure a Internet Gateway.
* Create a EC2 Instance.
  * Assign a Public IP address.
  * Assign a IAM Role.
    * Include the [AmazonSSMManagedInstanceCore Policy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonSSMManagedInstanceCore.html).
  * Initialize.
    * Configure SSH.
* Use Ansible to configure the EC2 Instance.
  * Use SSH via the AWS Systems Manager (SSM) Session Manager SSH proxy.

Also see:

* [rgl/aws-windows-vm](https://github.com/rgl/aws-windows-vm)
* [rgl/my-windows-ansible-playbooks](https://github.com/rgl/my-windows-ansible-playbooks)

## Usage (on a Ubuntu Desktop)

Install Visual Studio Code and the Dev Container plugin.

Install the dependencies:

* [Visual Studio Code](https://code.visualstudio.com).
* [Dev Container plugin](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

Open this directory with the Dev Container plugin.

Open the Visual Studio Code Terminal.

Set the AWS Account credentials using SSO, e.g.:

```bash
# set the account credentials.
# NB the aws cli stores these at ~/.aws/config.
# NB this is equivalent to manually configuring SSO using aws configure sso.
# see https://docs.aws.amazon.com/cli/latest/userguide/sso-configure-profile-token.html#sso-configure-profile-token-manual
# see https://docs.aws.amazon.com/cli/latest/userguide/sso-configure-profile-token.html#sso-configure-profile-token-auto-sso
cat >secrets.sh <<'EOF'
# set the environment variables to use a specific profile.
# NB use aws configure sso to configure these manually.
# e.g. use the pattern <aws-sso-session>-<aws-account-id>-<aws-role-name>
export aws_sso_session='example'
export aws_sso_start_url='https://example.awsapps.com/start'
export aws_sso_region='eu-west-1'
export aws_sso_account_id='123456'
export aws_sso_role_name='AdministratorAccess'
export AWS_PROFILE="$aws_sso_session-$aws_sso_account_id-$aws_sso_role_name"
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_DEFAULT_REGION
# configure the ~/.aws/config file.
# NB unfortunately, I did not find a way to create the [sso-session] section
#    inside the ~/.aws/config file using the aws cli. so, instead, manage that
#    file using python.
python3 <<'PY_EOF'
import configparser
import os
aws_sso_session = os.getenv('aws_sso_session')
aws_sso_start_url = os.getenv('aws_sso_start_url')
aws_sso_region = os.getenv('aws_sso_region')
aws_sso_account_id = os.getenv('aws_sso_account_id')
aws_sso_role_name = os.getenv('aws_sso_role_name')
aws_profile = os.getenv('AWS_PROFILE')
config = configparser.ConfigParser()
aws_config_directory_path = os.path.expanduser('~/.aws')
aws_config_path = os.path.join(aws_config_directory_path, 'config')
if os.path.exists(aws_config_path):
  config.read(aws_config_path)
config[f'sso-session {aws_sso_session}'] = {
  'sso_start_url': aws_sso_start_url,
  'sso_region': aws_sso_region,
  'sso_registration_scopes': 'sso:account:access',
}
config[f'profile {aws_profile}'] = {
  'sso_session': aws_sso_session,
  'sso_account_id': aws_sso_account_id,
  'sso_role_name': aws_sso_role_name,
  'region': aws_sso_region,
}
os.makedirs(aws_config_directory_path, mode=0o700, exist_ok=True)
with open(aws_config_path, 'w') as f:
  config.write(f)
PY_EOF
unset aws_sso_start_url
unset aws_sso_region
unset aws_sso_session
unset aws_sso_account_id
unset aws_sso_role_name
# show the user, user amazon resource name (arn), and the account id, of the
# profile set in the AWS_PROFILE environment variable.
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  aws sso login
fi
aws sts get-caller-identity
EOF
```

Or, set the AWS Account credentials using an Access Key, e.g.:

```bash
# set the account credentials.
# NB get these from your aws account iam console.
#    see Managing access keys (console) at
#        https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey
cat >secrets.sh <<'EOF'
export AWS_ACCESS_KEY_ID='TODO'
export AWS_SECRET_ACCESS_KEY='TODO'
unset AWS_PROFILE
# set the default region.
export AWS_DEFAULT_REGION='eu-west-1'
# show the user, user amazon resource name (arn), and the account id.
aws sts get-caller-identity
EOF
```

Review `main.tf`.

Load the secrets into the current shell session:

```bash
source secrets.sh
```

Initialize terraform:

```bash
make terraform-init
```

Launch the example:

```bash
rm -f terraform.log
make terraform-apply
```

Show the terraform state:

```bash
make terraform-show
```

Configure the infrastructure:

```bash
#ansible-doc -l # list all the available modules
ansible-inventory --list --yaml
ansible-lint --offline --parseable playbook.yml
ansible-playbook playbook.yml --syntax-check
ansible-playbook playbook.yml --list-hosts

# execute ad-hoc commands.
ansible -vvv -m gather_facts windows
ansible -vvv -m win_ping windows
ansible -vvv -m win_command -a 'whoami /all' windows
ansible -vvv -m win_shell -a '$FormatEnumerationLimit = -1; dir env: | Sort-Object Name | Format-Table -AutoSize | Out-String -Stream -Width ([int]::MaxValue) | ForEach-Object {$_.TrimEnd()}' windows

# execute the playbook.
# see https://docs.ansible.com/ansible-core/2.19/os_guide/windows_winrm.html#winrm-limitations
# see https://docs.ansible.com/ansible-core/2.19/os_guide/windows_usage.html
# see https://docs.ansible.com/ansible-core/2.19/os_guide/intro_windows.html#working-with-windows
time ansible-playbook playbook.yml #-vvv
time ansible-playbook playbook.yml --limit app #-vvv
```

Show the `Administrator` user password:

```bash
while true; do
  administrator_password="$(aws ec2 get-password-data \
    --instance-id "$(terraform output --raw app_instance_id)" \
    --priv-launch-key ~/.ssh/id_rsa \
    | jq -r .PasswordData)"
  if [ -n "$administrator_password" ]; then
    echo "Administrator password: $administrator_password"
    break
  fi
  sleep 5
done
```

Start the RDP port-forwarding session:

```bash
# NB visual studio code should automatically make this port available on your
#    host (outside the dev container).
aws ssm start-session \
  --target "$(terraform output --raw app_instance_id)" \
  --document-name AWS-StartPortForwardingSession \
  --parameters "localPortNumber=53389,portNumber=3389"
```

Connect to the instance RDP server as the `Administrator` user:

**NB** This does not run from the dev container, so you should echo it here,
and then execute the resulting command on your host.

```bash
# use remmina.
remmina "rdp://Administrator@localhost:53389"
# or use xfreerdp.
xfreerdp \
  /v:localhost:53389 \
  /u:Administrator \
  "/p:$administrator_password" \
  /size:1440x900 \
  /dynamic-resolution \
  +clipboard
```

Get the instance ssh host public keys, convert them to the knowns hosts format,
and show their fingerprints:

```bash
./aws-ssm-get-sshd-public-keys.sh \
  "$(terraform output --raw app_instance_id)" \
  | tail -2 \
  | jq -r .sshd_public_keys \
  | sed "s/^/$(terraform output --raw app_instance_id),$(terraform output --raw app_ip_address) /" \
  > app-ssh-known-hosts.txt
ssh-keygen -l -f app-ssh-known-hosts.txt
```

Using your ssh client, and [aws ssm session manager to proxy the ssh connection](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-enable-ssh-connections.html), open a shell inside the VM and execute some commands:

```bash
ssh \
  -o UserKnownHostsFile=app-ssh-known-hosts.txt \
  -o ProxyCommand='aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p' \
  "Administrator@$(terraform output --raw app_instance_id)"
powershell
$PSVersionTable
whoami /all
&"C:\Program Files\Amazon\SSM\ssm-cli.exe" get-instance-information
&"C:\Program Files\Amazon\SSM\ssm-cli.exe" get-diagnostics
exit # exit the powershell.exe shell.
exit # exit the cmd.exe shell.
```

Using [aws ssm session manager](https://docs.aws.amazon.com/cli/latest/reference/ssm/start-session.html), open a `powershell` shell inside the VM and execute some commands:

```bash
# NB this executes the command inside a windows powershell shell. to switch to a
#    different one, see the next example.
# NB the default ssm session --document-name is SSM-SessionManagerRunShell.
#    NB that document is created in our account when session manager is used
#       for the first time.
# see https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-default-session-document.html
# see aws ssm describe-document --name SSM-SessionManagerRunShell
aws ssm start-session --target "$(terraform output --raw app_instance_id)"
$PSVersionTable
whoami /all
&"C:\Program Files\Amazon\SSM\ssm-cli.exe" get-instance-information
&"C:\Program Files\Amazon\SSM\ssm-cli.exe" get-diagnostics
exit # exit the powershell.exe shell.
```

Using [aws ssm session manager](https://docs.aws.amazon.com/cli/latest/reference/ssm/start-session.html), open a `cmd` shell inside the VM and execute some commands:

```bash
# NB this executes the command inside a powershell shell, but we immediately
#    start the cmd shell.
# NB the default ssm session --document-name is SSM-SessionManagerRunShell which
#    is created in our account when session manager is used the first time.
# see aws ssm describe-document --name AWS-StartInteractiveCommand --query 'Document.Parameters[*]'
# see aws ssm describe-document --name AWS-StartNonInteractiveCommand --query 'Document.Parameters[*]'
aws ssm start-session \
  --document-name AWS-StartInteractiveCommand \
  --parameters '{"command":["cmd.exe"]}' \
  --target "$(terraform output --raw app_instance_id)"
ver
whoami /all
"C:\Program Files\Amazon\SSM\ssm-cli.exe" get-instance-information
"C:\Program Files\Amazon\SSM\ssm-cli.exe" get-diagnostics
exit
```

Destroy the example:

```bash
make terraform-destroy
```

## References

* [Environment variables to configure the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html)
* [Token provider configuration with automatic authentication refresh for AWS IAM Identity Center](https://docs.aws.amazon.com/cli/latest/userguide/sso-configure-profile-token.html) (SSO)
* [Managing access keys (console)](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey)
* [AWS General Reference](https://docs.aws.amazon.com/general/latest/gr/Welcome.html)
  * [Amazon Resource Names (ARNs)](https://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html)
* [Connect to the internet using an internet gateway](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html#vpc-igw-internet-access)
* [Configure your Amazon EC2 Windows instance](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-windows-instances.html)
* [How Amazon EC2 handles user data for Windows instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html#ec2-windows-user-data)
* [AWS Systems Manager (aka Amazon EC2 Simple Systems Manager (SSM))](https://docs.aws.amazon.com/systems-manager/latest/userguide/what-is-systems-manager.html)
  * [Amazon SSM Agent Source Code Repository](https://github.com/aws/amazon-ssm-agent)
  * [Amazon SSM Session Manager Plugin Source Code Repository](https://github.com/aws/session-manager-plugin)
  * [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
    * [Start a session](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html)
      * [Starting a session (AWS CLI)](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html#sessions-start-cli)
      * [Starting a session (SSH)](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html#sessions-start-ssh)
        * [Allow and control permissions for SSH connections through Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-enable-ssh-connections.html)
      * [Starting a session (port forwarding)](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html#sessions-start-port-forwarding)
