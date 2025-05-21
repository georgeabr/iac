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

# Define variables for user-specific values
# variable "azure_subscription_id" {
#   description = "The Azure Subscription ID to deploy resources into."
#   type        = string
#   # You should set this via a CI/CD variable or environment variable
#   # default     = "YOUR_AZURE_SUBSCRIPTION_ID" # Replace with your Subscription ID or remove default
# }

# variable "ssh_public_key" {
#   description = "The SSH public key to use for the Linux VMs."
#   type        = string
#   # You should set this via a CI/CD variable or environment variable
#   # default     = "ssh-rsa AAAAB3Nz..." # Replace with your actual public key or remove default
# }


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

# 🔹 Public IPs for VM1 & VM2 (IPv4 + IPv6)
resource "azurerm_public_ip" "vm1_ipv4" {
  name                = "vm1-ipv4"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static" # Keeping IPv4 as Static
  sku                 = "Standard"
  ip_version          = "IPv4"
}

resource "azurerm_public_ip" "vm1_ipv6" {
  name                = "vm1-ipv6"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic" # Corrected: Changed allocation_method to Dynamic for IPv6
  sku                 = "Basic"
  ip_version          = "IPv6"
}

resource "azurerm_public_ip" "vm2_ipv4" {
  name                = "vm2-ipv4"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static" # Keeping IPv4 as Static
  sku                 = "Standard"
  ip_version          = "IPv4"
}

resource "azurerm_public_ip" "vm2_ipv6" {
  name                = "vm2-ipv6"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic" # Corrected: Changed allocation_method to Dynamic for IPv6
  sku                 = "Basic"
  ip_version          = "IPv6"
}

# 🔹 Network Security Groups for SSH and Ping
resource "azurerm_network_security_group" "vm1_nsg" {
  name                = "VM1-NSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Allow SSH (TCP port 22) from anywhere
  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*" # WARNING: Allowing SSH from anywhere (0.0.0.0/0 or *) is not recommended for production. Restrict to known IPs.
    destination_address_prefix = "*"
  }

  # Allow Ping (ICMP) from anywhere (for public ping)
  security_rule {
    name                       = "AllowPingFromAnywhere"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*" # Allow from anywhere
    destination_address_prefix = "*"
  }

  # Allow Ping (ICMP) from VPC2's IPv4 CIDR (for private ping)
  security_rule {
    name                       = "AllowPingFromVPC2-IPv4"
    priority                   = 120 # Higher priority than AllowPingFromAnywhere
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.2.0.0/16" # VPC2 IPv4 CIDR
    destination_address_prefix = "*"
  }

    # Allow Ping (ICMP) from VPC2's IPv6 CIDR (for private ping)
  security_rule {
    name                       = "AllowPingFromVPC2-IPv6"
    priority                   = 130 # Higher priority than AllowPingFromAnywhere
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "2001:db8:abcd:0022::/64" # VPC2 IPv6 CIDR
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "vm2_nsg" {
  name                = "VM2-NSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Allow SSH (TCP port 22) from anywhere
  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*" # WARNING: Allowing SSH from anywhere (0.0.0.0/0 or *) is not recommended for production. Restrict to known IPs.
    destination_address_prefix = "*"
  }

  # Allow Ping (ICMP) from anywhere (for public ping)
  security_rule {
    name                       = "AllowPingFromAnywhere"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*" # Allow from anywhere
    destination_address_prefix = "*"
  }

  # Allow Ping (ICMP) from VPC1's IPv4 CIDR (for private ping)
  security_rule {
    name                       = "AllowPingFromVPC1-IPv4"
    priority                   = 120 # Higher priority than AllowPingFromAnywhere
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.1.0.0/16" # VPC1 IPv4 CIDR
    destination_address_prefix = "*"
  }

  # Allow Ping (ICMP) from VPC1's IPv6 CIDR (for private ping)
  security_rule {
    name                       = "AllowPingFromVPC1-IPv6"
    priority                   = 130 # Higher priority than AllowPingFromAnywhere
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "2001:db8:abcd:0012::/64" # VPC1 IPv6 CIDR
    destination_address_prefix = "*"
  }
}

# 🔹 Associate NSGs with Network Interfaces
resource "azurerm_network_interface_security_group_association" "vm1_nsg_association" {
  network_interface_id      = azurerm_network_interface.vm1_nic.id
  network_security_group_id = azurerm_network_security_group.vm1_nsg.id
}

resource "azurerm_network_interface_security_group_association" "vm2_nsg_association" {
  network_interface_id      = azurerm_network_interface.vm2_nic.id
  network_security_group_id = azurerm_network_security_group.vm2_nsg.id
}


