// Copyright (c) 2017, 2021, Oracle and/or its affiliates. All rights reserved.
// Licensed under the Mozilla Public License v2.0

/*
 * This example demonstrates round robin load balancing behavior by creating two instances, a configured
 * vcn and a load balancer. The public IP of the load balancer is outputted after a successful run, curl
 * this address to see the hostname change as different instances handle the request.
 *
 * NOTE: The https listener is included for completeness but should not be expected to work,
 * it uses dummy certs.
 */

variable "tenancy_ocid" {
}

variable "user_ocid" {
}

variable "fingerprint" {
}

variable "private_key_path" {
}

variable "compartment_ocid" {
}

variable "region" {
}

variable "instance_image_ocid" {
  type = map(string)

  default = {
    # See https://docs.us-phoenix-1.oraclecloud.com/images/
    # Oracle-provided image "Oracle-Linux-7.5-2018.10.16-0"
    us-phoenix-1   = "ocid1.image.oc1.phx.aaaaaaaaoqj42sokaoh42l76wsyhn3k2beuntrh5maj3gmgmzeyr55zzrwwa"
    us-ashburn-1   = "ocid1.image.oc1.iad.aaaaaaaageeenzyuxgia726xur4ztaoxbxyjlxogdhreu3ngfj2gji3bayda"
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaitzn6tdyjer7jl34h2ujz74jwy5nkbukbh55ekp6oyzwrtfa4zma"
    uk-london-1    = "ocid1.image.oc1.uk-london-1.aaaaaaaa32voyikkkzfxyo4xbdmadc2dmvorfxxgdhpnk6dw64fa3l4jh7wa"
  }
}

variable "instance_shape" {
  default = "VM.Standard2.1"
}

variable "availability_domain" {
  default = 3
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

data "oci_identity_availability_domain" "ad1" {
  compartment_id = var.tenancy_ocid
  ad_number      = 1
}

data "oci_identity_availability_domain" "ad2" {
  compartment_id = var.tenancy_ocid
  ad_number      = 2
}

/* Network */

resource "oci_core_vcn" "vcn1" {
  cidr_block     = "10.1.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "vcn1"
  dns_label      = "vcn1"
}

resource "oci_core_subnet" "subnet1" {
  availability_domain = data.oci_identity_availability_domain.ad1.name
  cidr_block          = "10.1.20.0/24"
  display_name        = "subnet1"
  dns_label           = "subnet1"
  security_list_ids   = [oci_core_security_list.securitylist1.id]
  compartment_id      = var.compartment_ocid
  vcn_id              = oci_core_vcn.vcn1.id
  route_table_id      = oci_core_route_table.routetable1.id
  dhcp_options_id     = oci_core_vcn.vcn1.default_dhcp_options_id

  provisioner "local-exec" {
    command = "sleep 5"
  }
}

resource "oci_core_subnet" "subnet2" {
  availability_domain = data.oci_identity_availability_domain.ad2.name
  cidr_block          = "10.1.21.0/24"
  display_name        = "subnet2"
  dns_label           = "subnet2"
  security_list_ids   = [oci_core_security_list.securitylist1.id]
  compartment_id      = var.compartment_ocid
  vcn_id              = oci_core_vcn.vcn1.id
  route_table_id      = oci_core_route_table.routetable1.id
  dhcp_options_id     = oci_core_vcn.vcn1.default_dhcp_options_id

  provisioner "local-exec" {
    command = "sleep 5"
  }
}

resource "oci_core_internet_gateway" "internetgateway1" {
  compartment_id = var.compartment_ocid
  display_name   = "internetgateway1"
  vcn_id         = oci_core_vcn.vcn1.id
}

resource "oci_core_route_table" "routetable1" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn1.id
  display_name   = "routetable1"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.internetgateway1.id
  }
}

