# modules/vm/outputs.tf
output "public_ip"  { value = aws_eip.vm.public_ip }
output "public_dns" { value = aws_instance.main.public_dns }
output "instance_id" { value = aws_instance.main.id }
