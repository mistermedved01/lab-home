output "talos_config" {
  description = "Talos client configuration"
  value       = data.talos_client_configuration.talos_client_config.talos_config
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubeconfig for the cluster"
  value       = talos_cluster_kubeconfig.talos_kubeconfig.kubeconfig_raw
  sensitive   = true
}
