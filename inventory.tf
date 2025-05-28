resource "ansible_host" "app" {
  name = "app"
  groups = [
    ansible_group.windows.name,
  ]
  variables = {
    ansible_host = aws_instance.app.id
  }
}

resource "ansible_group" "windows" {
  name = "windows"
  variables = {
    # connection configuration.
    # see https://docs.ansible.com/ansible-core/2.18/collections/ansible/builtin/ssh_connection.html
    # see https://docs.ansible.com/ansible/latest/os_guide/windows_ssh.html
    ansible_connection      = "ssh"
    ansible_ssh_common_args = "-o ProxyCommand='aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p' -o StrictHostKeyChecking=no"
    ansible_shell_type      = "cmd"
    ansible_user            = "Administrator"
  }
}
