provider "aws" {
  profile = "mysid"
  region     = "ap-south-1"

}

resource "aws_security_group" "http_ssh" {
  name        = "http_ssh"
  description = "Allow http"
  

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"    
    cidr_blocks = ["0.0.0.0/0"]
  }

 

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "http_ssh"
  }
}

resource "aws_instance" "new_instance" {
 	ami = "ami-0447a12f28fddb066"
 	instance_type = "t2.micro"
	availability_zone="ap-south-1b"
 	key_name = "mykey1111"
 	security_groups =  ["${aws_security_group.http_ssh.name}"] 
	
 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/siddh/OneDrive/Desktop/hybrid_cloud/mykey1111.pem")
    host     = aws_instance.new_instance.public_ip
}

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd"
    ]
  }



 tags = { 
     Name = "sidos"
  } 
}

resource "aws_ebs_volume" "ext-vol" {
 availability_zone = aws_instance.new_instance.availability_zone
 size = 1
 tags = {
        Name = "ext-vol"
 }

}

resource "aws_volume_attachment" "att-vol" {
 device_name = "/dev/sdh"
 volume_id = aws_ebs_volume.ext-vol.id
 instance_id = aws_instance.new_instance.id
 force_detach = true
}

resource "null_resource" "nullremote"  {

depends_on = [
    aws_volume_attachment.att-vol,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/siddh/OneDrive/Desktop/hybrid_cloud/mykey1111.pem")
    host     = aws_instance.new_instance.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Siddharth1700/hybrid.git /var/www/html"
    ]
  }
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket = "sidimage"
  acl    = "public-read"


  tags = {
    Name = "my_bucket"
  }

versioning{
	enabled =true
}
}

resource "aws_s3_bucket_object" "upload_image" {
  
depends_on = [
    aws_s3_bucket.s3_bucket,
  ]

  bucket = "sidimage"
  key    = "sid.jpg"
  source = "C:/Users/siddh/OneDrive/Desktop/hybrid_cloud/sid.jpg"
  acl    = "public-read"
}

resource "aws_cloudfront_distribution" "cloud_front" {
  origin {
    domain_name = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
    origin_id   = "s3_bucketid"
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3_bucketid"


    forwarded_values {
      query_string = true


      cookies {
        forward = "none"
      }
    }


    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  }
}