resource "oci_core_public_ip" "test_reserved_ip" {
  compartment_id = "${var.compartment_ocid}"
  lifetime       = "RESERVED"

  lifecycle {
    ignore_changes = [private_ip_id]
  }
}

resource "oci_core_security_list" "securitylist1" {
  display_name   = "public"
  compartment_id = oci_core_vcn.vcn1.compartment_id
  vcn_id         = oci_core_vcn.vcn1.id

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      min = 443
      max = 443
    }
  }
}

/* Instances */

resource "oci_core_instance" "instance1" {
  availability_domain = data.oci_identity_availability_domain.ad1.name
  compartment_id      = var.compartment_ocid
  display_name        = "be-instance1"
  shape               = var.instance_shape

  metadata = {
    user_data = base64encode(var.user-data)
  }

  create_vnic_details {
    subnet_id      = oci_core_subnet.subnet1.id
    hostname_label = "be-instance1"
  }

  source_details {
    source_type = "image"
    source_id   = var.instance_image_ocid[var.region]
  }
}

resource "oci_core_instance" "instance2" {
  availability_domain = data.oci_identity_availability_domain.ad2.name
  compartment_id      = var.compartment_ocid
  display_name        = "be-instance2"
  shape               = var.instance_shape

  metadata = {
    user_data = base64encode(var.user-data)
  }

  create_vnic_details {
    subnet_id      = oci_core_subnet.subnet2.id
    hostname_label = "be-instance2"
  }

  source_details {
    source_type = "image"
    source_id   = var.instance_image_ocid[var.region]
  }
}

variable "user-data" {
  default = <<EOF
#!/bin/bash -x
echo '################### webserver userdata begins #####################'
touch ~opc/userdata.`date +%s`.start

# echo '########## yum update all ###############'
# yum update -y

echo '########## basic webserver ##############'
yum install -y httpd
systemctl enable  httpd.service
systemctl start  httpd.service
echo '<html><head></head><body><pre><code>' > /var/www/html/index.html
hostname >> /var/www/html/index.html
echo '' >> /var/www/html/index.html
cat /etc/os-release >> /var/www/html/index.html
echo '</code></pre></body></html>' >> /var/www/html/index.html
firewall-offline-cmd --add-service=http
systemctl enable  firewalld
systemctl restart  firewalld

touch ~opc/userdata.`date +%s`.finish
echo '################### webserver userdata ends #######################'
EOF

}

/* Load Balancer */

resource "oci_load_balancer" "lb1" {
  shape          = "100Mbps"
  compartment_id = var.compartment_ocid

  subnet_ids = [
    oci_core_subnet.subnet1.id,
    oci_core_subnet.subnet2.id,
  ]

  display_name = "lb1"
  reserved_ips {
      id = "${oci_core_public_ip.test_reserved_ip.id}"
    }
}

resource "oci_load_balancer" "lb2" {
  shape          = "100Mbps"
  compartment_id = var.compartment_ocid

  subnet_ids = [
    oci_core_subnet.subnet1.id,
    oci_core_subnet.subnet2.id,
  ]

  display_name = "lb1"
}


variable "load_balancer_shape_details_maximum_bandwidth_in_mbps" {
  default = 100
}

variable "load_balancer_shape_details_minimum_bandwidth_in_mbps" {
  default = 10
}

resource "oci_load_balancer" "flex_lb" {
  shape          = "flexible"
  compartment_id = var.compartment_ocid

  subnet_ids = [
    oci_core_subnet.subnet1.id,
    oci_core_subnet.subnet2.id,
  ]

  shape_details {
      #Required
      maximum_bandwidth_in_mbps = var.load_balancer_shape_details_maximum_bandwidth_in_mbps
      minimum_bandwidth_in_mbps = var.load_balancer_shape_details_minimum_bandwidth_in_mbps
    }

  display_name = "flex_lb"
}

