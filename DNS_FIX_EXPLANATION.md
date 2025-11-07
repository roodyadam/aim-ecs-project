# DNS Fix Explanation - Historical Context

## ⚠️ NOTE: This file contains outdated information

**Current Status**: DNS is now correctly configured. See `DNS_SETUP_FINAL.md` for current configuration.

## 🔴 The Original Problem (RESOLVED)

Your domain `tm.roodyadamsapp.com` worked for you but not for others because:

1. **You had TWO Route53 hosted zones** for the same domain
2. **Your domain registrar** was pointing to one zone's nameservers
3. **But the DNS record** was only in the other zone
4. **Result**: 
   - Your local DNS (cached) → Found record → ✅ Worked
   - External DNS servers → Queried wrong zone → Found nothing → ❌ Failed

## ✅ Current Configuration (CORRECT)

- **Route53 Zone**: `Z06988621L4AI5LXY4AF3` (Zone 1) - This is the ONLY zone
- **Nameservers**: ns-896.awsdns-48.net, ns-107.awsdns-13.com, ns-1459.awsdns-54.org, ns-1909.awsdns-46.co.uk
- **DNS Record**: Exists in Zone 1 and is correct
- **External DNS**: ✅ Working (verified)

**See `DNS_SETUP_FINAL.md` for complete current configuration.**

### Historical Context

This file documented a previous fix attempt. The current correct configuration is:
- Zone 1 (`Z06988621L4AI5LXY4AF3`) is the active zone
- Zone 2 no longer exists
- DNS record is in Zone 1
- Terraform is configured to use Zone 1
- Everything is working correctly

## 🎓 Key Concepts to Learn

### Route53 Hosted Zones

- A **hosted zone** is a container for DNS records for a domain
- Each zone has its own set of **nameservers** (like `ns-1509.awsdns-60.org`)
- Your **domain registrar** (where you bought the domain) must point to ONE zone's nameservers
- DNS queries go: `User → DNS Server → Nameservers (from registrar) → Hosted Zone → Record`

### How DNS Resolution Works

```
1. User types: https://tm.roodyadamsapp.com
2. Browser asks DNS server: "What's the IP for tm.roodyadamsapp.com?"
3. DNS server checks: "Who are the nameservers for roodyadamsapp.com?"
4. Gets nameservers from domain registrar (Zone 2 nameservers)
5. Queries Zone 2 nameservers: "What's the IP for tm.roodyadamsapp.com?"
6. Zone 2 returns: "It's an alias to aimapp-alb-962039018.eu-west-2.elb.amazonaws.com"
7. Browser connects to that ALB
```

### The Problem in Detail

```
Your Setup:
├── Domain Registrar
│   └── Points to Zone 2 nameservers (ns-1509, ns-1622, etc.)
│
├── Route53 Zone 1 (Z06988621L4AI5LXY4AF3)
│   └── Has DNS record ✅
│   └── But registrar doesn't point here ❌
│
└── Route53 Zone 2 (Z03471512MMNKQA60WMUH)
    └── No DNS record ❌
    └── But registrar points here ✅
```

**Result**: External DNS servers query Zone 2 (as instructed by registrar) → find nothing → can't resolve

## 🔍 How to Diagnose This Issue

### 1. Check which nameservers your registrar uses:
```bash
whois roodyadamsapp.com | grep -i "name server"
```

### 2. List all Route53 hosted zones:
```bash
aws route53 list-hosted-zones --query "HostedZones[?Name=='roodyadamsapp.com.']"
```

### 3. Check which zone has those nameservers:
```bash
# Check Zone 1
aws route53 get-hosted-zone --id Z06988621L4AI5LXY4AF3 \
  --query 'DelegationSet.NameServers'

# Check Zone 2
aws route53 get-hosted-zone --id Z03471512MMNKQA60WMUH \
  --query 'DelegationSet.NameServers'
```

### 4. Test DNS resolution from external servers:
```bash
# Test from Google DNS
dig @8.8.8.8 tm.roodyadamsapp.com +short

# Test from Cloudflare DNS
dig @1.1.1.1 tm.roodyadamsapp.com +short
```

If external DNS servers can't resolve it, but your local DNS can, it's likely a zone mismatch issue.

## ✅ The Final Fix

1. **Confirmed** Zone 1 (`Z06988621L4AI5LXY4AF3`) is the correct zone
2. **Verified** registrar points to Zone 1's nameservers
3. **Confirmed** DNS record exists in Zone 1
4. **Verified** external DNS resolution works
5. **Documented** the correct configuration

## 📚 Current Configuration

1. **`infra/main.tf`** (Line 64)
   - Uses `hosted_zone_id = "Z06988621L4AI5LXY4AF3"` (Zone 1) ✅

2. **Route53 Zone 1**
   - Contains the A record pointing to ALB ✅
   - Nameservers match registrar ✅

3. **No Zone 2**
   - Zone 2 no longer exists
   - No confusion between zones ✅

## 🎯 Takeaway

**Your DNS is correctly configured. You should NEVER need to change nameservers again.**

- Zone 1 is permanent
- Nameservers are permanent  
- Terraform automatically manages DNS records
- Only one zone exists (no confusion)



