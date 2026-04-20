# Portfolio — Production Deployment on AWS

A portfolio website deployed to AWS using Terraform, Nginx, PM2, and GitHub Actions CI/CD.

## Live architecture

```
Developer
    │  git push
    ▼
GitHub (master branch)
    │  triggers
    ▼
GitHub Actions (deploy.yml)
    │  SSH deploy
    ▼
AWS EC2 — Ubuntu t2.micro (eu-west-2)
  ├── Nginx :80  ──►  server.js :3000  ──►  index.html + assets/
  └── PM2 (keeps server.js running)
```

## Project structure

```
portfoliod/
├── index.html              # Main portfolio page
├── post.html               # Secondary page
├── assets/                 # CSS, images, fonts
├── server.js               # Express server — serves static files
├── package.json
├── terraform/
│   ├── main.tf             # VPC, subnet, security group, EC2
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Public IP, DNS, SSH command
│   └── terraform.tfvars    # Your values (gitignored)
└── .github/
    └── workflows/
        └── deploy.yml      # CI/CD pipeline
```

## What each service does

| Service | Role |
|---|---|
| **Terraform** | Provisions all AWS infrastructure from code |
| **AWS EC2** | Ubuntu VM that hosts the application |
| **Nginx** | Reverse proxy — port 80 → port 3000 |
| **server.js** | Express app that serves portfolio files |
| **PM2** | Keeps server.js running and restarts it if it crashes |
| **GitHub Actions** | Automatically deploys on every push to master |

## Prerequisites

- AWS account with IAM credentials configured
- [Terraform](https://developer.hashicorp.com/terraform/downloads) installed
- [AWS CLI](https://aws.amazon.com/cli/) installed and configured
- Node.js 18+
- SSH key pair

## Setup — one time only

### 1. Clone the repository

```bash
git clone https://github.com/hugdora/portfoliod.git
cd portfoliod
```

### 2. Generate an SSH key pair

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/portfoliod-key
```

### 3. Configure AWS credentials

```bash
aws configure
# Enter your Access Key ID, Secret Access Key, region (eu-west-2), and output format (json)
```

### 4. Create terraform.tfvars

Create `terraform/terraform.tfvars` (this file is gitignored):

```hcl
aws_region          = "eu-west-2"
instance_type       = "t2.micro"
app_name            = "portfoliod"
ssh_public_key_path = "~/.ssh/portfoliod-key.pub"
```

### 5. Provision the infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply   # type 'yes' when prompted
```

Note the public IP from the output — you will need it in the next step.

### 6. Add GitHub Secrets

Go to your GitHub repo → **Settings → Secrets and variables → Actions** and add:

| Secret name | Value |
|---|---|
| `VM_HOST` | Public IP from `terraform output public_ip` |
| `VM_USER` | `ubuntu` |
| `VM_SSH_KEY` | Contents of `~/.ssh/portfoliod-key` (the private key) |

### 7. Verify the deployment

Wait 2–3 minutes for the EC2 startup script to finish, then open:

```
http://YOUR_PUBLIC_IP
```

Your portfolio should be live.

## CI/CD — how it works

Every push to the `master` branch triggers the GitHub Actions workflow automatically:

1. GitHub detects the push and starts `deploy.yml`
2. The runner checks out your code and installs dependencies
3. A basic HTTP test confirms the app starts correctly
4. The `appleboy/ssh-action` SSHs into your EC2 instance
5. On the server: `git pull` → `npm install` → `pm2 restart`
6. Your changes are live within about 60 seconds

No manual deployment steps are needed after initial setup.

## Useful commands

```bash
# Check the app process
pm2 status

# View app logs
pm2 logs portfoliod

# Test Nginx config
sudo nginx -t

# Check Nginx status
sudo systemctl status nginx

# Test the app locally on the server
curl http://localhost:3000

# Get Terraform outputs
terraform output
```

## Cleanup

To avoid AWS charges when you are finished:

```bash
cd terraform
terraform destroy   # type 'yes' when prompted
```

This removes all AWS resources created for this project.

## Security notes

- Never commit `terraform.tfvars` or your private key to the repository
- SSH private key is stored only in GitHub Secrets
- The security group allows port 22 (SSH) and port 80 (HTTP) only
- Use HTTPS with Let's Encrypt for production environments

## Bonus — add HTTPS

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```
