# Configure the Google Cloud Provider
provider "google" {
  project = var.gcp_project_id
  # Region is now specified per resource where applicable, or defaults to a primary region if needed for global resources.
}

# --- State Backend Configuration ---
# This block tells Terraform where to store its state file.
# Using a GCS bucket is recommended for remote state management in GCP.
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  backend "gcs" {
    bucket = "tf-state-neomutt-01" # IMPORTANT: Replace with the name of YOUR GCS bucket
    prefix = "terraform/state"    # Optional: A path within the bucket to store the state file (e.g., your-app/env/terraform.tfstate)
  }
}
# --- End State Backend Configuration ---


# Define variables for user-specific values
variable "gcp_project_id" {
  description = "The GCP Project ID to deploy resources into."
  type        = string
  default     = "neomutt-01" # Updated with provided project ID
}

variable "gcp_region_vm1" {
  description = "The GCP region for VM1 and its network components."
  type        = string
  default     = "europe-west2" # Changed to europe-west2 (London)
}

variable "gcp_zone_vm1" {
  description = "The GCP zone for VM1."
  type        = string
  default     = "europe-west2-a" # Example zone A
}

variable "gcp_region_vm2" {
  description = "The GCP region for VM2 and its network components."
  type        = string
  default     = "europe-west2" # Changed to europe-west2 (London)
}

variable "gcp_zone_vm2" {
  description = "The GCP zone for VM2."
  type        = string
  default     = "europe-west2-b" # Example zone B (different from VM1)
}

variable "ssh_public_key" {
  description = "The SSH public key to use for the Linux VMs."
  type        = string
  # default     = "ssh-rsa AAAAB3Nz..." # Replace with your actual public key
}

# 🔹 VPC Network 1
resource "google_compute_network" "vpc1" {
  name                    = "vpc1-network"
  auto_create_subnetworks = false # We will create custom subnets
  routing_mode            = "REGIONAL" # Changed back to REGIONAL for intra-region peering
  mtu                     = 1460 # Default for custom mode, good practice to set
}

# 🔹 Subnet 1 in VPC 1 (Dual-Stack)
resource "google_compute_subnetwork" "subnet1_dual" {
  name          = "subnet1-dualstack"
  ip_cidr_range = "10.1.1.0/24"
  region        = var.gcp_region_vm1 # Use VM1's region
  network       = google_compute_network.vpc1.id
  stack_type    = "IPV4_IPV6" # Enable dual-stack
  ipv6_access_type = "EXTERNAL" # Required for public IPv6 on instances in this subnet
}

# 🔹 VPC Network 2
resource "google_compute_network" "vpc2" {
  name                    = "vpc2-network"
  auto_create_subnetworks = false # We will create custom subnets
  routing_mode            = "REGIONAL" # Changed back to REGIONAL for intra-region peering
  mtu                     = 1460 # Default for custom mode, good practice to set
}

# 🔹 Subnet 2 in VPC 2 (Dual-Stack)
resource "google_compute_subnetwork" "subnet2_dual" {
  name          = "subnet2-dualstack"
  ip_cidr_range = "10.2.1.0/24"
  region        = var.gcp_region_vm2 # Use VM2's region
  network       = google_compute_network.vpc2.id
  stack_type    = "IPV4_IPV6" # Enable dual-stack
  ipv6_access_type = "EXTERNAL" # Required for public IPv6 on instances in this subnet
}

# 🔹 External IPv4 Addresses for VMs
resource "google_compute_address" "vm1_ipv4_external" {
  name        = "vm1-ipv4-external"
  region      = var.gcp_region_vm1 # Use VM1's region
  address_type = "EXTERNAL"
}

resource "google_compute_address" "vm2_ipv4_external" {
  name        = "vm2-ipv4-external"
  region      = var.gcp_region_vm2 # Use VM2's region
  address_type = "EXTERNAL"
}

