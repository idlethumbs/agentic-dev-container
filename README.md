# Dev Container for Agentic Development

A modified version of the [Claude Code dev container]([https://docs.anthropic.com/en/docs/claude-code](https://code.claude.com/docs/en/devcontainer#development-containers)) setup with sensible defaults for agentic AI development. The container runs a strict outbound firewall — all traffic is blocked by default, and only pre-approved domains and services are allowed through.

## What's included

The container ships with [Claude Code](https://code.claude.com) installed globally. Commented-out lines in the Dockerfile let you add alternative coding agents — just uncomment the ones you want and rebuild:

- [OpenAI Codex CLI](https://github.com/openai/codex) — uses `api.openai.com` (already in the firewall allowlist)
- [Aider](https://aider.chat) — supports many LLM providers via LiteLLM (major providers already allowed)
- [Goose by Block](https://github.com/block/goose) — supports 20+ LLM providers (major providers already allowed)

No additional firewall rules are needed — the existing allowlist covers all major LLM provider APIs.

## Setup

See the [claude docs](https://code.claude.com/docs/en/devcontainer#getting-started-in-4-steps) for information on how to get container started.

## Getting started

The container loads environment variables from `.devcontainer/.env`. This file is gitignored to prevent secrets from being committed. An `initializeCommand` in `devcontainer.json` will create an empty `.env` automatically on first build, so the container works out of the box with no configuration.

To add your own variables, copy the example file and fill in the values you need:

```sh
cp .devcontainer/.env.example .devcontainer/.env
```

See `.devcontainer/.env.example` for the available variables. None are required — the container boots fine with an empty `.env`.

## How it works

On container start, `init-firewall.sh` runs with `NET_ADMIN` / `NET_RAW` capabilities and:

1. Resolves every whitelisted domain to its current IPs via DNS
2. Fetches GitHub's published IP ranges from their `/meta` endpoint
3. Adds all resolved IPs to an `ipset` used by `iptables`
4. Drops all other outbound traffic (with `REJECT` for fast failure)
5. Verifies the firewall blocks `example.com` and allows `api.github.com`

If any domain fails to resolve, the script exits with an error and the container won't start — so a clean boot means every allowlisted domain is reachable.

## What's allowed through the firewall

### Core infrastructure
| Domain | Purpose |
|---|---|
| `github.com` | Git hosting |
| `raw.githubusercontent.com` | Raw file access |
| `api.github.com` | GitHub API (IPs fetched from `/meta`) |
| `sentry.io` | Error tracking |
| `statsig.anthropic.com` / `statsig.com` | Feature flags |

### VS Code / IDE
| Domain | Purpose |
|---|---|
| `marketplace.visualstudio.com` | Extension marketplace |
| `vscode.blob.core.windows.net` | Extension downloads |
| `update.code.visualstudio.com` | VS Code updates |

### Google Cloud
| Domain | Purpose |
|---|---|
| `aiplatform.googleapis.com` | Vertex AI |
| `global-aiplatform.googleapis.com` | Vertex AI (global) |
| `us-central1-aiplatform.googleapis.com` | Vertex AI (us-central1) |
| `generativelanguage.googleapis.com` | Gemini API |
| `oauth2.googleapis.com` | OAuth |
| `www.googleapis.com` | General Google APIs |
| `drive.googleapis.com` | Google Drive |
| `storage.googleapis.com` | Cloud Storage |
| `sqladmin.googleapis.com` | Cloud SQL Admin |
| `35.233.64.0/24` | Cloud SQL Proxy (europe-west1) |

### AI / LLM providers
| Domain | Purpose |
|---|---|
| `api.anthropic.com` | Anthropic / Claude |
| `api.openai.com` | OpenAI |
| `api.groq.com` | Groq |
| `api.mistral.ai` | Mistral |
| `api.together.xyz` | Together AI |
| `openrouter.ai` | OpenRouter |

### Web search and reference
| Domain | Purpose |
|---|---|
| `www.google.com` / `google.com` | Google search |
| `www.bing.com` | Bing search |
| `api.tavily.com` | Tavily search API |
| `api.search.brave.com` | Brave search API |
| `api.exa.ai` | Exa search API |
| `api.firecrawl.dev` | Firecrawl web scraping |
| `api.perplexity.ai` | Perplexity AI |
| `stackoverflow.com` | Stack Overflow |
| `developer.mozilla.org` | MDN Web Docs |
| `en.wikipedia.org` / `wikipedia.org` | Wikipedia |

### Documentation sites
| Domain | Purpose |
|---|---|
| `docs.python.org` | Python docs |
| `nodejs.org` | Node.js docs |
| `readthedocs.io` / `readthedocs.org` | ReadTheDocs |
| `docs.rs` | Rust crate docs |
| `pkg.go.dev` | Go package docs |
| `docs.github.com` | GitHub docs |

### Package registries
| Domain | Purpose |
|---|---|
| `registry.npmjs.org` | npm (JavaScript) |
| `pypi.org` / `files.pythonhosted.org` | PyPI (Python) |
| `proxy.golang.org` / `sum.golang.org` | Go module proxy |
| `crates.io` / `static.crates.io` | Cargo (Rust) |
| `rubygems.org` | RubyGems |

### System package repos (apt)
| Domain | Purpose |
|---|---|
| `deb.debian.org` | Debian packages |
| `security.debian.org` | Debian security updates |
| `archive.ubuntu.com` | Ubuntu packages |

### Docker / container registries
| Domain | Purpose |
|---|---|
| `registry-1.docker.io` | Docker Hub |
| `auth.docker.io` | Docker Hub auth |
| `production.cloudflare.docker.com` | Docker Hub CDN |
| `ghcr.io` | GitHub Container Registry |

### MCP servers
| Domain | Purpose |
|---|---|
| `smithery.ai` / `registry.smithery.ai` | Smithery MCP registry |
| `mcp.run` / `router.mcp.run` | MCP.run |
| `sse.dev` | SSE-based MCP transport |
| `glama.ai` | Glama MCP registry |

### Deployment platforms
| Domain | Purpose |
|---|---|
| `api.vercel.com` | Vercel |
| `api.netlify.com` | Netlify |
| `api.railway.app` | Railway |
| `fly.io` | Fly.io |

### Terraform / IaC
| Domain | Purpose |
|---|---|
| `registry.terraform.io` | Terraform provider registry |
| `releases.hashicorp.com` | HashiCorp binary releases |

### Localhost services (via `host.docker.internal`)
| Port | Purpose |
|---|---|
| `3000` | Local dev server |
| `3845` | Figma MCP |
| `4200` | Angular dev server |
| `5173` | Vite dev server |
| `8000` | Python / Django dev server |
| `8080` | Common alt HTTP |

## Cloud SQL Proxy

The container ships with [Cloud SQL Proxy](https://cloud.google.com/sql/docs/mysql/sql-proxy) for connecting to Google Cloud SQL instances. It starts automatically on container boot **only** when both of these environment variables are set in `.devcontainer/.env`:

```
REPO_BACKEND=sql
INSTANCE_CONNECTION_NAME=your-project:region:instance-name
```

When active, the proxy listens on `localhost:5432` inside the container. Logs are written to `/tmp/cloud-sql-proxy.log`.

If either variable is missing or `REPO_BACKEND` is not `sql`, the proxy is skipped entirely. The firewall allowlist includes a `/24` range for Cloud SQL IPs in `europe-west1` (`35.233.64.0/24`) plus `sqladmin.googleapis.com` for the admin API. If your instance is in a different region you may need to add its IP range to `init-firewall.sh`.

## Always blocked

Everything not listed above is blocked. The firewall uses `REJECT` (not `DROP`) so connections fail immediately instead of timing out.

## Customising the allowlist

Edit `.devcontainer/init-firewall.sh` and add domains to the `for domain in ...` loop, or add new `iptables` rules for `host.docker.internal` ports. Rebuild the container for changes to take effect.
