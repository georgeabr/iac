terraform {
  backend "azurerm" {
    resource_group_name  = "ResourceGroupNE"
    storage_account_name = "myterraformstategit1"
    container_name       = "terraform-state"
    key                  = "terraform-azure-tf-1.tfstate"
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

# 🔹 Virtual Networks (Dual-Stack)
resource "azurerm_virtual_network" "vpc1" {
  name                = "VPC1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.1.0.0/16", "2001:db8:abcd:0012::/64"]
}

resource "azurerm_virtual_network" "vpc2" {
  name                = "VPC2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.2.0.0/16", "2001:db8:abcd:0022::/64"]
}

# 🔹 Subnets
resource "azurerm_subnet" "subnet1_dual" {
  name                 = "Subnet1-DualStack"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vpc1.name
  address_prefixes     = ["10.1.1.0/24", "2001:db8:abcd:0012::/64"]
}

resource "azurerm_subnet" "subnet2_dual" {
  name                 = "Subnet2-DualStack"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vpc2.name
  address_prefixes     = ["10.2.1.0/24", "2001:db8:abcd:0022::/64"]
}

# 🔹 Network Security Groups (NSGs)
resource "azurerm_network_security_group" "vm1_nsg" {
  name                = "VM1-NSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "0.0.0.0/0"  # Consider restricting
    destination_port_range     = "22"
  }

  security_rule {
    name                       = "AllowPing"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "vm2_nsg" {
  name                = "VM2-NSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "0.0.0.0/0"  # Consider restricting
    destination_port_range     = "22"
  }

  security_rule {
    name                       = "AllowPing"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# 🔹 Virtual Machines (Debian 12)
resource "azurerm_linux_virtual_machine" "vm1" {
  name                  = "VM1"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = "Standard_B1s"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.vm1_nic.id]

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-12"
    sku       = "12"
    version   = "latest"
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }
}

resource "azurerm_linux_virtual_machine" "vm2" {
  name                  = "VM2"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = "Standard_B1s"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.vm2_nic.id]

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-12"
    sku       = "12"
    version   = "latest"
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }
}

# 🔹 VNet Peering (Bidirectional)
resource "azurerm_virtual_network_peering" "vpc1_to_vpc2" {
  name                         = "vpc1-to-vpc2"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.vpc1.name
  remote_virtual_network_id    = azurerm_virtual_network.vpc2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "vpc2_to_vpc1" {
  name                         = "vpc2-to-vpc1"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.vpc2.name
  remote_virtual_network_id    = azurerm_virtual_network.vpc1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# 🔹 Outputs for All IPs
output "vm1_public_ipv4" {
  value = azurerm_public_ip.vm1_ipv4.ip_address
}

output "vm1_public_ipv6" {
  value = azurerm_public_ip.vm1_ipv6.ip_address
}

output "vm1_private_ipv4" {
  value = azurerm_network_interface.vm1_nic.ip_configuration[0].private_ip_address
}

output "vm1_private_ipv6" {
  value = azurerm_network_interface.vm1_nic.ip_configuration[1].private_ip_address
}

output "vm2_public_ipv4" {
  value = azurerm_public_ip.vm2_ipv4.ip_address
}

output "vm2_public_ipv6" {
  value = azurerm_public_ip.vm2_ipv6.ip_address
}

output "vm2_private_ipv4" {
  value = azurerm_network_interface.vm2_nic.ip_configuration[0].private_ip_address
}

output "vm2_private_ipv6" {
  value = azurerm_network_interface.vm2_nic.ip_configuration[1].private_ip_address
}
