# Quick Deploy (Everything Already Set Up)

> EC2 IP: `3.229.137.116` · SSH key: `~/.ssh/careerforge-ec2.pem`  
> Amplify app: `da4uq3j68b16w` · Branch: `production`

---

## Deploy Frontend

```bash
git add -A
git commit -m "your message"
git push origin production
```

Amplify auto-deploys on push. Takes ~5–7 min. Monitor:

```bash
watch -n 30 "aws amplify list-jobs --app-id da4uq3j68b16w --branch-name production \
  --region us-east-1 --profile careerforge-dev \
  --query 'jobSummaries[0].{Job:jobId,Status:status}' --output table"
```

---

## Deploy Backend

```bash
ssh -i ~/.ssh/careerforge-ec2.pem ubuntu@3.229.137.116 "
  cd /home/ubuntu/careerforge && git pull origin production &&
  source project/backend/venv/bin/activate &&
  pip install -r project/backend/requirements.txt --quiet &&
  sudo systemctl restart careerforge &&
  sleep 4 && curl -s http://127.0.0.1:8000/health
"
```

---

## Deploy Both

```bash
# 1. Push code (triggers Amplify build automatically)
git add -A && git commit -m "your message" && git push origin production

# 2. Update backend simultaneously
ssh -i ~/.ssh/careerforge-ec2.pem ubuntu@3.229.137.116 "
  cd /home/ubuntu/careerforge && git pull origin production &&
  source project/backend/venv/bin/activate &&
  pip install -r project/backend/requirements.txt --quiet &&
  sudo systemctl restart careerforge &&
  sleep 4 && curl -s http://127.0.0.1:8000/health
"
```

---

## Change a Backend Config Value (no code push needed)

```bash
ssh -i ~/.ssh/careerforge-ec2.pem ubuntu@3.229.137.116 "
  nano /home/ubuntu/careerforge/project/backend/.env
  # edit, save, then:
  sudo systemctl restart careerforge
"
```

---

## Quick Health Check

```bash
# Backend
curl -s http://3.229.137.116/health

# Frontend + proxy
curl -sI https://production.da4uq3j68b16w.amplifyapp.com/ | grep HTTP
```