# 🔹 Firewall Rules for VPC1 (Firewall rules are global resources, but apply to networks)
resource "google_compute_firewall" "vpc1_allow_ssh" {
  name    = "vpc1-allow-ssh"
  network = google_compute_network.vpc1.name
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  allow { # Corrected: changed 'allows' to 'allow'
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags = ["vm1-tag"] # Apply to VMs with this tag
}

resource "google_compute_firewall" "vpc1_allow_icmp_internet" {
  name    = "vpc1-allow-icmp-internet"
  network = google_compute_network.vpc1.name
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0", "::/0"] # Allow ICMP from any IPv4 or IPv6 source
  allow { # Corrected: changed 'allows' to 'allow'
    protocol = "icmp"
  }
  target_tags = ["vm1-tag"]
}

resource "google_compute_firewall" "vpc1_allow_icmp_from_vpc2" {
  name    = "vpc1-allow-icmp-from-vpc2"
  network = google_compute_network.vpc1.name
  direction = "INGRESS"
  # Allow ICMP from VPC2's IPv4 and IPv6 CIDRs (using subnet CIDR blocks)
  source_ranges = [google_compute_subnetwork.subnet2_dual.ip_cidr_range, google_compute_subnetwork.subnet2_dual.ipv6_cidr_range] # Corrected: Use subnet CIDR blocks
  allow { # Corrected: changed 'allows' to 'allow'
    protocol = "icmp"
  }
  target_tags = ["vm1-tag"]
}

resource "google_compute_firewall" "vpc1_allow_ssh_from_vpc2" {
  name    = "vpc1-allow-ssh-from-vpc2"
  network = google_compute_network.vpc1.name
  direction = "INGRESS"
  # Allow SSH from VPC2's IPv4 and IPv6 CIDRs (using subnet CIDR blocks)
  source_ranges = [google_compute_subnetwork.subnet2_dual.ip_cidr_range, google_compute_subnetwork.subnet2_dual.ipv6_cidr_range] # Corrected: Use subnet CIDR blocks
  allow { # Corrected: changed 'allows' to 'allow'
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags = ["vm1-tag"]
}

# 🔹 Firewall Rules for VPC2
resource "google_compute_firewall" "vpc2_allow_ssh" {
  name    = "vpc2-allow-ssh"
  network = google_compute_network.vpc2.name
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  allow { # Corrected: changed 'allows' to 'allow'
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags = ["vm2-tag"] # Apply to VMs with this tag
}

resource "google_compute_firewall" "vpc2_allow_icmp_internet" {
  name    = "vpc2-allow-icmp-internet"
  network = google_compute_network.vpc2.name
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0", "::/0"] # Allow ICMP from any IPv4 or IPv6 source
  allow { # Corrected: changed 'allows' to 'allow'
    protocol = "icmp"
  }
  target_tags = ["vm2-tag"]
}

resource "google_compute_firewall" "vpc2_allow_icmp_from_vpc1" {
  name    = "vpc2-allow-icmp-from-vpc1"
  network = google_compute_network.vpc2.name
  direction = "INGRESS"
  # Allow ICMP from VPC1's IPv4 and IPv6 CIDRs (using subnet CIDR blocks)
  source_ranges = [google_compute_subnetwork.subnet1_dual.ip_cidr_range, google_compute_subnetwork.subnet1_dual.ipv6_cidr_range] # Corrected: Use subnet CIDR blocks
  allow { # Corrected: changed 'allows' to 'allow'
    protocol = "icmp"
  }
  target_tags = ["vm2-tag"]
}

resource "google_compute_firewall" "vpc2_allow_ssh_from_vpc1" {
  name    = "vpc2-allow-ssh-from-vpc1"
  network = google_compute_network.vpc2.name
  direction = "INGRESS"
  # Allow SSH from VPC1's IPv4 and IPv6 CIDRs (using subnet CIDR blocks)
  source_ranges = [google_compute_subnetwork.subnet1_dual.ip_cidr_range, google_compute_subnetwork.subnet1_dual.ipv6_cidr_range] # Corrected: Use subnet CIDR blocks
  allow { # Corrected: changed 'allows' to 'allow'
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags = ["vm2-tag"]
}

# 🔹 VM Instance 1
resource "google_compute_instance" "vm1" {
  name         = "vm1-instance"
  machine_type = "e2-micro" # Smallest general-purpose machine type
  zone         = var.gcp_zone_vm1 # Use VM1's zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11" # Using Debian 11 as a base image
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet1_dual.id
    network_ip = "10.1.1.4" # Assign a static private IPv4 address
    
    # Attach external IPv4 address
    access_config {
      nat_ip = google_compute_address.vm1_ipv4_external.address
    }
    # Enable IPv6 on the network interface
    ipv6_access_config {
      network_tier = "STANDARD" # Corrected: Added required network_tier
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_public_key}" # Inject the SSH public key from the variable
  }

  tags = ["vm1-tag"] # Apply tag for firewall rules
}

# 🔹 VM Instance 2
resource "google_compute_instance" "vm2" {
  name         = "vm2-instance"
  machine_type = "e2-micro" # Smallest general-purpose machine type
  zone         = var.gcp_zone_vm2 # Use VM2's zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11" # Using Debian 11 as a base image
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet2_dual.id
    network_ip = "10.2.1.4" # Assign a static private IPv4 address

    # Attach external IPv4 address
    access_config {
      nat_ip = google_compute_address.vm2_ipv4_external.address
    }
    # Enable IPv6 on the network interface
    ipv6_access_config {
      network_tier = "STANDARD" # Corrected: Added required network_tier
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_public_key}" # Inject the same SSH public key
  }

  tags = ["vm2-tag"] # Apply tag for firewall rules
}

# 🔹 VPC Peering between VPC1 and VPC2
# GCP VPC peering is bidirectional by default, so only one resource is needed
resource "google_compute_network_peering" "vpc_peering" {
  name         = "vpc1-vpc2-peering"
  network      = google_compute_network.vpc1.self_link
  peer_network = google_compute_network.vpc2.self_link
}

# 🔹 Outputs
output "vm1_public_ipv4" {
  description = "Public IPv4 address of VM 1"
  value       = google_compute_instance.vm1.network_interface[0].access_config[0].nat_ip
}

output "vm1_public_ipv6" {
  description = "Public IPv6 address of VM 1"
  value       = google_compute_instance.vm1.network_interface[0].ipv6_access_config[0].external_ipv6
}

output "vm1_private_ipv4" {
  description = "Private IPv4 address of VM 1"
  value       = google_compute_instance.vm1.network_interface[0].network_ip
}

# Removed vm1_private_ipv6 output as ipv6_internal_ip_address is not a valid attribute.
# GCP instances do not expose their internal IPv6 address as a direct attribute.

output "vm2_public_ipv4" {
  description = "Public IPv4 address of VM 2"
  value       = google_compute_instance.vm2.network_interface[0].access_config[0].nat_ip
}

output "vm2_public_ipv6" {
  description = "Public IPv6 address of VM 2"
  value       = google_compute_instance.vm2.network_interface[0].ipv6_access_config[0].external_ipv6
}

output "vm2_private_ipv4" {
  description = "Private IPv4 address of VM 2"
  value       = google_compute_instance.vm2.network_interface[0].network_ip
}

# Removed vm2_private_ipv6 output as ipv6_internal_ip_address is not a valid attribute.
# GCP instances do not expose their internal IPv6 address as a direct attribute.
