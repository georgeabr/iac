provider "azurerm" {
  features {}
}

resource "azurerm_virtual_network" "vpc1" {
  name                = "VPC1"
  location            = "East US"
  resource_group_name = "MyResourceGroup"
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_virtual_network" "vpc2" {
  name                = "VPC2"
  location            = "East US"
  resource_group_name = "MyResourceGroup"
  address_space       = ["10.2.0.0/16"]
}

resource "azurerm_virtual_network_peering" "peering" {
  name                      = "VPCPeering"
  resource_group_name       = "MyResourceGroup"
  virtual_network_name      = azurerm_virtual_network.vpc1.name
  remote_virtual_network_id = azurerm_virtual_network.vpc2.id
}

resource "azurerm_network_security_group" "nsg" {
  name                = "NSG-Allow-Ping-SSH"
  location            = "East US"
  resource_group_name = "MyResourceGroup"

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

resource "azurerm_linux_virtual_machine" "vm1" {
  name                  = "VM1"
  location              = "East US"
  resource_group_name   = "MyResourceGroup"
  size                  = "Standard_B1s"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.vm1.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }
}

resource "azurerm_linux_virtual_machine" "vm2" {
  name                  = "VM2"
  location              = "East US"
  resource_group_name   = "MyResourceGroup"
  size                  = "Standard_B1s"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.vm2.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }
}