resource "oci_load_balancer_backend_set" "lb-bes1" {
  name             = "lb-bes1"
  load_balancer_id = oci_load_balancer.lb1.id
  policy           = "ROUND_ROBIN"

  health_checker {
    port                = "80"
    protocol            = "HTTP"
    response_body_regex = ".*"
    url_path            = "/"
  }
}

resource "oci_load_balancer_backend_set" "lb-bes2" {
  name             = "lb-bes1"
  load_balancer_id = oci_load_balancer.lb2.id
  policy           = "ROUND_ROBIN"

  health_checker {
    port                = "80"
    protocol            = "TCP"
    response_body_regex = ".*"
    url_path            = "/"
  }

  ssl_configuration {
    protocols         = ["TLSv1.1", "TLSv1.2"]
    cipher_suite_name = oci_load_balancer_ssl_cipher_suite.test_ssl_cipher_suite2.name
    certificate_name  = oci_load_balancer_certificate.lb-cert2.certificate_name
  }
}

resource "oci_load_balancer_certificate" "lb-cert1" {
  load_balancer_id   = oci_load_balancer.lb1.id
  ca_certificate     = "-----BEGIN CERTIFICATE-----\nMIICljCCAX4CCQCEpaMjTCJ8WzANBgkqhkiG9w0BAQsFADANMQswCQYDVQQGEwJV\nUzAeFw0yMTAxMTkyMTI2MjRaFw0yNDAxMTkyMTI2MjRaMA0xCzAJBgNVBAYTAlVT\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAo83kaUQXpCcSoEuRVFX3\njztWDNKtWpjNG240f0RpERI1NnZtHH0qnZqfaWAQQa8kx3+W1LOeFbkkRnkJz19g\neIXR6TeavT+W5iRh4goK+N7gubYkSMa2shVf+XsoHKERSbhdhrtX+GqvKzAvplCt\nCgd4MDlsvLv/YHCLvJL4JgRxKyevjlnE1rqrICJMCLbbZMrIKTzwb/K13hGrm6Bc\n+Je9EC3MWWxd5jBwXu3vgIYRuGR4DPg/yfMKPZr2xFDLpBsv5jaqULS9t6GwoEBJ\nKN0NXp5obaQToYqMsvAZyHoEyfCBDka16Bm5hGF60FwqgUT3p/+qlBn61cAJe9t5\n8QIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQAX1rxV2hai02Pb4Cf8U44zj+1aY6wV\nLvOMWiL3zl53up4/X7PDcmWcPM9UMVCGTISZD6A6IPvNlkvbtvYCzgjhtGxDmrj7\nwTRV5gO9j3bAhxBO7XgTmwmD/9hpykM58nbhLFnkGf+Taja8qsy0U8H74Tr9w1M8\n8E5kghgGzBElNquM8AUuDakC1JL4aLO/VDMxe/1BLtmBHLZy3XTzVycjP9ZFPh6h\nT+cWJcVOjQSYY2U75sDnKD2Sg1cmK54HauA6SPh4kAkpmxyLyDZZjPBQe2sLFmmS\naZSE+g16yMR9TVHo3pTpRkxJwDEH0LePwYXA4vUIK3HHS6zgLe0ody8g\n-----END CERTIFICATE-----"
  certificate_name   = "certificate1"
  private_key        = "-----BEGIN RSA PRIVATE KEY-----\nMIIEogIBAAKCAQEAo83kaUQXpCcSoEuRVFX3jztWDNKtWpjNG240f0RpERI1NnZt\nHH0qnZqfaWAQQa8kx3+W1LOeFbkkRnkJz19geIXR6TeavT+W5iRh4goK+N7gubYk\nSMa2shVf+XsoHKERSbhdhrtX+GqvKzAvplCtCgd4MDlsvLv/YHCLvJL4JgRxKyev\njlnE1rqrICJMCLbbZMrIKTzwb/K13hGrm6Bc+Je9EC3MWWxd5jBwXu3vgIYRuGR4\nDPg/yfMKPZr2xFDLpBsv5jaqULS9t6GwoEBJKN0NXp5obaQToYqMsvAZyHoEyfCB\nDka16Bm5hGF60FwqgUT3p/+qlBn61cAJe9t58QIDAQABAoIBADIyHuOPJTt9abzL\nS26vpVw0D6uAR/UyS/Ay9k1ltliv3rSg19DaHlwLjPwqnvCx7jBgTeVCYZhAkvgx\nkSsGDDcCsw+npXiG6wP9dC1jbHdVPUJLqZTPqB6sZCu8bM9RIE4Z/DcUY+HRN3qh\nmoh5wn0HSvJkNokjhx+TfY687uQfDMu0de4V2UPScZ7mboCu9HqK9qu0/krdTMH1\nrtnnFGEnx/Pe38YJl0fWxo8BHKHprwEvWX0MQzQeklnUtxREMuofSAOBe/I2DJGh\n1I94b6I66ypxuX0qAozT1MPbJGuaR+puyKawLNAQmZa9pgrrFK7e8PQUzrGVpVCp\nFtwx420CgYEA0uX/G0ycia0UTdkxkIsKIiLjs12LC0XmYjiWgkoL0PjiZzcPITn6\nvqqqGSz44HwtbrttZPm3Mo79yJ5xFiHCX0vFJykgy6cfS94imMgm8qIOS0bXjX7w\nxH2BOgp0H32LP/Zt7owcWJLEIQCjj0/4+Nvu0GskGVHlE8EYrXWf1E8CgYEAxtWk\nxBo52uNXL712VGDPNxprVGUpWSbkXpE+7wtRso5LnAnAj6dpmZsGe2zaYjRIt3Ls\nGnno4HUmwpQ5yXlHFpDUJvb2soXq3afnuAh5aVu6aKRQoG/5o3cD4pOupNbjDDNs\nTVLtTLIAIYDbph/j7pV/JnJ2WHcdk6WiVJoW/b8CgYAopLZzNmJ8jeR51D+fEYyU\nY5DqQj7Hn2L0zt8CoO6CCVToe03pI1lVYWKCk44rBQNkca51ZUKO9cum3BIDJ+Jj\npyCJmX1+geigIGEefIQ1AlIq464q0Knp1B4RZ25Vm0Y4v28UJ+BWmYI+sfbTaaAb\npZbyh5NfZc717aKp2x9ANQKBgHQpvOkUqVhIGVe6yLbjGCyJMstLjqyXHDRjhvEB\nG+nFWEcBK47Br+Adwdu57JwTD6ida3LMZlE8IDjtgBVE1VNJqahaACasNlrpDWdn\nDAeRn4Yi+TfCM4Zcsdhdj1qecGdgY5WJLTnxhEIOlkSnvPJWRMKhfKKSdKUdz4i9\nvVDhAoGAEHxfhFLVwdTa0RMUq3KYSXa5WqLANRn2e62Cc3eUWekcUjbIATRF5AIo\nm0WS+rURZWy1Fd6fGg8sRHock0+vxwqeP6OlyW4tJMhL33NrNbgyvkXlMMIX6bC4\nUq8aAew0B3j61UUsTqhHMhYwIS3GOIHx/O10wwINPnUMIVER3Wg=\n-----END RSA PRIVATE KEY-----"
  public_certificate = "-----BEGIN CERTIFICATE-----\nMIICljCCAX4CCQCEpaMjTCJ8WzANBgkqhkiG9w0BAQsFADANMQswCQYDVQQGEwJV\nUzAeFw0yMTAxMTkyMTI2MjRaFw0yNDAxMTkyMTI2MjRaMA0xCzAJBgNVBAYTAlVT\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAo83kaUQXpCcSoEuRVFX3\njztWDNKtWpjNG240f0RpERI1NnZtHH0qnZqfaWAQQa8kx3+W1LOeFbkkRnkJz19g\neIXR6TeavT+W5iRh4goK+N7gubYkSMa2shVf+XsoHKERSbhdhrtX+GqvKzAvplCt\nCgd4MDlsvLv/YHCLvJL4JgRxKyevjlnE1rqrICJMCLbbZMrIKTzwb/K13hGrm6Bc\n+Je9EC3MWWxd5jBwXu3vgIYRuGR4DPg/yfMKPZr2xFDLpBsv5jaqULS9t6GwoEBJ\nKN0NXp5obaQToYqMsvAZyHoEyfCBDka16Bm5hGF60FwqgUT3p/+qlBn61cAJe9t5\n8QIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQAX1rxV2hai02Pb4Cf8U44zj+1aY6wV\nLvOMWiL3zl53up4/X7PDcmWcPM9UMVCGTISZD6A6IPvNlkvbtvYCzgjhtGxDmrj7\nwTRV5gO9j3bAhxBO7XgTmwmD/9hpykM58nbhLFnkGf+Taja8qsy0U8H74Tr9w1M8\n8E5kghgGzBElNquM8AUuDakC1JL4aLO/VDMxe/1BLtmBHLZy3XTzVycjP9ZFPh6h\nT+cWJcVOjQSYY2U75sDnKD2Sg1cmK54HauA6SPh4kAkpmxyLyDZZjPBQe2sLFmmS\naZSE+g16yMR9TVHo3pTpRkxJwDEH0LePwYXA4vUIK3HHS6zgLe0ody8g\n-----END CERTIFICATE-----"

  lifecycle {
    create_before_destroy = true
  }
}

