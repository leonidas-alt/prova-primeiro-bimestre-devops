# infra/outputs.tf

output "vpc_id" {
  description = "ID da VPC provisionada"
  value       = module.vpc.vpc_id
}

output "ec2_public_ip" {
  description = "IP público da instância EC2"
  value       = module.ec2.public_ip
}

output "rds_endpoint" {
  description = "Endpoint do RDS PostgreSQL (host:port)"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "api_url" {
  description = "URL pública da API de Reservas"
  value       = "http://${module.ec2.public_ip}:3000"
}

output "sg_ec2_id" {
  description = "ID do Security Group da EC2"
  value       = module.sg_ec2.sg_id
}

output "sg_rds_id" {
  description = "ID do Security Group do RDS"
  value       = module.sg_rds.sg_id
}
