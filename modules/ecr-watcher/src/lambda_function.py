import json
import os
import boto3
import requests
import logging
from datetime import datetime
import re

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Get environment variables
HARNESS_ACCOUNT_ID = os.environ.get('HARNESS_ACCOUNT_ID')
HARNESS_API_KEY = os.environ.get('HARNESS_API_KEY')
HARNESS_ORG_ID = os.environ.get('HARNESS_ORG_ID')
HARNESS_PROJECT_ID = os.environ.get('HARNESS_PROJECT_ID')
HARNESS_PIPELINE_ID = os.environ.get('HARNESS_PIPELINE_ID')
CONTAINER_REGISTRY = os.environ.get('CONTAINER_REGISTRY')
TARGET_IMAGES = os.environ.get('TARGET_IMAGES', 'harness/ci-addon,harness/ci-lite-engine').split(',')
DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE_NAME', 'harness-ci-image-versions')

# Initialize boto3 clients
dynamodb = boto3.resource('dynamodb')
ecr = boto3.client('ecr-public', region_name='us-east-1')
table = dynamodb.Table(DYNAMODB_TABLE)

def get_harness_default_images():
    """
    Get the default Harness CI images using the execution-config API
    """
    url = f"https://app.harness.io/gateway/ci/execution-config/get-default-config?accountIdentifier={HARNESS_ACCOUNT_ID}&infra=K8"
    headers = {"X-API-KEY": HARNESS_API_KEY}
    
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        data = response.json()
        return data.get('data', {})
    except Exception as e:
        logger.error(f"Error getting Harness default images: {str(e)}")
        return {}

def check_ecr_for_image(image_name):
    """
    Check ECR public for the specified image and get the latest version
    """
    # Extract repository name from image (e.g., harness/ci-addon -> ci-addon)
    repo_name = image_name.split('/')[-1]
    
    try:
        # Get image details from ECR public
        response = ecr.describe_image_tags(
            registryId='harness',
            repositoryName=repo_name,
            maxResults=100
        )
        
        # Extract version tags and sort by semver
        tags = [tag['imageTag'] for tag in response.get('imageTagDetails', []) if re.match(r'^\d+\.\d+\.\d+$', tag['imageTag'])]
        
        if not tags:
            return None
            
        # Sort tags by semver version (assuming x.y.z format)
        tags.sort(key=lambda v: [int(x) for x in v.split('.')])
        latest_tag = tags[-1]
        
        return latest_tag
    except Exception as e:
        logger.error(f"Error checking ECR for image {image_name}: {str(e)}")
        return None

def get_last_processed_version(image_name):
    """
    Get the last processed version of the image from DynamoDB
    """
    try:
        response = table.get_item(Key={'image_name': image_name})
        if 'Item' in response:
            return response['Item'].get('version')
        return None
    except Exception as e:
        logger.error(f"Error getting last processed version for {image_name}: {str(e)}")
        return None

def update_processed_version(image_name, version):
    """
    Update the processed version in DynamoDB
    """
    try:
        table.put_item(
            Item={
                'image_name': image_name,
                'version': version,
                'processed_at': datetime.now().isoformat()
            }
        )
        return True
    except Exception as e:
        logger.error(f"Error updating processed version for {image_name}: {str(e)}")
        return False

def trigger_harness_pipeline(new_images):
    """
    Trigger the Harness pipeline with the new image information
    """
    url = f"https://app.harness.io/pipeline/api/pipeline/execute/{HARNESS_PIPELINE_ID}?accountIdentifier={HARNESS_ACCOUNT_ID}&orgIdentifier={HARNESS_ORG_ID}&projectIdentifier={HARNESS_PROJECT_ID}"
    headers = {
        "X-API-KEY": HARNESS_API_KEY,
        "Content-Type": "application/yaml"
    }
    
    # Format the new images information for the pipeline
    images_info = []
    for image, version in new_images.items():
        image_name = image.split('/')[-1]
        images_info.append(f"{image}:{version}")
    
    payload = f"""
    pipeline:
      identifier: {HARNESS_PIPELINE_ID}
      variables:
        - name: registry
          value: {CONTAINER_REGISTRY}
        - name: is_retry
          value: "false"
        - name: modify_default
          value: "true"
        - name: new_images
          value: {','.join(images_info)}
    """
    
    try:
        response = requests.post(url, headers=headers, data=payload)
        response.raise_for_status()
        data = response.json()
        
        execution_id = data.get('data', {}).get('executionUrl', '').split('/')[-1]
        logger.info(f"Successfully triggered pipeline with execution ID: {execution_id}")
        return True
    except Exception as e:
        logger.error(f"Error triggering Harness pipeline: {str(e)}")
        return False

def lambda_handler(event, context):
    """
    Main Lambda handler function
    """
    try:
        # Get the Harness default images from API
        harness_default_images = get_harness_default_images()
        
        new_images = {}
        
        # Check each target image for new versions
        for image_name in TARGET_IMAGES:
            # Get field key name from the Harness API response
            field_key = None
            for key, value in harness_default_images.items():
                if image_name in value:
                    field_key = key
                    break
            
            if not field_key:
                logger.warning(f"Could not find field key for image {image_name}")
                continue
                
            # Get current version from the Harness API
            current_version = None
            if field_key in harness_default_images:
                current_image = harness_default_images[field_key]
                if ":" in current_image:
                    current_version = current_image.split(':')[-1]
            
            # Get the latest version from ECR
            latest_version = check_ecr_for_image(image_name)
            
            # Get the last processed version
            last_processed = get_last_processed_version(image_name)
            
            logger.info(f"Image: {image_name}, Current: {current_version}, Latest: {latest_version}, Last Processed: {last_processed}")
            
            # Check if there's a new version
            if latest_version and latest_version != last_processed:
                new_images[image_name] = latest_version
                update_processed_version(image_name, latest_version)
        
        # If there are new images, trigger the pipeline
        if new_images:
            logger.info(f"New images found: {json.dumps(new_images)}")
            trigger_result = trigger_harness_pipeline(new_images)
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Pipeline triggered successfully' if trigger_result else 'Failed to trigger pipeline',
                    'new_images': new_images
                })
            }
        else:
            logger.info("No new images found")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'No new images found'
                })
            }
    
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f'Error: {str(e)}'
            })
        } 