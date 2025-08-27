# Ghidra Server on AWS Using IaC (OpenTofu/Terraform)

Spin up a single EC2 instance running a Ghidra **server** in Docker, with users seeded from IaC.

_NOTE_: This project is **not supported by or affiliated with Georgia Institute of Technology**.  
I am a student in CS6747 (Advanced Malware Analysis) and created this to help classmates easily deploy a Ghidra server for team collaboration.

Credit to [Cryptophobia](https://github.com/Cryptophobia/docker-ghidra-server-aws) for inspiration.

## Contents

- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Configuration](#configuration)
  - [Variables](#variables)
  - [terraform.tfvars example](#terraformtfvars-example)
  - [AWS credentials](#aws-credentials)
- [Deploy](#deploy)
- [Connect to the server](#connect-to-the-server)
- [Destroy](#destroy)
- [Troubleshooting](#troubleshooting)
- [Security notes](#security-notes)
- [Protect your wallet!!](#protect-your-wallet)
- [Architecture](#architecture)

## Prerequisites

- **AWS account** with permission to create EC2, IAM roles, and Security Groups
- **OpenTofu** (`tofu`) _or_ **Terraform** (`terraform`)
- **AWS CLI v2** (`aws --version`)

## Quick start

1. **Clone** this repo and `cd` into it:

   ```bash
   git clone https://github.com/benjaminwilcox/ghidra-server-iac.git
   cd ghidra-server-iac
   ```

2. Copy the example variables and edit:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Authenticate** to AWS:

   ```bash
   aws configure
   ```

4. **Plan & apply**:

   ```bash
    tofu init
    tofu apply   # type 'yes' when prompted
   ```

   > If using terraform, replace any `tofu` commands with `terraform`

5. Grab the **outputs** after apply (public IP/DNS):

   ```bash
   tofu output
   ```

## What it creates

- An **IAM role** and instance profile for the EC2 server.
- One **EC2 instance** using an Ubuntu AMI and `instance_type`.
- A dedicated **Security Group** that allows:
  - **TCP 13100–13102** (Ghidra server) only from the CIDRs you specify (`allowed_ghidra_cidrs`).
- An **Elastic IP** to keep a static public IP across stop/starts:
  - Outputs the static IP as public_ip.
  - Note: idle/unattached EIPs cost $0.005/hr ($3.60/mo).
- Cloud-init **user data** that:
  - Installs Docker and dependencies.
  - Builds and runs a Ghidra server container.
  - Seeds user accounts from `ghidra_users`.
  - Registers a `systemd` service for automatic startup.
- An **AWS Budget** with email alerts, if `enable_budget = true`.

**Outputs** (after apply)

- `ghidra_server_ip` — Public IP address of the Ghidra server.
- `ssm_shell` — Copy-pasteable SSM command to connect to your instance.
- `ghidra_client_instructions` — Step-by-step instructions for connecting from the Ghidra GUI client.

## Connect to the server

1. **SSM** into the instance:

   ```bash
   aws ssm start-session --target <instance-id>
   sudo su - ubuntu
   ```

2. Verify the service:

   ```bash
   sudo docker ps
   sudo docker logs ghidra-server --tail=100
   ```

3. **Ghidra client** → **Server**

   - Host: `<public_ip>`
   - Port: `13100`
   - Users: the ones you set in `ghidra_users`
   - Password: `changeme` (**must be changed immediately after first login**).

## Destroy

```bash
tofu destroy    # terraform destroy
```

This will terminate the instance and destroy all resources.

## Configuration

### Variables

The repo defines (at minimum) the following variables (see [variables.tf](./variables.tf) for details):

- `aws_region` _(string)_ — AWS region to deploy into (default: `us-east-1`).
- `project_name` _(string)_ — Prefix for resource naming and tagging (default: `"ghidra-server"`).
- `instance_type` _(string)_ — EC2 instance type (`t2.micro`, `t3.micro`, or `t3.small`).
- `ghidra_users` _(string)_ — **Space-separated** list of usernames to seed in the Ghidra server.
- `allowed_ghidra_cidrs` _(list)_ — CIDRs allowed to connect to Ghidra client ports (13100–13102).
- `enable_budget` _(bool)_ — Whether to enable a budget alarm (default: `true`).
- `monthly_budget_limit_usd` _(number)_ — Monthly budget cap (USD).
- `billing_emails` _(list)_ — Email addresses for budget notifications.

### `terraform.tfvars` example

```hcl
# ============================
# AWS configuration
# ============================
aws_region = "us-east-1"

# ============================
# Project settings
# ============================
project_name = "cs6747-ghidra-server"

# ============================
# EC2 configuration
# ============================
instance_type = "t2.micro"   # may be free tier eligible; valid options: t2.micro, t3.micro, or t3.small

# ============================
# Ghidra users
# ============================
# Space-separated list; these will be created in the server on first boot
ghidra_users = "ben steve" # add your teammates

# ============================
# Network access
# ============================
# These lists define who can connect to Ghidra.
# Find your current public IP: curl -4 ifconfig.me (run this in your VM)
allowed_ghidra_cidrs = [
  "X.X.X.X/32",  # add teammates' IPs if needed
]

# ============================
# Budget configuration
# ============================
enable_budget             = true
monthly_budget_limit_usd  = 5
billing_emails            = ["student@school.edu"]

```

## Troubleshooting

**No valid credential sources found / no EC2 IMDS role found**

- You’re not logged in to AWS locally. Test with `aws sts get-caller-identity`.

**Ghidra port unreachable**

- Ensure Security Group allows **TCP 13100** from your client IP(s).
- Check to see if the server is running properly: `sudo docker ps` and `sudo docker logs ghidra-server`.

**AMI not found**

- AMI IDs are region-specific. Pick an Ubuntu AMI for your **region**.

## Security notes

- Restrict CIDRs to only what you need.
- Change the default password for seeded users immediately.

## Protect your wallet!!

Running AWS resources, even small ones, can cost money if left running.  
This repo includes a **Budget module** that helps you avoid surprise AWS bills:

- Sets a **monthly USD limit**.
- Sends **email alerts** when:
  - **Forecasted** spend exceeds **80%**.
  - **Actual** spend exceeds **100%**.

Notes:

- Budgets are account-wide.

- Data refreshes every few hours.

- Budgets do not stop resources. You must still run `tofu destroy`.

## Architecture

```mermaid
flowchart LR
  %% ===== Student side =====
  subgraph DEV["Student"]
    TFVARS["<code>terraform.tfvars</code>"]
    GHIDRA_GUI["Ghidra Client<br/>(connects to EC2 public IP:13100–13102)"]
    AWSCLI["AWS CLI v2<br/>(Session Manager shell)"]
  end

  %% ===== IaC engine =====
  subgraph TF["OpenTofu / Terraform"]
    VARS["variables.tf"]
    MOD_SEC["module: security<br/>(Security Group)"]
    MOD_SRV["module: ghidra-server<br/>(EC2, user_data, SSM Agent)"]
    MOD_BUD["module: budget"]
    OUTS["outputs.tf"]
  end

  %% ===== AWS resources =====
  subgraph AWS["AWS Account"]
    IAM["IAM Role + Instance Profile<br/>+ AmazonSSMManagedInstanceCore"]
    SG["Security Group<br/>Ghidra: 13100–13102<br/>(from allowed_ghidra_cidrs)"]
    EC2["EC2 (Ubuntu)<br/>Docker + Ghidra Server<br/>systemd service<br/>SSM Agent"]
    BUD["AWS Budgets<br/>(email alerts)"]
  end

  %% Vars drive modules
  TFVARS --> VARS
  VARS --> MOD_SEC
  VARS --> MOD_SRV
  VARS --> MOD_BUD

  %% Modules create resources
  MOD_SRV --> IAM
  MOD_SEC --> SG
  MOD_SRV --> EC2
  MOD_BUD --> BUD
  SG --> EC2

  %% How you connect
  AWSCLI -->|"SSM Session Shell"| EC2
  GHIDRA_GUI -->|"TCP 13100–13102"| EC2

  %% Outputs back to user
  OUTS -->|"ghidra_server_ip<br/>ssm_shell<br/>ghidra_client_instructions"| DEV
```
