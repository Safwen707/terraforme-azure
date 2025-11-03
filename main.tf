# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}

# Configure the Microsoft Azure Provider that will be used to create and manage resources in Azure
provider "azurerm" {
  resource_provider_registrations = "none" # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
  features {}
}

# Create a resource group that represent a container for resources
resource "azurerm_resource_group" "mtc-rg" {
  name     = "mtc-rg"
  location = "norwayeast"
  tags = {
    environment = "dev"
  }
}
resource "azurerm_virtual_network" "mtc-network" {
  name                = "mtc-network"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name
  address_space       = ["10.123.0.0/16"]
   tags = {
    environment = "dev"
  }
  
}
resource "azurerm_subnet" "mtc-subnet" {
  name                 = "mtc-subnet"
  resource_group_name  = azurerm_resource_group.mtc-rg.name
  virtual_network_name = azurerm_virtual_network.mtc-network.name
  address_prefixes     = ["10.123.1.0/24"]


}

resource "azurerm_network_security_group" "mtc-nsg" {
  name                = "mtc-nsg"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name
  tags = {
    environment = "dev"
  }

}
resource "azurerm_network_security_rule" "mtc-nsg-rule" {
  name                        = "mtc-nsg-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.mtc-rg.name
  network_security_group_name = azurerm_network_security_group.mtc-nsg.name
}

resource "azurerm_subnet_network_security_group_association" "mtc-sga" {
  subnet_id                 = azurerm_subnet.mtc-subnet.id
  network_security_group_id = azurerm_network_security_group.mtc-nsg.id
}

resource "azurerm_public_ip" "mtc-ip" {
  name                = "mtc-ip"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  allocation_method   = "Static"  # ← Changé à Static


  tags = {
  
    environment = "dev"
  }
}

resource "azurerm_network_interface" "mtc-nic" {
  name                = "mtc-nic"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mtc-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mtc-ip.id
  }
  tags = {
    environment = "dev"
  }
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "mtc-vm" {
  name                = "mtc-vm"
  resource_group_name = azurerm_resource_group.mtc-rg.name      # ✅ CORRIGÉ: mtc-rg
  location            = azurerm_resource_group.mtc-rg.location  # ✅ CORRIGÉ: mtc-rg
  size                = "Standard_B1s"  # ✅ Plus petit (moins cher) pour tests
  admin_username      = "adminuser"
  
  network_interface_ids = [
    azurerm_network_interface.mtc-nic.id,  # ✅ CORRIGÉ: mtc-nic
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  provisioner "local-exec" {
    command = templatefile("${path.module}/${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "adminuser",
      identityfile = "~/.ssh/id_rsa"
    })
    interpreter = var.host_os == "linux" ? ["bash", "-c"] : ["Powershell", "-Command"]
  }

 
  custom_data = base64encode(file("${path.module}/customdata.tpl"))

  tags = {
    environment = "dev"
  }
}

data "azurerm_public_ips" "mtc-ip-data" {
  
  resource_group_name = azurerm_resource_group.mtc-rg.name
  attachment_status   = "Attached"
}
output "mtc-vm-public-ip" {
  value = data.azurerm_public_ips.mtc-ip-data.public_ips[0].ip_address
}