# 🔹 Network Interfaces for VM1 & VM2 (Dual-Stack)
resource "azurerm_network_interface" "vm1_nic" {
  name                = "VM1-NIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "VM1-IPv4"
    subnet_id                     = azurerm_subnet.subnet1_dual.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm1_ipv4.id
    primary                       = true  # Corrected: IPv4 must be primary
    private_ip_address_version    = "IPv4"
  }

  ip_configuration {
    name                          = "VM1-IPv6"
    subnet_id                     = azurerm_subnet.subnet1_dual.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm1_ipv6.id
    primary                       = false # Corrected: IPv6 cannot be primary
    private_ip_address_version    = "IPv6"
  }
}

resource "azurerm_network_interface" "vm2_nic" {
  name                = "VM2-NIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "VM2-IPv4"
    subnet_id                     = azurerm_subnet.subnet2_dual.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm2_ipv4.id
    primary                       = true  # Corrected: IPv4 must be primary
    private_ip_address_version    = "IPv4"
  }

  ip_configuration {
    name                          = "VM2-IPv6"
    subnet_id                     = azurerm_subnet.subnet2_dual.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm2_ipv6.id
    primary                       = false # Corrected: IPv6 cannot be primary
    private_ip_address_version    = "IPv6"
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

# 🔹 Custom Route Tables for VPC1 and VPC2
resource "azurerm_route_table" "rt1" {
  name                = "VPC1-RT"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Note: Default routes to Internet Gateway are typically handled by system routes
  # when a subnet is associated with a route table and has a public IP or is in a public subnet.
  # Explicitly defining them here is optional but can be done if needed.
}

resource "azurerm_route_table" "rt2" {
  name                = "VPC2-RT"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Note: Default routes to Internet Gateway are typically handled by system routes
  # when a subnet is associated with a route table and has a public IP or is in a public subnet.
  # Explicitly defining them here is optional but can be done if needed.
}

# 🔹 Associate Custom Route Tables with Subnets
resource "azurerm_subnet_route_table_association" "subnet1_rta" {
  subnet_id      = azurerm_subnet.subnet1_dual.id
  route_table_id = azurerm_route_table.rt1.id
}

resource "azurerm_subnet_route_table_association" "subnet2_rta" {
  subnet_id      = azurerm_subnet.subnet2_dual.id
  route_table_id = azurerm_route_table.rt2.id
}


# 🔹 VNet Peering from VPC1 to VPC2
resource "azurerm_virtual_network_peering" "vpc1_to_vpc2_peering" {
  name                      = "vpc1-to-vpc2-peering"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vpc1.name
  remote_virtual_network_id = azurerm_virtual_network.vpc2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# 🔹 VNet Peering from VPC2 to VPC1
resource "azurerm_virtual_network_peering" "vpc2_to_vpc1_peering" {
  name                      = "vpc2-to-vpc1-peering"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vpc2.name
  remote_virtual_network_id = azurerm_virtual_network.vpc1.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}


# Note: Azure VNet peering automatically creates system routes.
# Explicitly adding routes below is often not strictly necessary for basic peering
# but can be helpful for clarity or in complex routing scenarios.
# Removed explicit route resources for peering to rely on Azure system routes.


# 🔹 Output Public & Private IPv4 and IPv6 Addresses
output "vm1_public_ipv4" {
  description = "Public IPv4 address of VM 1"
  value       = azurerm_public_ip.vm1_ipv4.ip_address
}

output "vm1_public_ipv6" {
  description = "Public IPv6 address of VM 1"
  value = azurerm_public_ip.vm1_ipv6.ip_address
}

output "vm1_private_ipv4" { # Added: Output for VM1 Private IPv4
  description = "Private IPv4 address of VM 1"
  value       = azurerm_network_interface.vm1_nic.ip_configuration[0].private_ip_address # Assuming IPv4 config is the first one
}

output "vm1_private_ipv6" { # Corrected: Reference the IPv6 ip_configuration
  description = "Private IPv6 address of VM 1"
  value       = azurerm_network_interface.vm1_nic.ip_configuration[1].private_ip_address # Assuming IPv6 config is the second one
}

output "vm2_public_ipv4" {
  description = "Public IPv4 address of VM 2"
  value       = azurerm_public_ip.vm2_ipv4.ip_address
}

output "vm2_public_ipv6" {
  description = "Public IPv6 address of VM 2"
  value = azurerm_public_ip.vm2_ipv6.ip_address
}

output "vm2_private_ipv4" { # Added: Output for VM2 Private IPv4
  description = "Private IPv4 address of VM 2"
  value       = azurerm_network_interface.vm2_nic.ip_configuration[0].private_ip_address # Assuming IPv4 config is the first one
}

output "vm2_private_ipv6" { # Corrected: Reference the IPv6 ip_configuration
  description = "Private IPv6 address of VM 2"
  value       = azurerm_network_interface.vm2_nic.ip_configuration[1].private_ip_address # Assuming IPv6 config is the second one
}
