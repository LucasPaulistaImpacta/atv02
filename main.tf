terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  skip_provider_registration = true
  features {}
}

resource "azurerm_resource_group" "atv02-rg" {
  name     = "atv02"
  location = "eastus"
}

resource "azurerm_virtual_network" "atv02-vnet" {
  name                = "vnet"
  location            = azurerm_resource_group.atv02-rg.location
  resource_group_name = azurerm_resource_group.atv02-rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "atv02-subnet" {
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.atv02-rg.name
  virtual_network_name = azurerm_virtual_network.atv02-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "atv02-nsg" {
  name                = "nsg"
  location            = azurerm_resource_group.atv02-rg.location
  resource_group_name = azurerm_resource_group.atv02-rg.name

  security_rule {
    name                       = "ssh"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "BD"
    access                     = "Allow"
    direction                  = "Inbound"
    priority                   = 1002
    protocol                   = "Tcp"
    destination_port_range     = "3306"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "atv02-ip" {
  name                = "public-ip"
  resource_group_name = azurerm_resource_group.atv02-rg.name
  location            = azurerm_resource_group.atv02-rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "atv02-ni" {
  name                = "nic"
  location            = azurerm_resource_group.atv02-rg.location
  resource_group_name = azurerm_resource_group.atv02-rg.name

  ip_configuration {
    name                          = "ipvm"
    subnet_id                     = azurerm_subnet.atv02-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.atv02-ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "atv02-nicnsg" {
  network_interface_id      = azurerm_network_interface.atv02-ni.id
  network_security_group_id = azurerm_network_security_group.atv02-nsg.id
}

resource "azurerm_storage_account" "storage_aula_db" {
  name                     = "storageauladb"
  resource_group_name      = azurerm_resource_group.atv02-rg.name
  location                 = azurerm_resource_group.atv02-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_linux_virtual_machine" "atv02-vm" {
  name                = "virtual-machine"
  resource_group_name = azurerm_resource_group.atv02-rg.name
  location            = azurerm_resource_group.atv02-rg.location
  size                = "Standard_DS1_v2"

  network_interface_ids = [
    azurerm_network_interface.atv02-ni.id
  ]

  os_disk {
    name                 = "myOsDBDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "myvm"
  admin_username                  = "adminuser"
  admin_password                  = "admin@123mudar"
  disable_password_authentication = false

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.storage_aula_db.primary_blob_endpoint
  }

  depends_on = [azurerm_resource_group.atv02-rg]
}

resource "time_sleep" "wait_30_seconds_db" {
  depends_on      = [azurerm_linux_virtual_machine.atv02-vm]
  create_duration = "30s"
}

resource "null_resource" "upload_db" {
  provisioner "file" {
    connection {
      type     = "ssh"
      user     = "adminuser"
      password = "admin@123mudar"
      host     = azurerm_public_ip.atv02-ip.ip_address
    }
    source      = "mysql"
    destination = "/home/adminuser"
  }

  depends_on = [time_sleep.wait_30_seconds_db]
}

resource "null_resource" "install-database" {
  triggers = {
    order = azurerm_linux_virtual_machine.atv02-vm.id
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = "adminuser"
      password = "admin@123mudar"
      host     = azurerm_public_ip.atv02-ip.ip_address
    }
    inline = [
      "sudo apt update",
      "sudo apt install -y mysql-server-5.7",
      "sudo cp -f /home/adminuser/mysql/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf",
      "sudo mysql < /home/adminuser/mysql/script.sql",
      "sudo systemctl restart mysql.service",
      "sleep 30"
    ]
  }
}

output "publicip" {
  value = azurerm_public_ip.atv02-ip.ip_address
}
