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

# 🔹 Single Dual-Stack Subnet for Each VPC
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

# 🔹 Public IPv6 for VM1 & VM2
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

# 🔹 Network Interfaces for VM1 & VM2 (Dual-Stack, IPv6 Primary)
resource "azurerm_network_interface" "vm1_nic" {
  name                = "VM1-NIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "VM1-IPConfig-IPv4"
    subnet_id                     = azurerm_subnet.subnet1_dual.id
    private_ip_address_allocation = "Dynamic"
    primary                       = false
  }

  ip_configuration {
    name                          = "VM1-IPConfig-IPv6"
    subnet_id                     = azurerm_subnet.subnet1_dual.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm1_ipv6.id
    primary                       = true  # 🔹 IPv6 as primary
  }
}

resource "azurerm_network_interface" "vm2_nic" {
  name                = "VM2-NIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "VM2-IPConfig-IPv4"
    subnet_id                     = azurerm_subnet.subnet2_dual.id
    private_ip_address_allocation = "Dynamic"
    primary                       = false
  }

  ip_configuration {
    name                          = "VM2-IPConfig-IPv6"
    subnet_id                     = azurerm_subnet.subnet2_dual.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm2_ipv6.id
    primary                       = true  # 🔹 IPv6 as primary
  }
}

# 🔹 Virtual Machines (Debian Linux)
resource "azurerm_linux_virtual_machine" "vm1" {
  name                  = "VM1"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = "Standard_B1s"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.vm1_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30  # 30GB Disk
  }

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

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30  # 30GB Disk
  }

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