resource "oci_load_balancer_certificate" "lb-cert2" {
  load_balancer_id   = oci_load_balancer.lb2.id
  ca_certificate     = "-----BEGIN CERTIFICATE-----\nMIICljCCAX4CCQCEpaMjTCJ8WzANBgkqhkiG9w0BAQsFADANMQswCQYDVQQGEwJV\nUzAeFw0yMTAxMTkyMTI2MjRaFw0yNDAxMTkyMTI2MjRaMA0xCzAJBgNVBAYTAlVT\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAo83kaUQXpCcSoEuRVFX3\njztWDNKtWpjNG240f0RpERI1NnZtHH0qnZqfaWAQQa8kx3+W1LOeFbkkRnkJz19g\neIXR6TeavT+W5iRh4goK+N7gubYkSMa2shVf+XsoHKERSbhdhrtX+GqvKzAvplCt\nCgd4MDlsvLv/YHCLvJL4JgRxKyevjlnE1rqrICJMCLbbZMrIKTzwb/K13hGrm6Bc\n+Je9EC3MWWxd5jBwXu3vgIYRuGR4DPg/yfMKPZr2xFDLpBsv5jaqULS9t6GwoEBJ\nKN0NXp5obaQToYqMsvAZyHoEyfCBDka16Bm5hGF60FwqgUT3p/+qlBn61cAJe9t5\n8QIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQAX1rxV2hai02Pb4Cf8U44zj+1aY6wV\nLvOMWiL3zl53up4/X7PDcmWcPM9UMVCGTISZD6A6IPvNlkvbtvYCzgjhtGxDmrj7\nwTRV5gO9j3bAhxBO7XgTmwmD/9hpykM58nbhLFnkGf+Taja8qsy0U8H74Tr9w1M8\n8E5kghgGzBElNquM8AUuDakC1JL4aLO/VDMxe/1BLtmBHLZy3XTzVycjP9ZFPh6h\nT+cWJcVOjQSYY2U75sDnKD2Sg1cmK54HauA6SPh4kAkpmxyLyDZZjPBQe2sLFmmS\naZSE+g16yMR9TVHo3pTpRkxJwDEH0LePwYXA4vUIK3HHS6zgLe0ody8g\n-----END CERTIFICATE-----"
  certificate_name   = "certificate2"
  private_key        = "-----BEGIN RSA PRIVATE KEY-----\nMIIEogIBAAKCAQEAo83kaUQXpCcSoEuRVFX3jztWDNKtWpjNG240f0RpERI1NnZt\nHH0qnZqfaWAQQa8kx3+W1LOeFbkkRnkJz19geIXR6TeavT+W5iRh4goK+N7gubYk\nSMa2shVf+XsoHKERSbhdhrtX+GqvKzAvplCtCgd4MDlsvLv/YHCLvJL4JgRxKyev\njlnE1rqrICJMCLbbZMrIKTzwb/K13hGrm6Bc+Je9EC3MWWxd5jBwXu3vgIYRuGR4\nDPg/yfMKPZr2xFDLpBsv5jaqULS9t6GwoEBJKN0NXp5obaQToYqMsvAZyHoEyfCB\nDka16Bm5hGF60FwqgUT3p/+qlBn61cAJe9t58QIDAQABAoIBADIyHuOPJTt9abzL\nS26vpVw0D6uAR/UyS/Ay9k1ltliv3rSg19DaHlwLjPwqnvCx7jBgTeVCYZhAkvgx\nkSsGDDcCsw+npXiG6wP9dC1jbHdVPUJLqZTPqB6sZCu8bM9RIE4Z/DcUY+HRN3qh\nmoh5wn0HSvJkNokjhx+TfY687uQfDMu0de4V2UPScZ7mboCu9HqK9qu0/krdTMH1\nrtnnFGEnx/Pe38YJl0fWxo8BHKHprwEvWX0MQzQeklnUtxREMuofSAOBe/I2DJGh\n1I94b6I66ypxuX0qAozT1MPbJGuaR+puyKawLNAQmZa9pgrrFK7e8PQUzrGVpVCp\nFtwx420CgYEA0uX/G0ycia0UTdkxkIsKIiLjs12LC0XmYjiWgkoL0PjiZzcPITn6\nvqqqGSz44HwtbrttZPm3Mo79yJ5xFiHCX0vFJykgy6cfS94imMgm8qIOS0bXjX7w\nxH2BOgp0H32LP/Zt7owcWJLEIQCjj0/4+Nvu0GskGVHlE8EYrXWf1E8CgYEAxtWk\nxBo52uNXL712VGDPNxprVGUpWSbkXpE+7wtRso5LnAnAj6dpmZsGe2zaYjRIt3Ls\nGnno4HUmwpQ5yXlHFpDUJvb2soXq3afnuAh5aVu6aKRQoG/5o3cD4pOupNbjDDNs\nTVLtTLIAIYDbph/j7pV/JnJ2WHcdk6WiVJoW/b8CgYAopLZzNmJ8jeR51D+fEYyU\nY5DqQj7Hn2L0zt8CoO6CCVToe03pI1lVYWKCk44rBQNkca51ZUKO9cum3BIDJ+Jj\npyCJmX1+geigIGEefIQ1AlIq464q0Knp1B4RZ25Vm0Y4v28UJ+BWmYI+sfbTaaAb\npZbyh5NfZc717aKp2x9ANQKBgHQpvOkUqVhIGVe6yLbjGCyJMstLjqyXHDRjhvEB\nG+nFWEcBK47Br+Adwdu57JwTD6ida3LMZlE8IDjtgBVE1VNJqahaACasNlrpDWdn\nDAeRn4Yi+TfCM4Zcsdhdj1qecGdgY5WJLTnxhEIOlkSnvPJWRMKhfKKSdKUdz4i9\nvVDhAoGAEHxfhFLVwdTa0RMUq3KYSXa5WqLANRn2e62Cc3eUWekcUjbIATRF5AIo\nm0WS+rURZWy1Fd6fGg8sRHock0+vxwqeP6OlyW4tJMhL33NrNbgyvkXlMMIX6bC4\nUq8aAew0B3j61UUsTqhHMhYwIS3GOIHx/O10wwINPnUMIVER3Wg=\n-----END RSA PRIVATE KEY-----"
  public_certificate = "-----BEGIN CERTIFICATE-----\nMIICljCCAX4CCQCEpaMjTCJ8WzANBgkqhkiG9w0BAQsFADANMQswCQYDVQQGEwJV\nUzAeFw0yMTAxMTkyMTI2MjRaFw0yNDAxMTkyMTI2MjRaMA0xCzAJBgNVBAYTAlVT\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAo83kaUQXpCcSoEuRVFX3\njztWDNKtWpjNG240f0RpERI1NnZtHH0qnZqfaWAQQa8kx3+W1LOeFbkkRnkJz19g\neIXR6TeavT+W5iRh4goK+N7gubYkSMa2shVf+XsoHKERSbhdhrtX+GqvKzAvplCt\nCgd4MDlsvLv/YHCLvJL4JgRxKyevjlnE1rqrICJMCLbbZMrIKTzwb/K13hGrm6Bc\n+Je9EC3MWWxd5jBwXu3vgIYRuGR4DPg/yfMKPZr2xFDLpBsv5jaqULS9t6GwoEBJ\nKN0NXp5obaQToYqMsvAZyHoEyfCBDka16Bm5hGF60FwqgUT3p/+qlBn61cAJe9t5\n8QIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQAX1rxV2hai02Pb4Cf8U44zj+1aY6wV\nLvOMWiL3zl53up4/X7PDcmWcPM9UMVCGTISZD6A6IPvNlkvbtvYCzgjhtGxDmrj7\nwTRV5gO9j3bAhxBO7XgTmwmD/9hpykM58nbhLFnkGf+Taja8qsy0U8H74Tr9w1M8\n8E5kghgGzBElNquM8AUuDakC1JL4aLO/VDMxe/1BLtmBHLZy3XTzVycjP9ZFPh6h\nT+cWJcVOjQSYY2U75sDnKD2Sg1cmK54HauA6SPh4kAkpmxyLyDZZjPBQe2sLFmmS\naZSE+g16yMR9TVHo3pTpRkxJwDEH0LePwYXA4vUIK3HHS6zgLe0ody8g\n-----END CERTIFICATE-----"

  lifecycle {
    create_before_destroy = true
  }
}

