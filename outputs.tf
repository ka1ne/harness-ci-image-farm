output "pipeline" {
  value       = harness_platform_pipeline.harness_ci_image_factory.id
  description = "The ID of the Harness CI Image Factory pipeline"
}

output "reset_pipeline" {
  value       = harness_platform_pipeline.harness_ci_image_factory_cleanup.id
  description = "The ID of the Harness CI Image Factory Reset pipeline"
}
