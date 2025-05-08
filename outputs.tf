output "pipeline" {
  value = module.harness-ci-image-factory.details
}

output "cleanup_pipeline" {
  value = module.harness-ci-image-factory-cleanup.details
}

output "organization_id" {
  description = "The Harness organization ID."
  value       = module.organization.details.id
}

output "project_id" {
  description = "The Harness project ID."
  value       = module.project.details.id
}

# CI Image Factory template outputs
output "gather_ci_images_template_id" {
  description = "The template ID for gathering CI images."
  value       = module.gather-harness-ci-images-template.details.id
}

output "build_push_template_id" {
  description = "The template ID for building and pushing CI images."
  value       = module.build-push-template.details.id
}

# ECR Ingestion template outputs
output "ecr_trigger_template_id" {
  description = "The unique ID of the ECR Trigger template."
  value       = harness_platform_template.ecr_trigger_template.id
}

output "ecr_trigger_template_version" {
  description = "The version of the ECR Trigger template."
  value       = harness_platform_template.ecr_trigger_template.version
}

output "ecr_ingestion_pipeline_template_id" {
  description = "The unique ID of the ECR Ingestion Pipeline template."
  value       = harness_platform_template.ecr_ingestion_pipeline_template.id
}

output "ecr_ingestion_pipeline_template_version" {
  description = "The version of the ECR Ingestion Pipeline template."
  value       = harness_platform_template.ecr_ingestion_pipeline_template.version
}

output "image_scan_step_template_id" {
  description = "The unique ID of the Image Scan Step template."
  value       = harness_platform_template.image_scan_step_template.id
}

output "image_scan_step_template_version" {
  description = "The version of the Image Scan Step template."
  value       = harness_platform_template.image_scan_step_template.version
}

output "image_factory_trigger_template_id" {
  description = "The unique ID of the Image Factory Trigger template."
  value       = harness_platform_template.image_factory_trigger_template.id
}

output "image_factory_trigger_template_version" {
  description = "The version of the Image Factory Trigger template."
  value       = harness_platform_template.image_factory_trigger_template.version
} 