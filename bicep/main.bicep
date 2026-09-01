@description('Azure region for deployment. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Environment name for the deployment.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environmentName string

@description('Name of the existing container image to deploy.')
param containerImageName string

@description('Tag of the existing container image to deploy.')
param containerImageTag string

@description('Basic tags applied to the deployed resources.')
var commonTags = {
  environment: environmentName
  managedBy: 'bicep'
  workload: 'monitoring'
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'law-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
  tags: commonTags
}

// Container Apps Environment for hosting future apps, with logs sent to the existing Log Analytics workspace.
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
  tags: commonTags
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-${environmentName}-${uniqueString(resourceGroup().id)}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
      }
    }
    template: {
      containers: [
        {
          name: 'app'
          image: '${containerImageName}:${containerImageTag}'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
  tags: commonTags
}
