# Agentic AI Immersion Workshop

[![Microsoft Foundry](https://img.shields.io/badge/Microsoft-Foundry-blue?style=for-the-badge&logo=microsoft)](https://ai.azure.com)
[![Python](https://img.shields.io/badge/Python-3.10+-green?style=for-the-badge&logo=python)](https://python.org)
[![Jupyter](https://img.shields.io/badge/Jupyter-Lab-orange?style=for-the-badge&logo=jupyter)](https://jupyter.org)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

---

[Overview](#overview) · [Learning Outcomes](#learning-outcomes) · [Workshop Structure](#how-the-workshop-is-structured) · [Industry Use Cases](#industry-use-cases) · [Getting Started](#getting-started) · [Troubleshooting](#troubleshooting) · [Resources](#resources)

---

## Overview

This workshop is a hands-on technical immersion in building AI agents on Microsoft Azure. It is designed for software engineers and solution architects who want to move beyond conceptual understanding of AI and develop practical skill with the Azure AI Foundry platform and the Microsoft Agent Framework.

Participants leave with direct experience of building, extending, evaluating, and securing AI agents — applied to realistic enterprise scenarios across financial services, insurance, and operations.

**Format:** Intensive, lab-based. Each notebook is a self-contained working implementation, not a demonstration.

**Audience:** Developers and architects with Python experience. No prior AI or machine learning background required.

**Platform:** Microsoft Azure AI Foundry, Python 3.10+, Jupyter.

---

## Learning Outcomes

This workshop is about developing judgment, not just technical skill. The goal is that participants leave able to look at a problem and know which AI capability fits — and equally, which ones don't.

By the end of the workshop, participants will be able to:

- **Distinguish between capabilities** — understand where one approach ends and another begins, and why the wrong choice leads to unnecessary complexity or brittle systems
- **Match a business problem to the right tool** — know when to use managed RAG versus a vector search index, when multi-agent orchestration is warranted versus a single well-prompted agent, when memory solves the problem versus when it introduces risk
- **Recognise the boundaries of each service** — understand maturity, preview limitations, and the trade-offs that come with choosing emerging capabilities in production contexts
- **Evaluate build vs configure decisions** — several capabilities in this workshop are fully managed by the platform; others require significant application code. Participants will understand the difference and its implications for maintenance and ownership
- **Assess AI outputs with appropriate scepticism** — run evaluations, interpret quality scores, and understand what adversarial testing reveals about a deployment before it reaches users

---

## How the Workshop Is Structured

The workshop has three tracks. Each track is independent — participants choose the depth they want in each area rather than working through everything sequentially.

### Track 1 — Azure AI Agents SDK (`azure-ai-agents/`)

The primary track and the right starting point regardless of experience level. These nine notebooks work directly with the Azure AI Agents SDK — the raw API surface that Azure AI Foundry exposes. There is no framework layer here: you create agents, manage threads, dispatch tool calls, and handle responses explicitly. Every decision is visible in the code.

This is the track that answers the question *what can AI agents do*. Each notebook introduces one Azure capability and shows exactly how it works at the API level. By the end, participants have a clear mental model of the platform's moving parts — which is the prerequisite for making good decisions about when and whether to add a framework on top.

| # | Notebook | Capability |
|---|----------|------------|
| 1 | [Agent Basics](azure-ai-agents/1-basics.ipynb) | Agent lifecycle, instructions, multi-turn conversation |
| 2 | [Code Interpreter](azure-ai-agents/2-code-interpreter.ipynb) | Sandboxed Python execution, file processing, computation |
| 3 | [File Search](azure-ai-agents/3-file-search.ipynb) | Managed RAG — upload documents and query them immediately |
| 4 | [Bing Grounding](azure-ai-agents/4-bing-grounding.ipynb) | Real-time web search integrated into agent responses |
| 5 | [Azure AI Search](azure-ai-agents/5-agents-aisearch.ipynb) | Vector search, semantic ranking, enterprise knowledge retrieval |
| 6 | [Multi-Agent Workflows](azure-ai-agents/6-multi-agent-solution-with-workflows.ipynb) | Declarative YAML orchestration of specialist agent pipelines |
| 7 | [MCP Tools](azure-ai-agents/7-mcp-tools.ipynb) | Model Context Protocol — agents that use external tool servers |
| 8 | [Foundry IQ](azure-ai-agents/8-foundry-IQ-agents.ipynb) | Agentic retrieval across multiple knowledge bases simultaneously |
| 9 | [Agent Memory](azure-ai-agents/9-agent-memory-search.ipynb) | Cross-session user profiles and semantic memory recall |

### Track 2 — Microsoft Agent Framework (`agent-framework/`)

Where Track 1 answers *what can agents do*, Track 2 answers *how do you build them for production*. The Microsoft Agent Framework is a higher-level SDK that wraps the Azure AI Agents runtime and adds the concerns that enterprise deployments require: a middleware pipeline for intercepting and controlling agent behaviour, pluggable storage for conversation history, workflow abstractions for multi-agent orchestration, and automatic lifecycle management. The analogy is raw HTTP versus a web framework — Track 1 gives you control over everything, Track 2 handles the plumbing so you can focus on business logic.

**This track is organised by concern, not by capability.** Each sub-track is independent and addresses a distinct production engineering problem. You do not need to work through them in order.

#### Agents (`agents/azure-ai-agents/`)

The same nine Azure capabilities from Track 1, re-implemented through the Agent Framework SDK. The underlying Azure services are identical — what changes is how the application code is structured. Take this sub-track to understand the framework's abstractions before applying them in middleware, threads, and workflows. If time is limited, do not do both this sub-track and Track 1 — pick the abstraction level that matches your production context.

| # | Notebook | Pattern |
|---|----------|---------|
| 1 | [Basic Agent](agent-framework/agents/azure-ai-agents/1-azure-ai-basic.ipynb) | Automatic agent lifecycle management |
| 2 | [Explicit Settings](agent-framework/agents/azure-ai-agents/2-azure-ai-with-explicit-settings.ipynb) | Explicit configuration |
| 3 | [Existing Agent](agent-framework/agents/azure-ai-agents/3-azure-ai-with-existing-ai-agent.ipynb) | Reusing a registered agent |
| 4 | [Function Tools](agent-framework/agents/azure-ai-agents/4-azure-ai-with-function-tools.ipynb) | Tool integration |
| 5 | [Code Interpreter](agent-framework/agents/azure-ai-agents/5-azure-ai-with-code-interpreter.ipynb) | Code execution |
| 6 | [File Search](agent-framework/agents/azure-ai-agents/6-azure-ai-with-file-search.ipynb) | Document Q&A |
| 7 | [Bing Grounding](agent-framework/agents/azure-ai-agents/7-azure-ai-with-bing-grounding.ipynb) | Web search |
| 8 | [Hosted MCP](agent-framework/agents/azure-ai-agents/8-azure-ai-with-hosted-mcp.ipynb) | External MCP server |
| 9 | [Multi-turn Threads](agent-framework/agents/azure-ai-agents/9-azure-ai-with-existing-multi-turn-thread.ipynb) | Conversation threading |

#### Context Providers (`context-providers/`)
How agents acquire structured context — user profiles, retrieved documents — before generating a response.

| # | Notebook | Use Case |
|---|----------|----------|
| 1 | [Simple Context Provider](agent-framework/context-providers/1-simple-context-provider.ipynb) | Customer Profile Collection |
| 2 | [Azure AI Search Context](agent-framework/context-providers/2-azure-ai-search-context-agentic.ipynb) | Multi-hop document reasoning for underwriting decisions |

#### Middleware (`middleware/`)
Intercepting and controlling agent behaviour at the pipeline level — audit logging, PII redaction, compliance screening, response modification.

| # | Notebook | Use Case |
|---|----------|----------|
| 1 | [Agent & Run Level](agent-framework/middleware/1-agent-and-run-level-middleware.ipynb) | Compliance audit records per transaction |
| 2 | [Function-Based](agent-framework/middleware/2-function-based-middleware.ipynb) | Trade execution logging |
| 3 | [Class-Based](agent-framework/middleware/3-class-based-middleware.ipynb) | PII protection, request counting |
| 4 | [Decorator](agent-framework/middleware/4-decorator-middleware.ipynb) | Portfolio trading window checks |
| 5 | [Chat Middleware](agent-framework/middleware/5-chat-middleware.ipynb) | PII redaction, sensitive query blocking |
| 6 | [Exception Handling](agent-framework/middleware/6-exception-handling-with-middleware.ipynb) | Graceful service failure recovery |
| 7 | [Termination](agent-framework/middleware/7-middleware-termination.ipynb) | Blocking prohibited transactions |
| 8 | [Result Override](agent-framework/middleware/8-override-result-with-middleware.ipynb) | Appending regulatory disclaimers |
| 9 | [Shared State](agent-framework/middleware/9-shared-state-middleware.ipynb) | Cross-request audit trail state |

#### Threads (`threads/`)
Where conversation history lives and how it persists across sessions and application restarts.

| # | Notebook | Use Case |
|---|----------|----------|
| 1 | [Custom Message Store](agent-framework/threads/1-custom-chat-message-store-thread.ipynb) | Compliance-approved database storage |
| 2 | [Redis Message Store](agent-framework/threads/2-redis-chat-message-store-thread.ipynb) | Distributed sessions across instances |
| 3 | [Suspend/Resume](agent-framework/threads/3-suspend-resume-thread.ipynb) | Long-running claim processing continuity |

#### Workflows (`workflows/`)
Multi-agent orchestration patterns — from streaming output to human approval gates to adaptive Magentic One coordination.

| # | Notebook | Use Case | Pattern |
|---|----------|----------|---------|
| 1 | [Streaming](agent-framework/workflows/1-azure-ai-agents-streaming.ipynb) | Real-time data updates | Streaming |
| 2 | [Chat Streaming](agent-framework/workflows/2-azure-chat-agents-streaming.ipynb) | Customer support chat | Streaming |
| 3 | [Sequential Pipeline](agent-framework/workflows/3-sequential-agents-loan-application.ipynb) | Application processing | Sequential |
| 4 | [Custom Executors](agent-framework/workflows/4-sequential-custom-executors-compliance.ipynb) | Compliance-enforced approval | Sequential |
| 5 | [Human-in-the-Loop](agent-framework/workflows/5-credit-limit-with-human-input.ipynb) | Manager approval gate | Human approval |
| 6 | [Transaction Review](agent-framework/workflows/6-workflow-as-agent-human-in-the-loop-transaction-review.ipynb) | High-value wire authorisation | Human escalation |
| 7 | [Magentic + Compliance](agent-framework/workflows/7-magentic-compliance-review-with-human-input.ipynb) | Research plan review before execution | Magentic |
| 8 | [Magentic Research](agent-framework/workflows/8-magentic-investment-research.ipynb) | Multi-agent market research | Magentic |
| 9 | [Reflection Pattern](agent-framework/workflows/9-workflow-as-agent-reflection-pattern.ipynb) | Iterative communication quality | Reflection |

#### Observability (`observability/`)
Instrumenting the Agent Framework with distributed tracing and Azure Monitor.

| # | Notebook | Use Case |
|---|----------|----------|
| 1 | [Foundry Tracing](agent-framework/observability/1-agent-with-foundry-tracing.ipynb) | Trade execution monitoring |
| 2 | [Agent Observability](agent-framework/observability/2-azure-ai-agent-observability.ipynb) | Customer service monitoring |
| 3 | [Workflow Observability](agent-framework/observability/3-workflow-observability.ipynb) | Loan processing pipeline monitoring |

### Track 3 — Observability & Evaluations (`observability-and-evaluations/`)

Testing AI agents systematically — quality scoring, tool call validation, and adversarial security testing. Independent of Tracks 1 and 2; can be taken by anyone with a working agent deployment.

Each use case across all three tracks is drawn from a set of 49 enterprise scenarios. See [Industry Use Cases](#industry-use-cases) for the full list mapped to notebooks.

| # | Notebook | Use Case | Key Capability |
|---|----------|----------|----------------|
| 1 | [Telemetry](observability-and-evaluations/1-telemetry.ipynb) | Advisory agent monitoring | OpenTelemetry, custom spans, Application Insights |
| 2 | [Agent Evaluation](observability-and-evaluations/2-agent-evaluation.ipynb) | Response quality scoring | Built-in evaluators: fluency, task adherence, safety |
| 3 | [Function Tools Evaluation](observability-and-evaluations/3-agent-evaluation-with-function-tools.ipynb) | Tool-enabled agent quality | Function tool evaluation in strict mode |
| 4 | [Tool Call Accuracy](observability-and-evaluations/4-tool-call-accuracy-evaluation.ipynb) | Tool routing validation | `builtin.tool_call_accuracy` |
| 5 | [Red Team Security](observability-and-evaluations/5-red-team-security-testing.ipynb) | Adversarial security testing | AttackStrategy, RiskCategory, vulnerability scoring |

---

## Industry Use Cases

The workshop uses 49 financial services scenarios as the applied context across all notebooks. These are realistic enterprise problems, not toy examples.

| Use Case | Description | Technology | Notebook |
|----------|-------------|------------|----------|
| Financial Services Advisor | General banking, loan, and investment guidance with regulatory disclaimers | Azure AI Agents v2 | [1-basics.ipynb](azure-ai-agents/1-basics.ipynb) |
| Loan & Portfolio Calculator | Calculates loan payments, amortization schedules, analyzes financial data | Azure AI Agents v2, Code Interpreter | [2-code-interpreter.ipynb](azure-ai-agents/2-code-interpreter.ipynb) |
| Banking Document Search | Search loan policies, banking regulations, and compliance documents | Azure AI Agents v2, File Search | [3-file-search.ipynb](azure-ai-agents/3-file-search.ipynb) |
| Financial Market Research | Real-time market trends, interest rates, and financial news | Azure AI Agents v2, Bing Grounding | [4-bing-grounding.ipynb](azure-ai-agents/4-bing-grounding.ipynb) |
| Banking Products Catalog | Semantic search across banking products (loans, credit cards, accounts) | Azure AI Agents v2, Azure AI Search | [5-agents-aisearch.ipynb](azure-ai-agents/5-agents-aisearch.ipynb) |
| Insurance Claims Processing | Automated claims assessment, validation, and payout decisions | Azure AI Agents v2, Multi-Agent Workflows | [6-multi-agent-solution-with-workflows.ipynb](azure-ai-agents/6-multi-agent-solution-with-workflows.ipynb) |
| Platform Operations Assistant | Model discovery, deployment management, evaluation creation | Azure AI Agents v2, Foundry MCP Server | [7-mcp-tools.ipynb](azure-ai-agents/7-mcp-tools.ipynb) |
| Multi-Source Fraud Investigation | Investigate fraud using patterns, regulations, and procedures | Azure AI Agents v2, Foundry IQ | [8-foundry-IQ-agents.ipynb](azure-ai-agents/8-foundry-IQ-agents.ipynb) |
| Personalized Banking Assistant | Remembers customer preferences for personalized guidance | Azure AI Agents v2, Memory Search | [9-agent-memory-search.ipynb](azure-ai-agents/9-agent-memory-search.ipynb) |
| Financial Advisor Basics | Banking operations with account balance and loan inquiries | Agent Framework, Azure AI Agents | [1-azure-ai-basic.ipynb](agent-framework/agents/azure-ai-agents/1-azure-ai-basic.ipynb) |
| Investment Portfolio Management | Configurable advisor with portfolio allocation recommendations | Agent Framework, Explicit Settings | [2-azure-ai-with-explicit-settings.ipynb](agent-framework/agents/azure-ai-agents/2-azure-ai-with-explicit-settings.ipynb) |
| Persistent Financial Advisor | Reusable banking agent retaining configuration across sessions | Agent Framework, Existing Agent | [3-azure-ai-with-existing-ai-agent.ipynb](agent-framework/agents/azure-ai-agents/3-azure-ai-with-existing-ai-agent.ipynb) |
| Banking Operations Center | Account management, transaction history, loan calculations | Agent Framework, Function Tools | [4-azure-ai-with-function-tools.ipynb](agent-framework/agents/azure-ai-agents/4-azure-ai-with-function-tools.ipynb) |
| Financial Analytics Dashboard | Portfolio analysis, compound interest, loan amortization | Agent Framework, Code Interpreter | [5-azure-ai-with-code-interpreter.ipynb](agent-framework/agents/azure-ai-agents/5-azure-ai-with-code-interpreter.ipynb) |
| Loan Policy Document Search | Q&A over loan policies and compliance documents | Agent Framework, File Search | [6-azure-ai-with-file-search.ipynb](agent-framework/agents/azure-ai-agents/6-azure-ai-with-file-search.ipynb) |
| Financial Market Research Portal | Real-time stock news, economic trends, market information | Agent Framework, Bing Grounding | [7-azure-ai-with-bing-grounding.ipynb](agent-framework/agents/azure-ai-agents/7-azure-ai-with-bing-grounding.ipynb) |
| Documentation Research Assistant | Query external documentation via cloud-hosted tools | Agent Framework, Hosted MCP | [8-azure-ai-with-hosted-mcp.ipynb](agent-framework/agents/azure-ai-agents/8-azure-ai-with-hosted-mcp.ipynb) |
| Loan Application Discussion | Multi-turn conversations for loan applications and planning | Agent Framework, Thread Management | [9-azure-ai-with-existing-multi-turn-thread.ipynb](agent-framework/agents/azure-ai-agents/9-azure-ai-with-existing-multi-turn-thread.ipynb) |
| Customer KYC Profile Collection | Collect and track customer identification for compliance | Agent Framework, Context Providers | [1-simple-context-provider.ipynb](agent-framework/context-providers/1-simple-context-provider.ipynb) |
| Loan Underwriting & Risk Assessment | Review underwriting guidelines with intelligent reasoning | Agent Framework, Azure AI Search (Agentic), Foundry IQ | [2-azure-ai-search-context-agentic.ipynb](agent-framework/context-providers/2-azure-ai-search-context-agentic.ipynb) |
| Transaction Compliance Monitoring | Monitor transactions for regulatory violations with audit logs | Agent Framework, Agent Middleware | [1-agent-and-run-level-middleware.ipynb](agent-framework/middleware/1-agent-and-run-level-middleware.ipynb) |
| Trade Execution Logging | Track trade execution timing for regulatory reporting | Agent Framework, Function Middleware | [2-function-based-middleware.ipynb](agent-framework/middleware/2-function-based-middleware.ipynb) |
| Credit Limit Assessment | Assess credit limits with PII protection and request counting | Agent Framework, Class Middleware | [3-class-based-middleware.ipynb](agent-framework/middleware/3-class-based-middleware.ipynb) |
| Portfolio Rebalancing | Manage portfolio changes with trading window checks | Agent Framework, Decorator Middleware | [4-decorator-middleware.ipynb](agent-framework/middleware/4-decorator-middleware.ipynb) |
| Customer Service Message Filtering | Audit logging, PII redaction, sensitive query blocking | Agent Framework, Chat Middleware | [5-chat-middleware.ipynb](agent-framework/middleware/5-chat-middleware.ipynb) |
| Market Data Service Recovery | Handle external service failures with graceful fallbacks | Agent Framework, Exception Handling | [6-exception-handling-with-middleware.ipynb](agent-framework/middleware/6-exception-handling-with-middleware.ipynb) |
| Transaction Compliance Screening | Block prohibited transactions and rate limit requests | Agent Framework, Termination Logic | [7-middleware-termination.ipynb](agent-framework/middleware/7-middleware-termination.ipynb) |
| Market Data Enrichment | Append regulatory disclaimers to market data responses | Agent Framework, Result Override | [8-override-result-with-middleware.ipynb](agent-framework/middleware/8-override-result-with-middleware.ipynb) |
| Transaction Audit Trail | Track transaction counts and maintain audit data | Agent Framework, Shared State | [9-shared-state-middleware.ipynb](agent-framework/middleware/9-shared-state-middleware.ipynb) |
| Trade Execution Monitoring | Track trade execution latency with real-time monitoring | Agent Framework, Foundry Tracing | [1-agent-with-foundry-tracing.ipynb](agent-framework/observability/1-agent-with-foundry-tracing.ipynb) |
| Customer Service Monitoring | Monitor customer service interactions with automatic tracing | Agent Framework, Azure Monitor | [2-azure-ai-agent-observability.ipynb](agent-framework/observability/2-azure-ai-agent-observability.ipynb) |
| Loan Processing Pipeline Monitoring | Track loan stages: validation, credit check, approval | Agent Framework, Workflow Observability | [3-workflow-observability.ipynb](agent-framework/observability/3-workflow-observability.ipynb) |
| Compliance-Ready Conversation Audit | Store conversations in compliance-approved databases | Agent Framework, Custom Message Store | [1-custom-chat-message-store-thread.ipynb](agent-framework/threads/1-custom-chat-message-store-thread.ipynb) |
| Distributed Customer Session Management | Scale customer conversations across multiple instances | Agent Framework, Redis Message Store | [2-redis-chat-message-store-thread.ipynb](agent-framework/threads/2-redis-chat-message-store-thread.ipynb) |
| Insurance Claim Processing Continuity | Suspend and resume claim conversations across sessions | Agent Framework, Thread Suspend/Resume | [3-suspend-resume-thread.ipynb](agent-framework/threads/3-suspend-resume-thread.ipynb) |
| Credit Card Application Review | Real-time credit assessment with analyst and underwriter | Agent Framework, Streaming Workflows | [1-azure-ai-agents-streaming.ipynb](agent-framework/workflows/1-azure-ai-agents-streaming.ipynb) |
| Investment Portfolio Review | Real-time portfolio analysis and risk assessment | Agent Framework, Streaming Workflows | [2-azure-chat-agents-streaming.ipynb](agent-framework/workflows/2-azure-chat-agents-streaming.ipynb) |
| Loan Application Processing | Sequential processing with analyst and risk reviewer | Agent Framework, Sequential Workflows | [3-sequential-agents-loan-application.ipynb](agent-framework/workflows/3-sequential-agents-loan-application.ipynb) |
| Loan Advisory with Compliance | AI recommendations combined with regulatory disclosures | Agent Framework, Custom Executors | [4-sequential-custom-executors-compliance.ipynb](agent-framework/workflows/4-sequential-custom-executors-compliance.ipynb) |
| Credit Limit Review with Approval | AI proposes limits, human manager approves or adjusts | Agent Framework, Human-in-the-Loop | [5-credit-limit-with-human-input.ipynb](agent-framework/workflows/5-credit-limit-with-human-input.ipynb) |
| Large Transaction Authorization | Human escalation for high-value wire transfers | Agent Framework, Human Escalation | [6-workflow-as-agent-human-in-the-loop-transaction-review.ipynb](agent-framework/workflows/6-workflow-as-agent-human-in-the-loop-transaction-review.ipynb) |
| Investment Research with Compliance | Compliance oversight of research plans before execution | Agent Framework, Magentic Orchestration | [7-magentic-compliance-review-with-human-input.ipynb](agent-framework/workflows/7-magentic-compliance-review-with-human-input.ipynb) |
| Investment Research Report Generation | Multi-agent market research and quantitative analysis | Agent Framework, Magentic Multi-Agent | [8-magentic-investment-research.ipynb](agent-framework/workflows/8-magentic-investment-research.ipynb) |
| Customer Communication Quality | Ensure communications meet quality and compliance standards | Agent Framework, Reflection Pattern | [9-workflow-as-agent-reflection-pattern.ipynb](agent-framework/workflows/9-workflow-as-agent-reflection-pattern.ipynb) |
| Wealth Management Advisory Monitoring | Telemetry and tracing for investment guidance with audit | Azure AI Agents v2, OpenTelemetry | [1-telemetry.ipynb](observability-and-evaluations/1-telemetry.ipynb) |
| Loan Advisory Quality Testing | Evaluate agent responses for quality, safety, compliance | Azure AI Agents v2, Built-in Evaluators | [2-agent-evaluation.ipynb](observability-and-evaluations/2-agent-evaluation.ipynb) |
| Banking Assistant Evaluation | Evaluate tool-enabled agents for correct API usage | Azure AI Agents v2, Function Tools Evaluation | [3-agent-evaluation-with-function-tools.ipynb](observability-and-evaluations/3-agent-evaluation-with-function-tools.ipynb) |
| Banking Operations Tool Validation | Validate correct tool selection for banking operations | Azure AI Agents v2, Tool Call Accuracy | [4-tool-call-accuracy-evaluation.ipynb](observability-and-evaluations/4-tool-call-accuracy-evaluation.ipynb) |
| Banking AI Security Assessment | Identify vulnerabilities through adversarial attack simulations | Azure AI Agents v2, Red Team Testing | [5-red-team-security-testing.ipynb](observability-and-evaluations/5-red-team-security-testing.ipynb) |

---

## Getting Started

### Option A: Dev Container (Recommended)

Requires [Docker](https://docker.com) and [VS Code](https://code.visualstudio.com) with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

1. Clone the repository and open in VS Code
2. Press `F1` → **Dev Containers: Reopen in Container**
3. Wait for the container to build (~5 minutes on first run)

Python 3.12, Azure CLI, azd, and all dependencies are pre-installed. Your local Azure credentials are mounted automatically.

### Option B: Local Setup

```powershell
# Clone and enter the repository
git clone https://github.com/dhangerkapil/agentic-ai-immersion-day.git
cd agentic-ai-immersion-day

# Create and activate a virtual environment
python -m venv .venv
.\.venv\Scripts\activate

# Install pinned dependencies
pip install -r requirements.txt
```

### Provision Azure Resources

Run the provisioning script to create all required Azure resources and generate your `.env` file:

```powershell
./provision.ps1
```

To tear down all resources after the workshop:

```powershell
./teardown.ps1
```

### Configure Environment Variables

Copy `.env.example` to `.env`. The provisioning script populates this automatically. Manual configuration reference:

```env
AI_FOUNDRY_PROJECT_ENDPOINT=https://your-project.services.ai.azure.com
AZURE_OPENAI_API_KEY=your-api-key
AZURE_AI_MODEL_DEPLOYMENT_NAME=gpt-4o
BING_CONNECTION_ID=/subscriptions/.../connections/bing        # for notebook 4
AZURE_AI_SEARCH_ENDPOINT=https://your-search.search.windows.net  # for notebook 5
```

### Required Azure RBAC Roles

#### Core (all notebooks)

| Role | Assignee | Resource |
|------|----------|----------|
| Azure AI Developer | User | AI Foundry Project |
| Cognitive Services OpenAI User | User | AI Foundry Project |

#### File Search notebooks (3, 6)

| Role | Assignee | Resource |
|------|----------|----------|
| Storage Blob Data Contributor | User | Project Storage Account |

#### Azure AI Search notebooks (5, 8)

| Role | Assignee | Resource |
|------|----------|----------|
| Search Index Data Contributor | User | AI Search Resource |
| Search Index Data Reader | User | AI Search Resource |
| Search Service Contributor | User | AI Search Resource |
| Search Index Data Reader | **Project Managed Identity** | AI Search Resource |

> The managed identity role on notebook 8 (Foundry IQ) is critical — without it the agent runtime cannot query the knowledge base. Role assignments can take 5–10 minutes to propagate.

#### Role assignment commands

```powershell
$USER_PRINCIPAL_ID = (az ad signed-in-user show --query id -o tsv)
$PROJECT_SCOPE  = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.MachineLearningServices/workspaces/<project>"
$STORAGE_SCOPE  = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<storage>"
$SEARCH_SCOPE   = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Search/searchServices/<search>"

az role assignment create --role "Azure AI Developer"               --assignee $USER_PRINCIPAL_ID --scope $PROJECT_SCOPE
az role assignment create --role "Cognitive Services OpenAI User"   --assignee $USER_PRINCIPAL_ID --scope $PROJECT_SCOPE
az role assignment create --role "Storage Blob Data Contributor"    --assignee $USER_PRINCIPAL_ID --scope $STORAGE_SCOPE
az role assignment create --role "Search Index Data Contributor"    --assignee $USER_PRINCIPAL_ID --scope $SEARCH_SCOPE
az role assignment create --role "Search Index Data Reader"         --assignee $USER_PRINCIPAL_ID --scope $SEARCH_SCOPE
az role assignment create --role "Search Service Contributor"       --assignee $USER_PRINCIPAL_ID --scope $SEARCH_SCOPE

# Foundry IQ managed identity role (notebook 8)
$PROJECT_MI_ID = "<PROJECT_MANAGED_IDENTITY_PRINCIPAL_ID>"
az role assignment create --role "Search Index Data Reader" --assignee $PROJECT_MI_ID --scope $SEARCH_SCOPE
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Kernel not found | `python -m ipykernel install --user --name=ai-foundry-lab` then reload VS Code |
| Execution policy error | `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| Azure auth failure | `az login --tenant YOUR_TENANT_ID` |
| Package import errors | Confirm `agent-framework` packages are installed in the same interpreter as Jupyter |
| Application Insights delay | Use Live Metrics Stream for real-time debugging |

---

## Resources

| Resource | Link |
|----------|------|
| Microsoft Foundry Documentation | [learn.microsoft.com/azure/ai-foundry](https://learn.microsoft.com/en-us/azure/ai-foundry/) |
| Azure AI Agents Overview | [learn.microsoft.com/azure/ai-services/agents](https://learn.microsoft.com/en-us/azure/ai-services/agents/overview) |
| Agent Framework Documentation | [learn.microsoft.com/agent-framework](https://learn.microsoft.com/en-us/agent-framework/overview/agent-framework-overview) |
| GitHub Issues | [Report bugs or request features](https://github.com/dhangerkapil/agentic-ai-immersion/issues) |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for code style, testing requirements, and the PR process.

**License:** MIT
