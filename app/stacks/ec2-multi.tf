provider "aws" {
  region = local.region
}
data "aws_availability_zones" "available" {}


locals {

  region                  = "ap-northeast-2"
  key_name                = "hjcho-keypare"
  ec2_name                = "ljlcc-app"

  #  AWS Console -> EC2 -> IMAGES -> AMIs -> AMI Name -> 20180618_ljlcc-app -> Launch 클릭
  ami                     = "ami-0ff0170ffe85deb25"

  #  Subnet -> 선택 (홀수 a, 짝수 c)
  private_subnet1_id      = "subnet-02dfbb7e65b661c52"

  #  Assign a security group -> Select an existing security group ->  sg-e5c77b8eSG_PRD_LCCAPP_EC2 선택
  vpc_security_group_ids  = ["sg-060aefd96abe8f816"]

  # Primary IP -> 10.31.30.13 입력 -> Next:Add Storage -> Next: Add Tags 클릭
  # private_ip              = ["10.0.140.128","10.0.140.129"]
  private_ips = {
    "00" = "10.0.140.126"
    "01" = "10.0.140.127"
  }

  # IAM role -> EC2_Service 선택
  iam_instance_profile    = "AdministratorAccess"

  #  Instance Type -> m5.xlarge 선택 -> Next: Configure Instance Details 선택
  instance_type           = "t3.medium"
}


module "ec2_instance_multi" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  for_each = toset(["00", "01"])
  # ex jeus_instance_02, jeus_instance_03
  name = "${local.ec2_name}${each.key}"
  key_name               = "hjcho-keypare"
  monitoring             = false

  ami                    = local.ami
  vpc_security_group_ids = local.vpc_security_group_ids
  subnet_id              = local.private_subnet1_id
  instance_type          = local.instance_type

  iam_instance_profile   = local.iam_instance_profile

  private_ip             = local.private_ips[each.key]

  user_data            = <<-EOT
      #!/bin/bash -xe
      exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

      # ec2 userdata는 모든 명령어가 Root권한으로 실행되므로 일반권한으로 실행해야 할 명령어는 별도의 조치 필요

      # 기동되기 전에 해야해서 가장 상단에 위치해야함
      # 호스트네임 변경
      hostnamectl set-hostname ${local.ec2_name}${each.key}

      # NW 서비스종료
      systemctl stop firewalld.service && systemctl disable firewalld.service
      systemctl stop NetworkManager.service && systemctl disable NetworkManager.service

      cd /home/ec2-user

      # PoleStar


      # JEUS 라이센스 업로드


      # 로그삭제
      rm -rf /data/jeus/logs/*/servlet/*.log*

      # /etc/hosts 등록
      echo "10.31.30.11 ljlcc-app1" >> /etc/hosts


      # MS 추가
      ## /data/jeus/nodemanager/jeusnm.xml 내 host정보 수정 후 wq!



      ## nmboot / 명령어 바뀔순 있으나 일반권한으로 실행해야 함
      sudo -u ec2-user bash -c "nohup /home/ec2-user/jeus8_5/bin/startNodeManager > node.log &"

      ## 어드민서버 정보 스크립트로 적용
      ### 어드민 콘솔
      ### NODE 생성
      ### 서버 생성
      ### 리스너 추가
      ### webtob 연결
      ### 클러스터에 추가
      ### 서버 시작
      sudo -u ec2-user bash -c '/home/ec2-user/jeus8_5/bin/jeusadmin -host 10.0.131.66:9736 -u administrator -p jeusadmin <<!
      add-java-node Node${local.ec2_name}${each.key} -host ${local.private_ips[each.key]} -port 7730
      add-server ${local.ec2_name}${each.key} -addr ${local.private_ips[each.key]} -baseport 9936 -node Node${local.ec2_name}${each.key} -jvm "-Xms1024m -Xmx1024m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=512m"
      add-listener -name http-${local.ec2_name}${each.key} -server ${local.ec2_name}${each.key} -addr ${local.private_ips[each.key]} -port 8088
      add-listener -name jms-internal3 -server ${local.ec2_name}${each.key} -addr ${local.private_ips[each.key]} -port 9741
      add-web-listener -name http1 -tmin 10 -tmax 20 -server ${local.ec2_name}${each.key} -http -slref http-${local.ec2_name}${each.key}
      add-webtob-connector -name HOM -server ${local.ec2_name}${each.key} -num 5 -regid HOM -port 9900 -addr 10.0.142.216
      add-servers-to-cluster clusterDemo -servers ${local.ec2_name}${each.key}
      serverinfo
      startserver ${local.ec2_name}${each.key}
      quit
      !'





      # 소스 파일 삭제
      rm -rf /data/jeus/domains/lcc_domain/.downloaded/.applications/hom
      rm -rf /data/jeus/domains/lcc_domain/servers/serverHOM*/.workspace/deployed/hom/hom_war___




  EOT
  user_data_replace_on_change = false

#  Add Tag -> Key : Value -> Name : ljlcc-app3 -> Class : LCC -> Env : TMP 입력
  tags = {
    Name = "${local.ec2_name}${each.key}"
    Class = "LCC"
    Env = "TMP"
  }
}
