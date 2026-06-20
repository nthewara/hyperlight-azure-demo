// Hyperlight Azure Demo — Bicep
// VM with NESTED VIRT (Intel D-series v5 => KVM), public IP, NSG allowing SSH.
// Deploy at subscription scope so it can create the resource group.

targetScope = 'subscription'

@description('Azure region. Hard default australiaeast.')
param location string = 'australiaeast'

@description('Suffix for resource names (keep short, lowercase).')
param suffix string = uniqueString(subscription().id, deployment().name)

@description('VM size — Intel v5 D-series required for nested virtualization / KVM.')
param vmSize string = 'Standard_D4s_v5'

@description('Admin username for the VM.')
param adminUsername string = 'azureuser'

@description('SSH public key contents for the admin user.')
@secure()
param sshPublicKey string

@description('Source CIDR allowed to SSH in. Lock to your public IP /32.')
param sshSourceCidr string

var shortSuffix = toLower(substring(suffix, 0, 5))
var name = 'hl-${shortSuffix}'
var tags = {
  purpose: 'hyperlight-demo'
  owner: 'nirmal'
  lab: 'true'
  SecurityControl: 'Ignore'
  'inbound-access': 'ssh-22-open-by-design'
  repo: 'nthewara/hyperlight-azure-demo'
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'hyperlight-demo-${shortSuffix}'
  location: location
  tags: tags
}

module lab 'lab.bicep' = {
  name: 'lab-${shortSuffix}'
  scope: rg
  params: {
    location: location
    name: name
    tags: tags
    vmSize: vmSize
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    sshSourceCidr: sshSourceCidr
  }
}

output resourceGroup string = rg.name
output vmName string = lab.outputs.vmName
output publicIp string = lab.outputs.publicIp
output sshCommand string = 'ssh ${adminUsername}@${lab.outputs.publicIp}'
output vmSize string = vmSize
