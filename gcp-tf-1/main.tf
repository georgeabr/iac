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

# 🔹 Firewall Rules for VPC1
resource "google_compute_firewall" "vpc1_allow_ssh" {
  name    = "vpc1-allow-ssh"
  network = google_compute_network.vpc1.name
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags = ["vm1-tag"] # Apply to VMs with this tag
}

resource "google_compute_firewall" "vpc1_allow_icmp_internet_ipv4" { # New rule for IPv4 ICMP
  name    = "vpc1-allow-icmp-internet-ipv4"
  network = google_compute_network.vpc1.name
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "icmp"
  }
  target_tags = ["vm1-tag"]
}

resource "google_compute_firewall" "vpc1_allow_icmp_internet_ipv6" { # New rule for IPv6 ICMP
  name    = "vpc1-allow-icmp-internet-ipv6"
  network = google_compute_network.vpc1.name
  direction = "INGRESS"
  source_ranges = ["::/0"]
  allow {
    protocol = "58" # Reverted to 58 for IPv6 ICMP
  }
  target_tags = ["vm1-tag"]
}

resource "google_compute_firewall" "vpc1_allow_icmp_from_vpc2_ipv4" { # New rule for IPv4 ICMP from VPC2
  name    = "vpc1-allow-icmp-from-vpc2-ipv4"
  network = google_compute_network.vpc1.name
  direction = "INGRESS"
  source_ranges = [google_compute_subnetwork.subnet2_dual.ip_cidr_range] # Corrected: Use subnet IPv4 CIDR
  allow {
    protocol = "icmp"
  }
  target_tags = ["vm1-tag"]
}

resource "google_compute_firewall" "vpc1_allow_icmp_from_vpc2_ipv6" { # New rule for IPv6 ICMP from VPC2
  name    = "vpc1-allow-icmp-from-vpc2-ipv6"
  network = google_compute_network.vpc1.name
  direction = "INGRESS"
  source_tags = ["vm2-tag"] # Corrected: Use source_tags for peering IPv6
  allow {
    protocol = "58" # Reverted to 58 for IPv6 ICMP
  }
  target_tags = ["vm1-tag"]
  depends_on = [google_compute_subnetwork.subnet2_dual] # Explicit dependency for IPv6 CIDR
}

resource "google_compute_firewall" "vpc1_allow_ssh_from_vpc2_ipv4" { # New rule for IPv4 SSH from VPC2
  name    = "vpc1-allow-ssh-from-vpc2-ipv4"
  network = google_compute_network.vpc1.name
  direction = "INGRESS"
  source_ranges = [google_compute_subnetwork.subnet2_dual.ip_cidr_range] # Corrected: Use subnet IPv4 CIDR
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags = ["vm1-tag"]
}

resource "google_compute_firewall" "vpc1_allow_ssh_from_vpc2_ipv6" { # New rule for IPv6 SSH from VPC2
  name    = "vpc1-allow-ssh-from-vpc2-ipv6"
  network = google_compute_network.vpc1.name
  direction = "INGRESS"
  source_tags = ["vm2-tag"] # Corrected: Use source_tags for peering IPv6
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags = ["vm1-tag"]
  depends_on = [google_compute_subnetwork.subnet2_dual] # Explicit dependency for IPv6 CIDR
}


# 🔹 Firewall Rules for VPC2
resource "google_compute_firewall" "vpc2_allow_ssh" {
  name    = "vpc2-allow-ssh"
  network = google_compute_network.vpc2.name
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags = ["vm2-tag"] # Apply to VMs with this tag
}

resource "google_compute_firewall" "vpc2_allow_icmp_internet_ipv4" { # New rule for IPv4 ICMP
  name    = "vpc2-allow-icmp-internet-ipv4"
  network = google_compute_network.vpc2.name
  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "icmp"
  }
  target_tags = ["vm2-tag"]
}

resource "google_compute_firewall" "vpc2_allow_icmp_internet_ipv6" { # New rule for IPv6 ICMP
  name    = "vpc2-allow-icmp-internet-ipv6"
  direction = "INGRESS"
  source_ranges = ["::/0"]
  allow {
    protocol = "58" # Reverted to 58 for IPv6 ICMP
  }
  target_tags = ["vm2-tag"]
}

resource "google_compute_firewall" "vpc2_allow_icmp_from_vpc1_ipv4" { # New rule for IPv4 ICMP from VPC1
  name    = "vpc2-allow-icmp-from-vpc1-ipv4"
  network = google_compute_network.vpc2.name
  direction = "INGRESS"
  source_ranges = [google_compute_subnetwork.subnet1_dual.ip_cidr_range] # Corrected: Use subnet IPv4 CIDR
  allow {
    protocol = "icmp"
  }
  target_tags = ["vm2-tag"]
}

resource "google_compute_firewall" "vpc2_allow_icmp_from_vpc1_ipv6" { # New rule for IPv6 ICMP from VPC1
  name    = "vpc2-allow-icmp-from-vpc1-ipv6"
  network = google_compute_network.vpc2.name
  direction = "INGRESS"
  source_tags = ["vm1-tag"] # Corrected: Use source_tags for peering IPv6
  allow {
    protocol = "58" # Reverted to 58 for IPv6 ICMP
  }
  target_tags = ["vm2-tag"]
  depends_on = [google_compute_subnetwork.subnet1_dual] # Explicit dependency for IPv6 CIDR
}