resource "oci_load_balancer_path_route_set" "test_path_route_set" {
  #Required
  load_balancer_id = oci_load_balancer.lb1.id
  name             = "pr-set1"

  path_routes {
    #Required
    backend_set_name = oci_load_balancer_backend_set.lb-bes1.name
    path             = "/example/video/123"

    path_match_type {
      #Required
      match_type = "EXACT_MATCH"
    }
  }
}

resource "oci_load_balancer_hostname" "test_hostname1" {
  #Required
  hostname         = "app.example.com"
  load_balancer_id = oci_load_balancer.lb1.id
  name             = "hostname1"
}

resource "oci_load_balancer_hostname" "test_hostname2" {
  #Required
  hostname         = "app2.example.com"
  load_balancer_id = oci_load_balancer.lb1.id
  name             = "hostname2"
}

resource "oci_load_balancer_listener" "lb-listener1" {
  load_balancer_id         = oci_load_balancer.lb1.id
  name                     = "http"
  default_backend_set_name = oci_load_balancer_backend_set.lb-bes1.name
  hostname_names           = [oci_load_balancer_hostname.test_hostname1.name, oci_load_balancer_hostname.test_hostname2.name]
  port                     = 80
  protocol                 = "HTTP"
  rule_set_names           = [oci_load_balancer_rule_set.test_rule_set.name]

  connection_configuration {
    idle_timeout_in_seconds = "2"
  }
}

