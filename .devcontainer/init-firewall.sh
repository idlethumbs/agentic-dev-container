#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, and pipeline failures
IFS=$'\n\t'       # Stricter word splitting

# 1. Extract Docker DNS info BEFORE any flushing
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# Flush existing rules and delete existing ipsets
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

# 2. Selectively restore ONLY internal Docker DNS resolution
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
else
    echo "No Docker DNS rules to restore"
fi

# First allow DNS and localhost before any restrictions
# Allow outbound DNS
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
# Allow inbound DNS responses
iptables -A INPUT -p udp --sport 53 -j ACCEPT
# Allow outbound SSH
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
# Allow inbound SSH responses
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
# Allow localhost
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Create ipset with CIDR support
ipset create allowed-domains hash:net

# Fetch GitHub meta information and aggregate + add their IP ranges
echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -s https://api.github.com/meta)
if [ -z "$gh_ranges" ]; then
    echo "ERROR: Failed to fetch GitHub IP ranges"
    exit 1
fi

if ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
    echo "ERROR: GitHub API response missing required fields"
    exit 1
fi

echo "Processing GitHub IPs..."
while read -r cidr; do
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "ERROR: Invalid CIDR range from GitHub meta: $cidr"
        exit 1
    fi
    echo "Adding GitHub range $cidr"
    ipset add allowed-domains "$cidr" -exist
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q)

# Resolve and add other allowed domains
# Groups: core infra, Google Cloud, web search & reference,
#         package registries (npm, PyPI, Go, Rust, Ruby),
#         system package repos (apt), Docker/container registries,
#         AI/LLM providers, documentation sites,
#         deployment platforms, Terraform/IaC,
#         well-known online MCP servers
for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    "sentry.io" \
    "statsig.anthropic.com" \
    "statsig.com" \
    "marketplace.visualstudio.com" \
    "vscode.blob.core.windows.net" \
    "update.code.visualstudio.com" \
    "github.com" \
    "raw.githubusercontent.com" \
    "aiplatform.googleapis.com" \
    "global-aiplatform.googleapis.com" \
    "us-central1-aiplatform.googleapis.com" \
    "generativelanguage.googleapis.com" \
    "oauth2.googleapis.com" \
    "www.googleapis.com" \
    "drive.googleapis.com" \
    "storage.googleapis.com" \
    "sqladmin.googleapis.com" \
    "www.google.com" \
    "google.com" \
"stackoverflow.com" \
    "developer.mozilla.org" \
    "en.wikipedia.org" \
    "wikipedia.org" \
    "pypi.org" \
    "files.pythonhosted.org" \
    "api.tavily.com" \
    "api.search.brave.com" \
    "api.exa.ai" \
    "api.firecrawl.dev" \
    "api.perplexity.ai" \
    "smithery.ai" \
    "registry.smithery.ai" \
    "mcp.run" \
    "sse.dev" \
    "router.mcp.run" \
    "glama.ai" \
    "deb.debian.org" \
    "security.debian.org" \
    "archive.ubuntu.com" \
    "registry-1.docker.io" \
    "auth.docker.io" \
    "production.cloudflare.docker.com" \
    "ghcr.io" \
    "proxy.golang.org" \
    "sum.golang.org" \
    "crates.io" \
    "static.crates.io" \
    "rubygems.org" \
    "api.openai.com" \
    "api.groq.com" \
    "api.mistral.ai" \
    "api.together.xyz" \
    "openrouter.ai" \
    "docs.python.org" \
    "nodejs.org" \
    "readthedocs.io" \
    "readthedocs.org" \
    "docs.rs" \
    "pkg.go.dev" \
    "docs.github.com" \
    "api.vercel.com" \
    "api.netlify.com" \
    "api.railway.app" \
    "fly.io" \
    "registry.terraform.io" \
    "releases.hashicorp.com"; do
    echo "Resolving $domain..."
    ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then
        echo "ERROR: Failed to resolve $domain"
        exit 1
    fi
    
    while read -r ip; do
        if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "ERROR: Invalid IP from DNS for $domain: $ip"
            exit 1
        fi
        echo "Adding $ip for $domain"
        ipset add allowed-domains "$ip" -exist
    done < <(echo "$ips")
done

# Add Cloud SQL IP range (Google Cloud europe-west1 - used by Cloud SQL Proxy)
# The Cloud SQL proxy connects directly to instance IPs, which can change
# Adding a /24 range to cover potential IP changes within the same subnet
echo "Adding Cloud SQL IP ranges..."
ipset add allowed-domains "35.233.64.0/24" -exist

# Get host IP from default route
HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -z "$HOST_IP" ]; then
    echo "ERROR: Failed to detect host IP"
    exit 1
fi

HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
echo "Host network detected as: $HOST_NETWORK"

# Set up remaining iptables rules
iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT

# Set default policies to DROP first
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# First allow established connections for already approved traffic
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Host-exposed services via host.docker.internal
HDI_IP=$(getent hosts host.docker.internal 2>/dev/null | awk '{print $1}')

if [ -n "$HDI_IP" ]; then
    # Figma MCP
    echo "Allowing Figma MCP at $HDI_IP:3845"
    iptables -A OUTPUT -p tcp -d "$HDI_IP" --dport 3845 -j ACCEPT

    # Local dev server (localhost:3000)
    echo "Allowing localhost:3000 at $HDI_IP:3000"
    iptables -A OUTPUT -p tcp -d "$HDI_IP" --dport 3000 -j ACCEPT

    # Common alt HTTP (localhost:8080)
    echo "Allowing localhost:8080 at $HDI_IP:8080"
    iptables -A OUTPUT -p tcp -d "$HDI_IP" --dport 8080 -j ACCEPT

    # Vite dev server (localhost:5173)
    echo "Allowing localhost:5173 at $HDI_IP:5173"
    iptables -A OUTPUT -p tcp -d "$HDI_IP" --dport 5173 -j ACCEPT

    # Python/Django dev server (localhost:8000)
    echo "Allowing localhost:8000 at $HDI_IP:8000"
    iptables -A OUTPUT -p tcp -d "$HDI_IP" --dport 8000 -j ACCEPT

    # Angular dev server (localhost:4200)
    echo "Allowing localhost:4200 at $HDI_IP:4200"
    iptables -A OUTPUT -p tcp -d "$HDI_IP" --dport 4200 -j ACCEPT

    # Allow only established/related return traffic from host
    iptables -A INPUT -s "$HDI_IP" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
fi

# Then allow only specific outbound traffic to allowed domains
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

# Explicitly REJECT all other outbound traffic for immediate feedback
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited



echo "Firewall configuration complete"
echo "Verifying firewall rules..."
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - was able to reach https://example.com"
    exit 1
else
    echo "Firewall verification passed - unable to reach https://example.com as expected"
fi

# Verify GitHub API access
if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://api.github.com"
    exit 1
else
    echo "Firewall verification passed - able to reach https://api.github.com as expected"
fi
