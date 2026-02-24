## CloudFormation for Anypoint VPC Networking
> AWS CloudFormation templates for VPC, Private Space networking, and VPN tunnels

### When to Use
- Your organization standardizes on AWS CloudFormation for infrastructure
- You need to provision AWS VPCs that peer with Anypoint CloudHub VPCs
- You want automated VPN tunnel setup for hybrid connectivity

### Configuration

**anypoint-vpc-network.yaml**
```yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: "AWS VPC and networking for Anypoint Platform integration"

Parameters:
  Environment:
    Type: String
    AllowedValues: [dev, qa, prod]
    Description: Target environment

  AnypointVpcCidr:
    Type: String
    Default: "10.0.0.0/24"
    Description: CIDR block of the Anypoint CloudHub VPC

  AwsVpcCidr:
    Type: String
    Default: "10.1.0.0/16"
    Description: CIDR block for the AWS VPC

  OnPremCidr:
    Type: String
    Default: "172.16.0.0/12"
    Description: On-premises network CIDR

  CustomerGatewayIp:
    Type: String
    Description: Public IP of on-premises VPN device

Resources:
  # VPC
  MuleVpc:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref AwsVpcCidr
      EnableDnsSupport: true
      EnableDnsHostnames: true
      Tags:
        - Key: Name
          Value: !Sub "mulesoft-${Environment}-vpc"

  # Subnets (private, across 3 AZs)
  PrivateSubnetA:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref MuleVpc
      CidrBlock: !Select [0, !Cidr [!Ref AwsVpcCidr, 6, 8]]
      AvailabilityZone: !Select [0, !GetAZs ""]
      MapPublicIpOnLaunch: false
      Tags:
        - Key: Name
          Value: !Sub "mulesoft-${Environment}-private-a"

  PrivateSubnetB:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref MuleVpc
      CidrBlock: !Select [1, !Cidr [!Ref AwsVpcCidr, 6, 8]]
      AvailabilityZone: !Select [1, !GetAZs ""]
      MapPublicIpOnLaunch: false
      Tags:
        - Key: Name
          Value: !Sub "mulesoft-${Environment}-private-b"

  PrivateSubnetC:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref MuleVpc
      CidrBlock: !Select [2, !Cidr [!Ref AwsVpcCidr, 6, 8]]
      AvailabilityZone: !Select [2, !GetAZs ""]
      MapPublicIpOnLaunch: false
      Tags:
        - Key: Name
          Value: !Sub "mulesoft-${Environment}-private-c"

  # VPN Gateway for on-premises connectivity
  VpnGateway:
    Type: AWS::EC2::VPNGateway
    Properties:
      Type: ipsec.1
      Tags:
        - Key: Name
          Value: !Sub "mulesoft-${Environment}-vgw"

  VpnGatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref MuleVpc
      VpnGatewayId: !Ref VpnGateway

  CustomerGateway:
    Type: AWS::EC2::CustomerGateway
    Properties:
      Type: ipsec.1
      BgpAsn: 65000
      IpAddress: !Ref CustomerGatewayIp
      Tags:
        - Key: Name
          Value: !Sub "mulesoft-${Environment}-cgw"

  VpnConnection:
    Type: AWS::EC2::VPNConnection
    Properties:
      Type: ipsec.1
      CustomerGatewayId: !Ref CustomerGateway
      VpnGatewayId: !Ref VpnGateway
      StaticRoutesOnly: true
      Tags:
        - Key: Name
          Value: !Sub "mulesoft-${Environment}-vpn"

  VpnRoute:
    Type: AWS::EC2::VPNConnectionRoute
    Properties:
      VpnConnectionId: !Ref VpnConnection
      DestinationCidrBlock: !Ref OnPremCidr

  # Route table for private subnets
  PrivateRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref MuleVpc
      Tags:
        - Key: Name
          Value: !Sub "mulesoft-${Environment}-private-rt"

  VpnRoute2:
    Type: AWS::EC2::Route
    DependsOn: VpnGatewayAttachment
    Properties:
      RouteTableId: !Ref PrivateRouteTable
      DestinationCidrBlock: !Ref OnPremCidr
      GatewayId: !Ref VpnGateway

  SubnetARouteAssoc:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateSubnetA
      RouteTableId: !Ref PrivateRouteTable

  SubnetBRouteAssoc:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateSubnetB
      RouteTableId: !Ref PrivateRouteTable

  SubnetCRouteAssoc:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateSubnetC
      RouteTableId: !Ref PrivateRouteTable

  # Security Group for Mule apps
  MuleSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: "Security group for Mule application traffic"
      VpcId: !Ref MuleVpc
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 8081
          ToPort: 8082
          CidrIp: !Ref AnypointVpcCidr
          Description: "Anypoint VPC inbound"
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: !Ref OnPremCidr
          Description: "On-prem HTTPS"
      SecurityGroupEgress:
        - IpProtocol: -1
          CidrIp: 0.0.0.0/0
          Description: "Allow all outbound"
      Tags:
        - Key: Name
          Value: !Sub "mulesoft-${Environment}-sg"

Outputs:
  VpcId:
    Value: !Ref MuleVpc
    Export:
      Name: !Sub "mulesoft-${Environment}-vpc-id"

  PrivateSubnetIds:
    Value: !Join
      - ","
      - - !Ref PrivateSubnetA
        - !Ref PrivateSubnetB
        - !Ref PrivateSubnetC
    Export:
      Name: !Sub "mulesoft-${Environment}-private-subnets"

  SecurityGroupId:
    Value: !Ref MuleSecurityGroup
    Export:
      Name: !Sub "mulesoft-${Environment}-sg-id"

  VpnConnectionId:
    Value: !Ref VpnConnection
```

**Deploy command**
```bash
aws cloudformation deploy \
    --template-file anypoint-vpc-network.yaml \
    --stack-name mulesoft-prod-network \
    --parameter-overrides \
        Environment=prod \
        CustomerGatewayIp=203.0.113.50 \
    --capabilities CAPABILITY_IAM \
    --tags Project=MuleSoft Environment=prod
```

### How It Works
1. Creates a VPC with private subnets across 3 availability zones for high availability
2. Sets up a site-to-site VPN connection to the on-premises data center
3. Route tables direct on-premises traffic through the VPN gateway
4. Security groups restrict inbound traffic to Anypoint VPC and on-premises CIDRs only
5. Outputs are exported for cross-stack references (other stacks can reference the VPC ID)

### Gotchas
- VPC peering between AWS VPC and Anypoint VPC must be initiated from Anypoint Runtime Manager
- CIDR blocks must not overlap between your AWS VPC, Anypoint VPC, and on-premises network
- VPN tunnels have a 1.25 Gbps bandwidth limit per tunnel; use two tunnels for HA
- CloudFormation stack updates to VPN resources can briefly disrupt connectivity
- Private Space (CH2) uses different networking than CloudHub 1.0 VPCs

### Related
- [terraform-anypoint](../terraform-anypoint/) — Terraform alternative for IaC
- [k8s-flex-gateway](../k8s-flex-gateway/) — Flex Gateway for API ingress
- [secure-properties](../../environments/secure-properties/) — Secure VPN credentials