resource "oci_load_balancer_listener" "lb-listener2" {
  load_balancer_id         = oci_load_balancer.lb1.id
  name                     = "https"
  default_backend_set_name = oci_load_balancer_backend_set.lb-bes1.name
  port                     = 443
  protocol                 = "HTTP"

  ssl_configuration {
    certificate_name        = oci_load_balancer_certificate.lb-cert1.certificate_name
    verify_peer_certificate = false
    protocols               = ["TLSv1.1", "TLSv1.2"]
    server_order_preference = "ENABLED"
    cipher_suite_name       = oci_load_balancer_ssl_cipher_suite.test_ssl_cipher_suite.name
  }
}

resource "oci_load_balancer_listener" "lb-listener3" {
  load_balancer_id         = oci_load_balancer.lb2.id
  name                     = "tcp"
  default_backend_set_name = oci_load_balancer_backend_set.lb-bes2.name
  port                     = 80
  protocol                 = "TCP"

  connection_configuration {
    idle_timeout_in_seconds            = "2"
    backend_tcp_proxy_protocol_version = "1"
  }
}

resource "oci_load_balancer_backend" "lb-be1" {
  load_balancer_id = oci_load_balancer.lb1.id
  backendset_name  = oci_load_balancer_backend_set.lb-bes1.name
  ip_address       = oci_core_instance.instance1.private_ip
  port             = 80
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}

