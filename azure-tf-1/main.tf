terraform {
  backend "azurerm" {
    resource_group_name  = "ResourceGroupNE"
    storage_account_name = "myterraformstategit1"
    container_name       = "terraform-state"
    key                 = "terraform-azure-tf-2.tfstate"
    use_azuread_auth     = true  # Enables authentication via Azure AD
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "MyResourceGroup"
  location = "UK South"
}

resource "azurerm_virtual_network" "vpc1" {
  name                = "VPC1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_virtual_network" "vpc2" {
  name                = "VPC2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.2.0.0/16"]
}

resource "azurerm_subnet" "subnet1" {
  name                 = "Subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vpc1.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "subnet2" {
  name                 = "Subnet2"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vpc2.name
  address_prefixes     = ["10.2.1.0/24"]
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

resource "azurerm_network_interface" "vm1_nic" {
  name                = "VM1-NIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "VM1-IPConfig"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "vm2_nic" {
  name                = "VM2-NIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "VM2-IPConfig"
    subnet_id                     = azurerm_subnet.subnet2.id
    private_ip_address_allocation = "Dynamic"
  }
}

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
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-12"
    sku       = "12"
    version   = "latest"
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key # Uses GitHub Secret
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
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-12"
    sku       = "12"
    version   = "latest"
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key # Uses GitHub Secret
  }
}
