terraform {
    required_version = "> 0.12.0"
# The below section if not specified the terraform.tfstate file is created in current directory of your machine.
 backend "azurerm" {
 
  }
}

provider "azurerm" {
  features {}
  version = "~>2.0"
  subscription_id = "*****-*****-****-****"
  client_id = "*****-*****-****-****"
  tenant_id = "*****-*****-****-****"
  client_secret = "*****-*****-****-****"
}


resource   "azurerm_resource_group"   "rg"   { 
   name   =   "terraformtest-rg" 
   location   =   "East us" 
 } 

 resource   "azurerm_virtual_network"   "myvnet"   { 
   name   =   "my-vnet" 
   address_space   =   [ "10.0.0.0/16" ] 
   location   =   "East us" 
   resource_group_name   =   azurerm_resource_group.rg.name 
 } 

 resource   "azurerm_subnet"   "frontendsubnet"   { 
   name   =   "frontendSubnet" 
   resource_group_name   =    azurerm_resource_group.rg.name 
   virtual_network_name   =   azurerm_virtual_network.myvnet.name 
   address_prefix   =   "10.0.1.0/24" 
 } 

resource "azurerm_network_security_group" "examplensg" {
  name                = "acceptanceTestSecurityGroup1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "testrules" {
  for_each                    = local.nsgrules 
  name                        = each.key
  direction                   = each.value.direction
  access                      = each.value.access
  priority                    = each.value.priority
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.examplensg.name
}
 resource   "azurerm_public_ip"   "myvm1publicip"   { 
   name   =   "pip1" 
   location   =   "East us" 
   resource_group_name   =   azurerm_resource_group.rg.name 
   allocation_method   =   "Dynamic" 
   sku   =   "Basic" 
 } 

 resource   "azurerm_network_interface"   "myvm1nic"   { 
   name   =   "myvm1-nic" 
   location   =   "East us" 
   resource_group_name   =   azurerm_resource_group.rg.name 

   ip_configuration   { 
     name   =   "ipconfig1" 
     subnet_id   =   azurerm_subnet.frontendsubnet.id 
     private_ip_address_allocation   =   "Dynamic" 
     public_ip_address_id   =   azurerm_public_ip.myvm1publicip.id 
   } 
 } 
 resource "random_id" "kvname" {
  byte_length = 5
  prefix = "keyvault"
}  

 data "azurerm_client_config" "current" {}
resource "azurerm_key_vault" "azvault" {
  name                        = random_id.kvname.hex
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "get",
    ]

    secret_permissions = [
      "get", "backup", "delete", "list", "purge", "recover", "restore", "set",
    ]

    storage_permissions = [
      "get",
    ]
  }
}

#Create KeyVault VM password
resource "random_password" "vmpassword" {
  length = 20
  special = true
}
#Create Key Vault Secret
resource "azurerm_key_vault_secret" "vmpassword" {
  name         = "vmpassword"
  value        = random_password.vmpassword.result
  key_vault_id = azurerm_key_vault.azvault.id
  depends_on = [ azurerm_key_vault.azvault ]
}
 resource   "azurerm_windows_virtual_machine"   "example"   { 
   name                    =   "narendravm1"   
   location                =   "East us" 
   resource_group_name     =   azurerm_resource_group.rg.name 
   network_interface_ids   =   [ azurerm_network_interface.myvm1nic.id ] 
   size                    =   "Standard_DS1" 
   admin_username          =   "adminuser" 
   admin_password          =   azurerm_key_vault_secret.vmpassword.value 

   source_image_reference   { 
     publisher   =   "MicrosoftWindowsServer" 
     offer       =   "WindowsServer" 
     sku         =   "2019-Datacenter" 
     version     =   "latest" 
   } 

   os_disk   { 
     caching             =   "ReadWrite" 
     storage_account_type   =   "Standard_LRS" 
   } 
 } 

resource   "azurerm_resource_group"   "storagerg"   { 
   name   =   "st-terraform-rg" 
   location   =   "east us" 
 } 

# Create storage account 
resource "azurerm_storage_account" "mystorageaccount" {
  name                     = "narendra"
  location                 = azurerm_resource_group.storagerg.location
  resource_group_name      = azurerm_resource_group.storagerg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