resource "google_compute_firewall" "vpc2_allow_ssh_from_vpc1_ipv4" { # New rule for IPv4 SSH from VPC1
  name    = "vpc2-allow-ssh-from-vpc1-ipv4"
  network = google_compute_network.vpc2.name
  direction = "INGRESS"
  source_ranges = [google_compute_subnetwork.subnet1_dual.ip_cidr_range] # Corrected: Use subnet IPv4 CIDR
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags = ["vm2-tag"]
}

resource "google_compute_firewall" "vpc2_allow_ssh_from_vpc1_ipv6" { # New rule for IPv6 SSH from VPC1
  name    = "vpc2-allow-ssh-from-vpc1-ipv6"
  network = google_compute_network.vpc2.name
  direction = "INGRESS"
  source_tags = ["vm1-tag"] # Corrected: Use source_tags for peering IPv6
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags = ["vm2-tag"]
  depends_on = [google_compute_subnetwork.subnet1_dual] # Explicit dependency for IPv6 CIDR
}

# --- Time Sleep Resources for IPv6 Propagation ---
# These resources introduce a delay to allow IPv6 CIDR ranges to fully propagate
# on the subnets before dependent resources (firewalls, VMs) try to use them.
resource "time_sleep" "wait_for_subnet1_ipv6" {
  # This depends on the IPv6 CIDR range being available on subnet1_dual
  depends_on = [google_compute_subnetwork.subnet1_dual]
  # Wait for 30 seconds. Adjust as needed based on observed propagation times.
  create_duration = "30s"
}

resource "time_sleep" "wait_for_subnet2_ipv6" {
  # This depends on the IPv6 CIDR range being available on subnet2_dual
  depends_on = [google_compute_subnetwork.subnet2_dual]
  # Wait for 30 seconds. Adjust as needed based on observed propagation times.
  create_duration = "30s"
}
# --- End Time Sleep Resources ---


# 🔹 VM Instance 1
resource "google_compute_instance" "vm1" {
  name         = "vm1-instance"
  machine_type = "e2-micro" # Smallest general-purpose machine type
  zone         = var.gcp_zone_vm1 # Use VM1's zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12" # Changed to Debian 12
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet1_dual.id
    network_ip = "10.1.1.4" # Assign a static private IPv4 address
    
    # Attach external IPv4 address
    access_config {
      nat_ip = google_compute_address.vm1_ipv4_external.address
    }
    # Removed ipv6_access_config block to bypass "IPv6 access config is not supported" error
    # The subnet will still be dual-stack, but the instance will only get IPv4.
  }

  metadata = {
    ssh-keys = "${var.ssh_public_key}" # Inject the SSH public key from the variable
  }

  tags = ["vm1-tag"] # Apply tag for firewall rules

  # Ensure subnet, peering, and IPv6 propagation are fully configured before creating the instance
  depends_on = [
    google_compute_subnetwork.subnet1_dual,
    google_compute_network_peering.vpc_peering,
    time_sleep.wait_for_subnet1_ipv6, # Added dependency on time_sleep
  ]
}

# 🔹 VM Instance 2
resource "google_compute_instance" "vm2" {
  name         = "vm2-instance"
  machine_type = "e2-micro" # Smallest general-purpose machine type
  zone         = var.gcp_zone_vm2 # Use VM2's zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12" # Changed to Debian 12
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet2_dual.id
    network_ip = "10.2.1.4" # Assign a static private IPv4 address

    # Attach external IPv4 address
    access_config {
      nat_ip = google_compute_address.vm2_ipv4_external.address
    }
    # Removed ipv6_access_config block to bypass "IPv6 access config is not supported" error
    # The subnet will still be dual-stack, but the instance will only get IPv4.
  }

  metadata = {
    ssh-keys = "${var.ssh_public_key}" # Inject the same SSH public key
  }

  tags = ["vm2-tag"] # Apply tag for firewall rules

  # Ensure subnet, peering, and IPv6 propagation are fully configured before creating the instance
  depends_on = [
    google_compute_subnetwork.subnet2_dual,
    google_compute_network_peering.vpc_peering,
    time_sleep.wait_for_subnet2_ipv6, # Added dependency on time_sleep
  ]
}

# 🔹 VPC Peering from VPC1 to VPC2
resource "google_compute_network_peering" "vpc1_to_vpc2_peering" {
  name         = "vpc1-to-vpc2-peering"
  network      = google_compute_network.vpc1.self_link
  peer_network = google_compute_network.vpc2.self_link
}

# 🔹 VPC Peering from VPC2 to VPC1 (Added for explicit bidirectional setup)
resource "google_compute_network_peering" "vpc2_to_vpc1_peering" {
  name         = "vpc2-to-vpc1-peering"
  network      = google_compute_network.vpc2.self_link
  peer_network = google_compute_network.vpc1.self_link
}

# 🔹 Outputs
output "vm1_public_ipv4" {
  description = "Public IPv4 address of VM 1"
  value       = google_compute_instance.vm1.network_interface[0].access_config[0].nat_ip
}

# Removed vm1_public_ipv6 output as ipv6_access_config is removed from instance.
# If you need IPv6 on the instance, this requires further debugging with GCP.
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

# Removed vm2_public_ipv6 output as ipv6_access_config is removed from instance.
# If you need IPv6 on the instance, this requires further debugging with GCP.
output "vm2_private_ipv4" {
  description = "Private IPv4 address of VM 2"
  value       = google_compute_instance.vm2.network_interface[0].network_ip
}

# Removed vm2_private_ipv6 output as ipv6_internal_ip_address is not a valid attribute.
# GCP instances do not expose their internal IPv6 address as a direct attribute.
