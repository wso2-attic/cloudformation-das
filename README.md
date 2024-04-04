# NOTE
## WSO2 Data Analytics Server is deprecated and moved to the attic. Similarly, AWS Cloud Formation templates for DAS is deprecated and moved to the attic. 

# AWS CloudFormation Templates for WSO2 Data Analytics Server Deployments

This repository contains AWS CloudFormation templates for WSO2 Data Analytics Server.

## Setup instructions

1. Clone the repository
  ```
  $ git clone https://github.com/wso2/cloudformation-das.git
  ```
2. Go to [AWS console](https://console.aws.amazon.com/ec2/v2/home#KeyPairs:sort=keyName) and create a key value pair. This will be used to ssh to the nodes.
3. Add a self signed certificate for AWS ACM as explained [here](https://medium.com/@chamilad/adding-a-self-signed-ssl-certificate-to-aws-acm-88a123a04301). Copy the ARN value of the created certificate. This certificate will be used for the ALB fronting WSO2 Data Analytics Server.
4. Go to [AWS CloudFormer console](https://console.aws.amazon.com/cloudformation/home).
5. Select Create Stack option and select choose a template option.
6. Browse and select the cloudformation template under cloudformation-templates directory for the deployment pattern 
preferred and proceed with the deployment. Supported deployment pattern and solution are as below.
   1. Pattern2: WSO2 Data Analytics Server Minimum HA deployment with external RDS
   2. Solution-Analytics-APIM: APIM Analytics 2.1.0 Minimum HA Cluster with APIM 2.1.0 all in one single node as data publisher.
7. Follow the on screen instructions, and provide the ARN of the certificate uploaded in step 3, SSH key, and other 
requested information and proceed.  
 
