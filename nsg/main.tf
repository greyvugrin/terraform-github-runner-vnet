
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">3.0.0"
    }
  }
}

resource "azurerm_resource_provider_registration" "github_network_provider" {
  name = "GitHub.Network"
}

resource "azurerm_resource_group" "resource_group" {
  location = var.location
  name     = "${var.base_name}-rg"
}

resource "azurerm_network_security_group" "actions_nsg" {
  name                = "${var.base_name}-actions-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.resource_group.name

  security_rule {
    name                       = "DenyInternetOutBoundOverwrite"
    priority                   = 400
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  security_rule {
    name                         = "AllowVnetOutBoundOverwrite"
    source_port_range            = "*"
    destination_port_range       = "443"
    source_address_prefix        = "*"
    destination_address_prefix   = "VirtualNetwork"
    access                       = "Allow"
    priority                     = 200
    direction                    = "Outbound"
    destination_address_prefixes = []
    protocol                     = "Tcp"
  }

  security_rule {
    name                         = "AllowAzureCloudOutBound"
    source_port_range            = "*"
    destination_port_range       = "443"
    source_address_prefix        = "*"
    destination_address_prefix   = "AzureCloud"
    access                       = "Allow"
    priority                     = 210
    direction                    = "Outbound"
    destination_address_prefixes = []
    protocol                     = "Tcp"
  }

  security_rule {
    name                   = "AllowInternetOutBoundGitHub"
    protocol               = "Tcp"
    source_port_range      = "*"
    destination_port_range = "443"
    source_address_prefix  = "*"
    access                 = "Allow"
    priority               = 220
    direction              = "Outbound"
    destination_address_prefixes = [
      "140.82.112.0/20",
      "142.250.0.0/15",
      "143.55.64.0/20",
      "192.30.252.0/22",
      "185.199.108.0/22"
    ]
  }

  security_rule {
    name                   = "AllowInternetOutBoundMicrosoft"
    protocol               = "Tcp"
    source_port_range      = "*"
    destination_port_range = "443"
    source_address_prefix  = "*"
    access                 = "Allow"
    priority               = 230
    direction              = "Outbound"
    destination_address_prefixes = [
      "13.64.0.0/11",
      "13.96.0.0/13",
      "13.104.0.0/14",
      "20.33.0.0/16",
      "20.34.0.0/15",
      "20.36.0.0/14",
      "20.40.0.0/13",
      "20.48.0.0/12",
      "20.64.0.0/10",
      "20.128.0.0/16",
      "52.224.0.0/11",
      "204.79.197.200"
    ]
  }

  security_rule {
    name                         = "AllowInternetOutBoundCannonical"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_range       = "443"
    source_address_prefix        = "*"
    access                       = "Allow"
    priority                     = 240
    direction                    = "Outbound"
    destination_address_prefix   = "185.125.188.0/22"
    destination_address_prefixes = []
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.base_name}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.resource_group.name
  address_space       = var.vnet_address_space
}

resource "azurerm_subnet" "runner_subnet" {
  name                 = "${var.base_name}-runner-subnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name

  address_prefixes = var.runner_subnet_address_prefixes

  delegation {
    name = "delegation"

    service_delegation {
      name = "GitHub.Network/networkSettings"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }


  # provisioner "local-exec" {
  #   command = "../scripts/create-ns.sh ${azurerm_resource_group.resource_group.name} ${var.base_name}-ns ${var.location} ${azurerm_subnet.runner_subnet.id} ${var.gh_org_id}"
  # }

  # provisioner "local-exec" {
  #   when = destroy
  #   command = "../scripts/delete-ns.sh ${azurerm_resource_group.resource_group.name} ${var.base_name}-ns"
  # }
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.runner_subnet.id
  network_security_group_id = azurerm_network_security_group.actions_nsg.id
}