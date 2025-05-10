---
pipeline:
  name: ${pipeline_name}
  identifier: ${pipeline_identifier}
  projectIdentifier: ${project_identifier}
  orgIdentifier: ${organization_identifier}
  description: ${description}
  tags: ${jsonencode(merge(try(yamldecode(yaml_data).pipeline.tags, {}), common_tags))}
  ${indent(2, yamlencode(omit(yamldecode(yaml_data).pipeline, ["tags"])))} 