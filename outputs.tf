output "alb_dns_name" {
  value = aws_lb.pb_alb.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.rds.endpoint
}