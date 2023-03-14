
# Configure Azure Provider
terraform {

  required_version = ">=0.12"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.0.99"
    }
  }


}

provider "azurerm" {
  features {}
}
#Create Resource Groups
resource "azurerm_resource_group" "test-rg" {
  name     = "test-rg"
  location = var.avzs[0] 
}



#Create Virtual Networks = VPC
resource "azurerm_virtual_network" "test-vnet" {
  name                = "test-vnet"
  location            = azurerm_resource_group.test-rg.location
  resource_group_name = azurerm_resource_group.test-rg.name
  address_space       = ["10.20.0.0/16"]

  tags = {
    environment = "test demo"
  }
}


#Create Subnet
resource "azurerm_subnet" "pools-subnet" {
  name                 = "pools-subnet"
  resource_group_name  = azurerm_resource_group.test-rg.name
  virtual_network_name = azurerm_virtual_network.test-vnet.name
  address_prefixes     = ["10.20.10.0/24"]
}

#Create Private Network Interfaces = ENI
resource "azurerm_network_interface" "net-inter" {
  name                = "net-inter-${count.index + 1}"
  location            = azurerm_resource_group.test-rg.location
  resource_group_name = azurerm_resource_group.test-rg.name
  count               = 2

  ip_configuration {
    name                          = "ipconfig-${count.index + 1}"
    subnet_id                     = azurerm_subnet.pools-subnet.id
    private_ip_address_allocation = "Dynamic"

  }
}
#Create Load Balancer
resource "azurerm_lb" "test-lb" {
  name                = "test-lb"
  location            = azurerm_resource_group.test-rg.location
  resource_group_name = azurerm_resource_group.test-rg.name

  frontend_ip_configuration {
    name                          = "lb-ip"
    subnet_id                     = azurerm_subnet.pools-subnet.id
    private_ip_address            = var.env == "Static" ? var.private_ip : null
    private_ip_address_allocation = var.env == "Static" ? "Static" : "Dynamic"
  }
}
#Create Loadbalancing Rules
resource "azurerm_lb_rule" "test-inbound-rules" {
  loadbalancer_id                = azurerm_lb.test-lb.id
  resource_group_name            = azurerm_resource_group.test-rg.name
  name                           = "ssh-inbound-rule"
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  frontend_ip_configuration_name = "lb-ip"
  probe_id                       = azurerm_lb_probe.ssh-inbound-probe.id
  backend_address_pool_ids        = ["${azurerm_lb_backend_address_pool.backend-pool.id}"]
 

}
#Create health Probe
resource "azurerm_lb_probe" "ssh-inbound-probe" {
  resource_group_name = azurerm_resource_group.test-rg.name
  loadbalancer_id     = azurerm_lb.test-lb.id
  name                = "ssh-inbound-probe"
  port                = 22
}
#Create Backend Address Pool
resource "azurerm_lb_backend_address_pool" "backend-pool" {
  loadbalancer_id = azurerm_lb.test-lb.id
  name            = "backend-pool"
}
#Backend Pool Addition
resource "azurerm_network_interface_backend_address_pool_association" "pool-asso" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.net-inter.*.id[count.index]
  ip_configuration_name   = azurerm_network_interface.net-inter.*.ip_configuration.0.name[count.index]
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend-pool.id

}
# Create SSH key
resource "tls_private_key" "linuxvmsshkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create NSG/rule
resource "azurerm_network_security_group" "tesr-nsg" {
  name                = "tesr-nsg"
  location            = azurerm_resource_group.test-rg.location
  resource_group_name = azurerm_resource_group.test-rg.name


  #Add rule for Inbound Access
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = var.ssh_access_port 
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


#Connect NSG to Subnet
resource "azurerm_subnet_network_security_group_association" "nsg-assoc" {
  subnet_id                 = azurerm_subnet.pools-subnet.id
  network_security_group_id = azurerm_network_security_group.tesr-nsg.id
}



#Availability Set - Fault Domains 
resource "azurerm_availability_set" "vmavset" {
  name                         = "vmavset"
  location                     = azurerm_resource_group.test-rg.location
  resource_group_name          = azurerm_resource_group.test-rg.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
  tags = {
    environment = "test"
  }
}


#Create Linux Virtual Machines 
resource "azurerm_linux_virtual_machine" "linux-vm" {

  name                  = "${var.demo}linuxvm${count.index}"
  location              = azurerm_resource_group.test-rg.location
  resource_group_name   = azurerm_resource_group.test-rg.name
  availability_set_id   = azurerm_availability_set.vmavset.id
  network_interface_ids = ["${element(azurerm_network_interface.net-inter.*.id, count.index)}"]
  size                  =  "Standard_B1s"  
  count                 = 2


  #Create Operating System Disk
  os_disk {
    name                 = "${var.demo}disk${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS" 
  }


  #Reference Source Image from Publisher
  source_image_reference {
    publisher = "Canonical"                    
    offer     = "0001-com-ubuntu-server-focal" 
    sku       = "20_04-lts-gen2"               
    version   = "latest"
  }


  #Create Computer Name and Specify Administrative User Credentials
  computer_name                   = "demonstration-linux-vm${count.index}"
  admin_username                  = "linuxsvruser${count.index}"
  disable_password_authentication = true



  #Create SSH Key for Secured Authentication - on Windows Management Server [Putty + PrivateKey]
  admin_ssh_key {
    username   = "linuxsvruser${count.index}"
    public_key = tls_private_key.linuxvmsshkey.public_key_openssh
  }


}