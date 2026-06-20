# Hyperlight Azure Demo — main infrastructure
# VM with NESTED VIRT (Intel D-series v5) for KVM, public IP, NSG allowing SSH.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
  # Partial backend — supply via -backend-config=~/workspace/tfvars/backend.hcl
  backend "azurerm" {
    key = "hyperlight-azure-demo.tfstate"
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

locals {
  suffix = random_string.suffix.result
  name   = "hl-${local.suffix}"
  tags = {
    purpose          = "hyperlight-demo"
    owner            = "nirmal"
    lab              = "true"
    SecurityControl  = "Ignore"
    "inbound-access" = "ssh-22-open-by-design"
    repo             = "nthewara/hyperlight-azure-demo"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "hyperlight-demo-${local.suffix}"
  location = var.location
  tags     = local.tags
}

# --- Networking ---
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.name}-vnet"
  address_space       = ["10.50.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

resource "azurerm_subnet" "subnet" {
  name                 = "${local.name}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.50.1.0/24"]
}

resource "azurerm_public_ip" "pip" {
  name                = "${local.name}-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

# NSG: ALLOW inbound SSH from the demo source IP so the demo is not silently blocked.
resource "azurerm_network_security_group" "nsg" {
  name                = "${local.name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags

  security_rule {
    name                       = "Allow-SSH-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_source_cidr
    destination_address_prefix = "*"
    description                = "Demo SSH access — intentionally open (see inbound-access tag)"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "${local.name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# --- VM (Intel D4s_v5 => nested virtualization / KVM) ---
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "${local.name}-vm"
  computer_name         = "hlvm${local.suffix}"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic.id]
  tags                  = local.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # cloud-init: installs build tools, Rust, LLVM, cargo-hyperlight, runs KVM check + demo.
  custom_data = base64encode(file("${path.module}/cloud-init.yaml"))

  boot_diagnostics {}
}
