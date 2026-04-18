output "public_ip" {
  description = "Public IP address of the web server"
  value       = aws_instance.web.public_ip
}

output "public_dns" {
  description = "Public DNS of the web server"
  value       = aws_instance.web.public_dns
}

output "ssh_command" {
  description = "Command to SSH into the server"
  value       = "ssh -i ~/.ssh/my-web-app-key ubuntu@${aws_instance.web.public_ip}"
}
