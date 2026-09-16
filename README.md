# AWS Cloud Security Audit

An automated cloud security monitoring tool that scans your AWS account for common misconfigurations, generates a detailed report, and sends real-time email alerts when issues are found — running entirely on autopilot via GitHub Actions.

**Live demo:** check the [Actions tab](https://github.com/Vishwa09132006/aws-security-audit/actions) to see the latest audit run and download the report.

* * *

## What it does

Every day at 9am UTC this tool automatically audits your AWS environment across 6 security checks, uploads a timestamped report to S3, and emails you instantly if anything needs attention.

```
Scheduled trigger (daily 9am) or push to main
              ↓
      GitHub Actions runner
              ↓
    6 security checks fire against your AWS account
              ↓
    Color coded report generated with remediation steps
              ↓
    Report uploaded to S3 (permanent record)
              ↓
    Email alert sent via SNS if any failures found
              ↓
    Report saved as GitHub artifact (30 days)
```

* * *

## Security checks

| # | Check | What it looks for |
| --- | --- | --- |
| 1 | Root account access keys | Active keys on the root account — highest severity risk |
| 2 | S3 bucket public access | Buckets with public access enabled unexpectedly |
| 3 | Security groups | Inbound rules open to `0.0.0.0/0` (entire internet) |
| 4 | IAM MFA | Users without Multi-Factor Authentication enabled |
| 5 | CloudTrail logging | Whether API activity is being logged across the account |
| 6 | Password policy | Whether a custom IAM password policy is enforced |

* * *

## Sample output

```
=======================================================
         AWS Cloud Security Audit
         Sat Sep 12 14:22:26 EDT 2026
=======================================================

[CHECK 1] Root Account Access Keys
  ✅ [PASS] Root account has no active access keys

[CHECK 2] S3 Bucket Public Access
  ✅ [PASS] vp-cloud-backups-2026 — Fully private
  ⚠️  [WARN] vp-cloud-portfolio-2026 — Public access enabled (static website)

[CHECK 3] Security Groups Open to Internet
  ✅ [PASS] No security groups with unrestricted inbound access found

[CHECK 4] IAM Users Without MFA
  ❌ [FAIL] vp-cli-user — MFA not enabled
     → Fix: AWS Console → IAM → Users → Security Credentials → Assign MFA device

[CHECK 5] CloudTrail Logging
  ❌ [FAIL] No CloudTrail trails found — API activity is not being logged
     → Fix: aws cloudtrail create-trail --name my-trail --s3-bucket-name YOUR_BUCKET

[CHECK 6] IAM Password Policy
  ❌ [FAIL] No custom password policy configured
     → Fix: aws iam update-account-password-policy --minimum-password-length 12 ...

=======================================================
 Score: 3/7 checks passed
 4 issue(s) need attention — see log for remediation steps
=======================================================
```

* * *

## Features

**Automated scheduling** — runs every day at 9am UTC without any manual intervention. Also triggers on every push to main and can be run manually from the GitHub Actions tab.

**Real-time alerts** — AWS SNS sends an email the moment a failure is detected, including the score and a direct link to the full report in S3.

**Detailed remediation** — every FAIL includes the exact fix, whether that's a console path or a CLI command to run. No Googling required.

**Permanent audit history** — every report is uploaded to S3 with a timestamp so you can track your security posture over time and see whether issues are being resolved.

**Universal** — works on any AWS account. No hardcoded values — the script discovers your buckets, users, and security groups dynamically.

**Auto cleanup** — local log files older than 7 days are deleted automatically to prevent disk bloat.

* * *

## AWS services used

-   **IAM** — reads users, MFA devices, password policy, root account summary
-   **S3** — checks public access settings, stores audit reports
-   **EC2** — scans security group inbound rules
-   **CloudTrail** — checks if API logging is enabled
-   **SNS** — sends email alerts on failure
-   **GitHub Actions** — schedules and runs the audit automatically

* * *

## Running it yourself

**Prerequisites:**

-   AWS CLI configured with an IAM user that has `SecurityAudit` + `AmazonSNSFullAccess` permissions
-   Python3 installed
-   An SNS topic with your email subscribed and confirmed

**Clone and run:**

```bash
git clone https://github.com/Vishwa09132006/aws-security-audit.git
cd aws-security-audit
chmod +x security_audit.sh
bash security_audit.sh
```

**For GitHub Actions automation:**

Add these two secrets to your repo under Settings → Secrets → Actions:

-   `AWS_ACCESS_KEY_ID`
-   `AWS_SECRET_ACCESS_KEY`

Then push to main — the workflow triggers automatically.

* * *

## Roadmap

-   \[ \] Enable MFA on `vp-cli-user` → push score to 4/7
-   \[ \] Enable CloudTrail → push score to 5/7
-   \[ \] Add custom password policy → push score to 6/7
-   \[ \] Add severity levels (CRITICAL / HIGH / MEDIUM)
-   \[ \] Expand to multi-region scanning
-   \[ \] Add Slack notification support
-   \[ \] Auto-remediation for low-risk findings

* * *

*Built as part of a self-directed cloud engineering roadmap — Phase 2 of 5.* *Queens College CS · Building toward a cloud engineering internship.*