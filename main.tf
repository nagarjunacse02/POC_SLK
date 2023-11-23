# Creating a resource group
resource "azurerm_resource_group" "myrg" {
  name     = "myTFRG"
  location = "East US 2"
}

# Creating a virtual network
resource "azurerm_virtual_network" "tfDemoVM-vnet" {
  name                = "tfDemoVM-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.myrg.location
  resource_group_name = azurerm_resource_group.myrg.name
}

# Creating a subnet
resource "azurerm_subnet" "tfDemo-subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.myrg.name
  virtual_network_name = azurerm_virtual_network.tfDemoVM-vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Creating Network Security Group (NSG)
resource "azurerm_network_security_group" "tfDemoVM-nsg" {
  name                = "tfDemoVM-nsg"
  resource_group_name = azurerm_resource_group.myrg.name
  location            = azurerm_resource_group.myrg.location
  security_rule {
    name                       = "allow_SSH"
    description                = "Allow SSH access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_8080"
    description                = "Allow Jenkins access"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Creating a public IP address
resource "azurerm_public_ip" "tfDemoVM-publicip" {
  name                = "tfDemoVM-publicip"
  resource_group_name = azurerm_resource_group.myrg.name
  location            = azurerm_resource_group.myrg.location
  allocation_method   = "Dynamic" # You can use "Static" if you want a static public IP
}

# Create a network interface with public IP association
resource "azurerm_network_interface" "tfdemovm01" {
  name                = "tfdemovm01-nic"
  location            = azurerm_resource_group.myrg.location
  resource_group_name = azurerm_resource_group.myrg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.tfDemo-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tfDemoVM-publicip.id
  }
}

# Associating NSG with the network interface
resource "azurerm_network_interface_security_group_association" "tfdemovm01-nic-association" {
  network_interface_id      = azurerm_network_interface.tfdemovm01.id
  network_security_group_id = azurerm_network_security_group.tfDemoVM-nsg.id
}

# Create a Linux virtual machine
resource "azurerm_linux_virtual_machine" "tfDemoVM" {
  name                = "tfDemoVM-machine"
  resource_group_name = azurerm_resource_group.myrg.name
  location            = azurerm_resource_group.myrg.location
  size                = "Standard_B2s"
  admin_username      = "demouser"
  network_interface_ids = [
    azurerm_network_interface.tfdemovm01.id,
  ]

  admin_ssh_key {
    username   = "demouser"
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
}
