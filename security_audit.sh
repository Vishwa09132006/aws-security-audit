#!/bin/bash

# ─── AWS Cloud Security Audit Script ─────────────────────
# Checks your AWS account for common security misconfigurations
# Works on any AWS account — no hardcoded values
# ──────────────────────────────────────────────────────────

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Log file
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
LOG_DIR=~/projects/aws-security-audit/logs
LOG_FILE="$LOG_DIR/security_audit_$TIMESTAMP.log"
mkdir -p $LOG_DIR

# Account info
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)
CALLER=$(aws sts get-caller-identity --query Arn --output text)

# Score tracking
PASS=0
FAIL=0

# ── Helper functions ──
pass() {
  echo -e "${GREEN}  [PASS]${NC} $1"
  echo "[PASS] $1" >> $LOG_FILE
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}  [FAIL]${NC} $1"
  echo "[FAIL] $1" >> $LOG_FILE
  echo "  → Fix: $2" >> $LOG_FILE
  FAIL=$((FAIL + 1))
}

warn() {
  echo -e "${YELLOW}  [WARN]${NC} $1"
  echo "[WARN] $1" >> $LOG_FILE
  echo "  → Note: $2" >> $LOG_FILE
}

info() {
  echo -e "${BLUE}  [INFO]${NC} $1"
  echo "[INFO] $1" >> $LOG_FILE
}

# ── Header ──
echo "======================================================="
echo "         AWS Cloud Security Audit"
echo "         $(date)"
echo "======================================================="
echo ""

# ── Account info header in log ──
{
echo "======================================================="
echo " AWS Cloud Security Audit Report"
echo " Date:       $(date)"
echo " Account ID: $ACCOUNT_ID"
echo " Region:     $REGION"
echo " Run by:     $CALLER"
echo "======================================================="
echo ""
} >> $LOG_FILE

# ──────────────────────────────────────────────────────────
# CHECK 1 — Root account access keys
# ──────────────────────────────────────────────────────────
echo -e "${BLUE}[CHECK 1]${NC} Root Account Access Keys"

root_keys=$(aws iam get-account-summary --query "SummaryMap.AccountAccessKeysPresent" --output text)

if [ "$root_keys" -eq 0 ]; then
  pass "Root account has no active access keys"
else
  fail "Root account has active access keys" \
       "AWS Console → IAM → Security Credentials → Delete root access keys immediately"
fi
echo ""

# ──────────────────────────────────────────────────────────
# CHECK 2 — S3 bucket public access
# ──────────────────────────────────────────────────────────
echo -e "${BLUE}[CHECK 2]${NC} S3 Bucket Public Access"

buckets=$(aws s3api list-buckets --query "Buckets[*].Name" --output text)

if [ -z "$buckets" ]; then
  info "No S3 buckets found in this account"
else
  for bucket in $buckets; do
    block=$(aws s3api get-public-access-block --bucket $bucket 2>/dev/null)
    if [ $? -ne 0 ]; then
      fail "$bucket — No public access block configured" \
           "AWS Console → S3 → $bucket → Permissions → Block Public Access → Enable all"
    else
      restrict=$(echo $block | python3 -c "import sys,json; d=json.load(sys.stdin)['PublicAccessBlockConfiguration']; print('true' if all(d.values()) else 'false')")
      if [ "$restrict" == "true" ]; then
        pass "$bucket — Fully private"
      else
        warn "$bucket — Public access enabled" \
             "Intentional if hosting a static website. If not, enable Block Public Access in S3 console."
        FAIL=$((FAIL + 1))
      fi
    fi
  done
fi
echo ""

# ──────────────────────────────────────────────────────────
# CHECK 3 — Security groups open to internet
# ──────────────────────────────────────────────────────────
echo -e "${BLUE}[CHECK 3]${NC} Security Groups Open to Internet (0.0.0.0/0)"

open_groups=$(aws ec2 describe-security-groups \
  --query "SecurityGroups[?IpPermissions[?IpRanges[?CidrIp=='0.0.0.0/0']]].GroupName" \
  --output text)

