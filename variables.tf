#Create Locations - Availability Zones
variable "avzs" {
  default = ["eastus", "ukwest", "westeurope"]
}


#Prefix for demonstration
variable "demo" {
  default = "demo"
}


variable "env" {
  default = "Static"
}


#variable "tenant_id" {
# type = string
# default = "36b6838b-d41b-4ef5-8c96-abd06907a34e"
#}


#demoorate Naming Convention Prefix for Virtual Machine Environments -"${var.demo}-${var.mgmt}-vm01"
variable "mgmt" {
  description = "naming convention prefix"
  default     = "management"

}


#Specify type of resource being deployed here - "${var.demo}-${var.mgmt}-${var.webres[0]}-01"
variable "webres" {
  default = ["vm", "webapp", "slb", "appgw"]
}



#Load  Balancer Constructs
variable "private_ip" {
  default = "10.20.10.100"
}


#ssh port 

variable "ssh_access_port" {
  description = "dedicated ssh port for webserver shell access"
  default     = 22

}

