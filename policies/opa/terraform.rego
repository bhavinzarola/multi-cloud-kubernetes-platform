package terraform.security

import future.keywords.in

# Deny S3 buckets with public ACLs or public-read policies.
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket_acl"
    acl := resource.change.after.acl
    acl in {"public-read", "public-read-write", "authenticated-read"}
    msg := sprintf(
        "S3 bucket ACL '%s' on %s is public and not allowed",
        [acl, resource.address],
    )
}

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket_public_access_block"
    after := resource.change.after
    not after.block_public_acls
    msg := sprintf(
        "%s must set block_public_acls = true",
        [resource.address],
    )
}

# Deny unencrypted EBS volumes.
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_ebs_volume"
    after := resource.change.after
    after.encrypted != true
    msg := sprintf("EBS volume %s must be encrypted", [resource.address])
}

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_launch_template"
    mapping := resource.change.after.block_device_mappings[_]
    mapping.ebs[_].encrypted != true
    msg := sprintf(
        "Launch template %s has an unencrypted EBS block device mapping",
        [resource.address],
    )
}

# Require cost-allocation tags on every taggable resource.
required_tags := {"Project", "Environment", "Owner", "ManagedBy"}

taggable_types := {
    "aws_vpc", "aws_subnet", "aws_eks_cluster", "aws_ecr_repository",
    "aws_iam_role", "aws_nat_gateway", "aws_security_group",
}

deny[msg] {
    resource := input.resource_changes[_]
    resource.type in taggable_types
    tags := object.get(resource.change.after, "tags", {})
    missing := required_tags - {k | tags[k]}
    count(missing) > 0
    msg := sprintf(
        "%s is missing required tags: %v",
        [resource.address, missing],
    )
}
