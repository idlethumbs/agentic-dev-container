# Dev Container for Agentic Development

A modified version of the [Claude Code dev container](https://docs.anthropic.com/en/docs/claude-code) setup with sensible defaults for agentic AI development. The container runs a strict outbound firewall — all traffic is blocked by default, and only pre-approved domains and services are allowed through.

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

## Always blocked

Everything not listed above is blocked. The firewall uses `REJECT` (not `DROP`) so connections fail immediately instead of timing out.

## Customising the allowlist

Edit `.devcontainer/init-firewall.sh` and add domains to the `for domain in ...` loop, or add new `iptables` rules for `host.docker.internal` ports. Rebuild the container for changes to take effect.
