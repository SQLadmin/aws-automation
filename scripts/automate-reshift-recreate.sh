#!/bin/bash
# ----------------------------------------------------------
# RECREATE REDSHIFT CLUSTERS FROM RUNNING CLUSTER'S SNAPSHOT
# ----------------------------------------------------------

# Version: 1.0
# Created by: @SQLadmin
# Blog URL: https://www.sqlgossip.com/automate-aws-redshift-snapshot-and-restore/

# Create IAM user with keys assign Redshift nessessary access 
# and SES send raw email access

# READ CAREFULLY
# --------------
# Change the below things:
# AWS CLI must be installed
# YOUR_ACCESS_KEY
# YOUR_SECRET_KEY
# prod-cluster -> Prod/Main cluster name
# dev-cluster -> New Test/DEV cluster name
# REDSHIFT-REGION -> Region where your cluster located
# ses-region -> Region for your SES
# from@domain.com -> From Address for SES (this should be verified one)
# to@domain.com,to2@domain.com -> Who all are needs to get the email notification
# default.redshift-1.0 -> If you are using custom parameter group then replace this with that name.
# "sg-id1" "sg-id2" -> Security group ids that you want to attach it to Redshift Cluster.


#function for kill the process once its failed
die() { echo >&2 "$0 Err: $@" ; exit 1 ;}

#Export Access Keys
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"

#Input Parameters
#For Cluster Refresh
Snapdate=`date +%Y-%m-%d-%H-%M-%S`
SourceRedshift='prod-cluster'
DestRedshift='dev-cluster'
Region='REDSHIFT-REGION'


#Delete Cluster
echo "Delete Cluster ... Please wait" 

aws redshift  delete-cluster \
--region $Region  \
--cluster-identifier  $DestRedshift \
--skip-final-cluster-snapshot || die | aws ses send-email \
  --region ses-region \
  --from "from@domain.com" \
  --destination "to@domain.com,to2@domain.com" \
  --message "Subject={Data=RedShift Refresh  Failed,Charset=utf8},Body={Text={Data=Refreshing the redshift cluster is failed. 
  Step: Delete Cluster,Charset=utf8}}"

sleep 5m
echo "Cluster Deleted !!!"

#Take snapshot
echo "Taking Snapshot ... Please wait" 

aws redshift create-cluster-snapshot \
--region $Region  \
--cluster-identifier $SourceRedshift  \
--snapshot-identifier $SourceRedshift-refresh-snap-$Snapdate || die | aws ses send-email \
  --region ses-region \
  --from "from@domain.com" \
  --destination "to@domain.com,to2@domain.com" \
  --message "Subject={Data=RedShift Refresh  Failed,Charset=utf8},Body={Text={Data=Refreshing the redshift cluster is failed. 
  Step: Take snapshot,Charset=utf8}}"

sleep 15m
echo "Snapshot Created !!!"

#Restore snapshot
echo "Restoring Snapshot... Please wait!"

aws redshift restore-from-cluster-snapshot \
--region $Region \
--cluster-identifier $DestRedshift  \
--snapshot-identifier $SourceRedshift-refresh-snap-$Snapdate \
--cluster-subnet-group-name reshiftsubnet \
--cluster-parameter-group-name default.redshift-1.0 \
--vpc-security-group-ids  "sg-id1" "sg-id2" || die | aws ses send-email \
  --region ses-region \
  --from "from@domain.com" \
  --destination "to@domain.com,to2@domain.com" \
  --message "Subject={Data=RedShift Refresh  Failed,Charset=utf8},Body={Text={Data=Refreshing the redshift cluster is failed. 
  Step: Restore snapshot,Charset=utf8}}"

sleep 60m
echo "Snapshot Restored !!!"

#Delete old snapshot
echo "Old Snapshot Deleteing!!!"

Deldate=prod-cluster-refresh-snap-`date -d "1 days ago" +%Y-%m-%d`
Delsnap=$(aws redshift describe-cluster-snapshots --region ses-region --query 'Snapshots[].SnapshotIdentifier' --output json | grep $Deldate |   sed -n '2p' |  sed 's|[",,]||g')
aws redshift delete-cluster-snapshot \
--region $Region \
--snapshot-identifier $Delsnap  || die | aws ses send-email \
  --region ses-region \
  --from "from@domain.com" \
  --destination "to@domain.com,to2@domain.com" \
  --message "Subject={Data=RedShift Refresh  Failed,Charset=utf8},Body={Text={Data=Refreshing the redshift cluster is failed. 
  Step: Delete Old snapshot,Charset=utf8}}"
