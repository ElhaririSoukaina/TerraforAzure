#Availability Zones
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

variable "webres" {
  default = ["vm", "appgw"]
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

