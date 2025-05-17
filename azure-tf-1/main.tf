terraform {
  backend "azurerm" {
    resource_group_name  = "ResourceGroupNE"
    storage_account_name = "myterraformstategit1"
    container_name       = "terraform-state"
    key                 = "terraform-azure-tf-1.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

resource "azurerm_resource_group" "rg" {
  name     = "MyResourceGroup"
  location = "UK South"
}

resource "azurerm_virtual_network" "vpc1" {
  name                = "VPC1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.1.0.0/16", "2001:db8:abcd:0012::/64"]  # IPv4 + IPv6
}

resource "azurerm_virtual_network" "vpc2" {
  name                = "VPC2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.2.0.0/16", "2001:db8:abcd:0022::/64"]  # IPv4 + IPv6
}

resource "azurerm_subnet" "subnet1" {
  name                 = "Subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vpc1.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "subnet1_ipv6" {
  name                 = "Subnet1-IPv6"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vpc1.name
  address_prefixes     = ["2001:db8:abcd:0012::/64"]
}

resource "azurerm_subnet" "subnet2" {
  name                 = "Subnet2"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vpc2.name
  address_prefixes     = ["10.2.1.0/24"]
}

resource "azurerm_subnet" "subnet2_ipv6" {
  name                 = "Subnet2-IPv6"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vpc2.name
  address_prefixes     = ["2001:db8:abcd:0022::/64"]
}

resource "azurerm_virtual_network_peering" "peering1" {
  name                      = "PeeringBetweenVPCs"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vpc1.name
  remote_virtual_network_id = azurerm_virtual_network.vpc2.id
}

resource "azurerm_network_security_group" "nsg" {
  name                = "NSG-Allow-Ping-SSH"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowPing"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# 🔹 IPv6 Public IPs (Primary)
resource "azurerm_public_ip" "vm1_ipv6" {
  name                = "vm1-ipv6"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv6"
}

resource "azurerm_public_ip" "vm2_ipv6" {
  name                = "vm2-ipv6"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv6"
}

# 🔹 Network Interfaces for VM1 & VM2 (IPv6 Primary)
resource "azurerm_network_interface" "vm1_nic" {
  name                = "VM1-NIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "VM1-IPConfig-IPv6"
    subnet_id                     = azurerm_subnet.subnet1_ipv6.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm1_ipv6.id
    primary                       = true  # IPv6 as primary
  }
}

resource "azurerm_network_interface" "vm2_nic" {
  name                = "VM2-NIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "VM2-IPConfig-IPv6"
    subnet_id                     = azurerm_subnet.subnet2_ipv6.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm2_ipv6.id
    primary                       = true  # IPv6 as primary
  }
}

# 🔹 Output Public & Private IPv6 Addresses
output "vm1_public_ipv6" {
  value = azurerm_public_ip.vm1_ipv6.ip_address
}

output "vm1_private_ipv6" {
  value = azurerm_network_interface.vm1_nic.private_ip_address
}

output "vm2_public_ipv6" {
  value = azurerm_public_ip.vm2_ipv6.ip_address
}

output "vm2_private_ipv6" {
  value = azurerm_network_interface.vm2_nic.private_ip_address
}
