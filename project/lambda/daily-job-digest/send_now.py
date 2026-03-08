#!/usr/bin/env python3
"""
send_now.py — Send the CareerForge digest immediately via SES.
Polls until krishnagoutham37@gmail.com is verified, then sends.

Usage:
  python3 send_now.py
"""
import boto3, time, sys
from boto3.dynamodb.conditions import Attr
from datetime import datetime, timezone

REGION     = "us-east-1"
FROM_EMAIL = "krishnagoutham37@gmail.com"
RECIPIENTS = ["krishnagoutham37@gmail.com", "hiruviru18@gmail.com", "kishorerose88@gmail.com"]

def _to_float(v):
    try: return float(v)
    except: return 0.0

def fetch_top_jobs(n=5):
    ddb = boto3.resource("dynamodb", region_name=REGION)
    table = ddb.Table("Jobs")
    items, kw = [], {"FilterExpression": Attr("matchScore").exists()}
    while True:
        r = table.scan(**kw)
        items.extend(r.get("Items", []))
        if not r.get("LastEvaluatedKey"): break
        kw["ExclusiveStartKey"] = r["LastEvaluatedKey"]
    items.sort(key=lambda j: _to_float(j.get("matchScore", 0)), reverse=True)
    return items[:n]

def format_digest(jobs):
    today = datetime.now(timezone.utc).strftime("%B %d, %Y")
    subject = f"CareerForge Daily Job Digest — {today}"
    lines = ["CareerForge — Daily Job Digest", f"Date        : {today}",
             f"Top {len(jobs)} jobs by match score", "=" * 52, ""]
    for i, job in enumerate(jobs, 1):
        score = _to_float(job.get("matchScore", 0))
        skills = job.get("requiredSkills", [])
        skills_str = ", ".join(str(s) for s in (skills[:5] if isinstance(skills, list) else [])) or "N/A"
        missing = job.get("missingSkills", [])
        missing_str = ", ".join(str(s) for s in (missing[:3] if isinstance(missing, list) else []))
        lines.append(f"#{i}  {job.get('title','?')}")
        lines.append(f"    Company     : {job.get('company','?')}")
        lines.append(f"    Location    : {job.get('location','Remote')}")
        lines.append(f"    Match Score : {score:.0f}%")
        if job.get("salary"): lines.append(f"    Salary      : {job['salary']}")
        if job.get("jobType"): lines.append(f"    Type        : {job['jobType']}")
        lines.append(f"    Skills      : {skills_str}")
        if missing_str: lines.append(f"    Gaps        : {missing_str}")
        if job.get("url"): lines.append(f"    Apply       : {job['url']}")
        lines.append("")
    lines += ["─"*52, "View all matches in your CareerForge dashboard.",
              "Generate a tailored resume for any job with one click.", ""]
    return subject, "\n".join(lines)

def is_verified(ses, email):
    r = ses.get_email_identity(EmailIdentity=email)
    return r.get("VerifiedForSendingStatus", False)

ses = boto3.client("sesv2", region_name=REGION)

print(f"⏳  Waiting for {FROM_EMAIL} to be verified in SES...")
print("   → Check your inbox and click the AWS verification link.\n")

while True:
    if is_verified(ses, FROM_EMAIL):
        print(f"✅  {FROM_EMAIL} is verified!")
        break
    print("   still waiting... (checking every 5s)")
    time.sleep(5)

# Check which recipients are verified (sandbox: all must be)
unverified = [e for e in RECIPIENTS if not is_verified(ses, e)]
if unverified:
    print(f"\n⚠️  SES sandbox: these recipients still need to click their verification link:")
    for e in unverified: print(f"   • {e}")
    print("\nWaiting for all recipients to verify...")
    while unverified:
        time.sleep(5)
        unverified = [e for e in RECIPIENTS if not is_verified(ses, e)]
        if unverified:
            print(f"   still waiting on: {', '.join(unverified)}")
        else:
            print("✅  All recipients verified!")

print("\n📬  Fetching top jobs from DynamoDB...")
jobs = fetch_top_jobs(5)
print(f"    Found {len(jobs)} scored jobs")

subject, body = format_digest(jobs)

print(f"\n📨  Sending digest: '{subject}'")
print(f"    To: {', '.join(RECIPIENTS)}\n")

ses_v1 = boto3.client("ses", region_name=REGION)
resp = ses_v1.send_email(
    Source=FROM_EMAIL,
    Destination={"ToAddresses": RECIPIENTS},
    Message={
        "Subject": {"Data": subject, "Charset": "UTF-8"},
        "Body":    {"Text": {"Data": body, "Charset": "UTF-8"}},
    },
)
print(f"✅  Sent! MessageId: {resp['MessageId']}")
print(f"\nThe digest with {len(jobs)} jobs has landed in all inboxes.")