resource "oci_load_balancer_backend" "lb-be2" {
  load_balancer_id = oci_load_balancer.lb1.id
  backendset_name  = oci_load_balancer_backend_set.lb-bes1.name
  ip_address       = oci_core_instance.instance2.private_ip
  port             = 80
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}

resource "oci_load_balancer_rule_set" "test_rule_set" {
  items {
    action = "ADD_HTTP_REQUEST_HEADER"
    header = "example_header_name"
    value  = "example_header_value"
  }

  items {
    action          = "CONTROL_ACCESS_USING_HTTP_METHODS"
    allowed_methods = ["GET", "POST"]
    status_code     = "405"
  }

  items {
    action      = "ALLOW"
    description = "example vcn ACL"

    conditions {
      attribute_name  = "SOURCE_VCN_ID"
      attribute_value = oci_core_vcn.vcn1.id
    }

    conditions {
      attribute_name  = "SOURCE_VCN_IP_ADDRESS"
      attribute_value = "10.10.1.0/24"
    }
  }

  items {
    action = "REDIRECT"

    conditions {
      attribute_name  = "PATH"
      attribute_value = "/example"
      operator        = "FORCE_LONGEST_PREFIX_MATCH"
    }

    redirect_uri {
      protocol = "{protocol}"
      host     = "in{host}"
      port     = 8081
      path     = "{path}/video"
      query    = "?lang=en"
    }

    response_code = 302
  }

  items {
    action                         = "HTTP_HEADER"
    are_invalid_characters_allowed = true
    http_large_header_size_in_kb   = 8
  }

  load_balancer_id = oci_load_balancer.lb1.id
  name             = "example_rule_set_name"
}

output "lb_public_ip" {
  value = [oci_load_balancer.lb1.ip_address_details]
}

resource "oci_load_balancer_ssl_cipher_suite" "test_ssl_cipher_suite" {
  #Required
  name = "test_cipher_name"

  ciphers = ["AES128-SHA", "AES256-SHA"]

  #Optional
  load_balancer_id = oci_load_balancer.lb1.id
}

resource "oci_load_balancer_ssl_cipher_suite" "test_ssl_cipher_suite2" {
  #Required
  name = "test_cipher_name"

  ciphers = ["AES128-SHA", "AES256-SHA"]

  #Optional
  load_balancer_id = oci_load_balancer.lb2.id
}

data "oci_load_balancer_ssl_cipher_suites" "test_ssl_cipher_suites" {
  #Optional
  load_balancer_id = oci_load_balancer.lb1.id
}

data "oci_load_balancer_ssl_cipher_suites" "test_ssl_cipher_suites2" {
  #Optional
  load_balancer_id = oci_load_balancer.lb2.id
}