if [ -z "$open_groups" ]; then
  pass "No security groups with unrestricted inbound access found"
else
  for group in $open_groups; do
    fail "Security group '$group' allows unrestricted inbound traffic" \
         "AWS Console → EC2 → Security Groups → $group → Edit inbound rules → restrict source IPs"
  done
fi
echo ""

# ──────────────────────────────────────────────────────────
# CHECK 4 — IAM users without MFA
# ──────────────────────────────────────────────────────────
echo -e "${BLUE}[CHECK 4]${NC} IAM Users Without MFA"

users=$(aws iam list-users --query "Users[*].UserName" --output text)

if [ -z "$users" ]; then
  info "No IAM users found"
else
  for user in $users; do
    mfa=$(aws iam list-mfa-devices --user-name $user \
      --query "MFADevices[*].SerialNumber" --output text)
    if [ -z "$mfa" ]; then
      fail "$user — MFA not enabled" \
           "AWS Console → IAM → Users → $user → Security Credentials → Assign MFA device"
    else
      pass "$user — MFA enabled"
    fi
  done
fi
echo ""

# ──────────────────────────────────────────────────────────
# CHECK 5 — CloudTrail enabled
# ──────────────────────────────────────────────────────────
echo -e "${BLUE}[CHECK 5]${NC} CloudTrail Logging"

trails=$(aws cloudtrail describe-trails --query "trailList[*].Name" --output text)

if [ -z "$trails" ]; then
  fail "No CloudTrail trails found — API activity is not being logged" \
       "Run: aws cloudtrail create-trail --name my-trail --s3-bucket-name YOUR_BUCKET && aws cloudtrail start-logging --name my-trail"
else
  pass "CloudTrail is enabled: $trails"
fi
echo ""

# ──────────────────────────────────────────────────────────
# CHECK 6 — IAM password policy
# ──────────────────────────────────────────────────────────
echo -e "${BLUE}[CHECK 6]${NC} IAM Password Policy"

aws iam get-account-password-policy &>/dev/null

if [ $? -ne 0 ]; then
  fail "No custom password policy configured" \
       "Run: aws iam update-account-password-policy --minimum-password-length 12 --require-symbols --require-numbers --require-uppercase-characters --require-lowercase-characters --max-password-age 90"
else
  pass "Custom IAM password policy is configured"
fi
echo ""

# ──────────────────────────────────────────────────────────
# SUMMARY
# ──────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))

echo "======================================================="
echo " Security Audit Complete"
echo " $(date)"
echo "======================================================="
echo ""

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN} Score: $PASS/$TOTAL checks passed — Excellent!${NC}"
else
  echo -e "${RED} Score: $PASS/$TOTAL checks passed${NC}"
  echo -e "${YELLOW} $FAIL issue(s) need attention — see log for remediation steps${NC}"
fi

echo ""
echo " Full report saved to: $LOG_FILE"
echo "Run this to see full report: cat ~/bash_scripts/logs/security_audit_*.log | tail -50"
echo "======================================================="

# Save summary to log
{
echo ""
echo "======================================================="
echo " Score: $PASS/$TOTAL checks passed"
echo " $FAIL issue(s) need attention"
echo "======================================================="
} >> $LOG_FILE

# ── Upload report to S3 ──
echo ""
echo "Uploading report to S3..."
aws s3 cp $LOG_FILE s3://$(aws s3api list-buckets --query "Buckets[?contains(Name, 'backups')].Name" --output text)/security-audits/

if [ $? -eq 0 ]; then
  echo -e "${GREEN}  [PASS]${NC} Report uploaded to S3"
else
  echo -e "${YELLOW}  [WARN]${NC} S3 upload failed — report saved locally only"
fi

# ── Clean up old local logs ──
find $LOG_DIR -name "security_audit_*.log" -mtime +7 -delete
echo -e "${GREEN}  [INFO]${NC} Cleaned up local audit logs older than 7 days"