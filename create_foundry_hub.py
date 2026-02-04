#!/usr/bin/env python3
"""
Script to create Azure AI Foundry Hub and Project using Azure Python SDK
"""
import os
from azure.ai.ml import MLClient
from azure.ai.ml.entities import Hub, Project
from azure.identity import DefaultAzureCredential

# Get configuration from environment
resource_group = os.getenv("RESOURCE_GROUP", "rg-agentic-ai-immersion")
subscription_id = os.getenv("SUBSCRIPTION_ID")
location = os.getenv("LOCATION", "eastus2")
hub_name = os.getenv("AI_HUB_NAME", "agentic-ai-hub")
project_name = os.getenv("AI_PROJECT_NAME", "agentic-ai-project")

print(f"Configuration:")
print(f"  Subscription: {subscription_id}")
print(f"  Resource Group: {resource_group}")
print(f"  Location: {location}")
print(f"  Hub Name: {hub_name}")
print(f"  Project Name: {project_name}")
print()

try:
    # Authenticate
    credential = DefaultAzureCredential()

    # Create ML Client
    ml_client = MLClient(
        credential=credential,
        subscription_id=subscription_id,
        resource_group_name=resource_group,
    )

    print(f"✅ Authenticated successfully")

    # Create Hub
    print(f"\nCreating AI Foundry Hub: {hub_name}...")
    hub = Hub(
        name=hub_name,
        location=location,
        display_name="Agentic AI Immersion Hub",
        description="Hub for Agentic AI Immersion Workshop",
    )

    hub_result = ml_client.workspaces.begin_create(hub).result()
    print(f"✅ AI Hub created: {hub_name}")
    print(f"   Hub ID: {hub_result.id}")

    # Create Project
    print(f"\nCreating AI Foundry Project: {project_name}...")
    project = Project(
        name=project_name,
        location=location,
        display_name="Agentic AI Immersion Project",
        description="Project for Agentic AI Immersion Workshop",
        hub_id=hub_result.id,
    )

    project_result = ml_client.workspaces.begin_create(project).result()
    print(f"✅ AI Project created: {project_name}")
    print(f"   Project ID: {project_result.id}")
    print(f"   Project Workspace ID: {project_result.workspace_id}")

    # Display project endpoint
    print(f"\n{'='*70}")
    print(f"🎉 Success!")
    print(f"{'='*70}")
    print(f"Hub Name: {hub_name}")
    print(f"Project Name: {project_name}")
    print(f"Project Endpoint: {project_result.discovery_url}")
    print(f"Project ID: {project_result.id}")
    print(f"\nUpdate your .env file with:")
    print(f"AI_FOUNDRY_PROJECT_ENDPOINT={project_result.discovery_url}")
    print(f"PROJECT_RESOURCE_ID={project_result.id}")

except Exception as e:
    print(f"❌ Error: {e}")
    import traceback

    traceback.print_exc()
    exit(1)
