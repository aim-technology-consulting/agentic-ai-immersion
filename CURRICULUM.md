# Agentic AI Immersion — Curriculum & Student Guide

This guide maps each hands-on use case to its notebook, explains what you will build and why it matters, and walks through every code block so you understand not just *what* runs but *why* it is written that way.

---

## How to Use This Guide

Work through the use cases **in order**. Each one builds on the patterns introduced before it. By the end you will have a complete picture of how production agentic systems are designed — from computed analytics and live platform integration through multi-agent orchestration, memory, and session continuity.

### Prerequisites

- Python 3.11+
- An Azure subscription with an AI Foundry project provisioned
- A `.env` file in the repo root populated with the values from your instructor (see `setup-env.sh`)
- Azure CLI installed and authenticated (`az login --use-device-code`)

---

## Learning Path Overview

| # | Use Case | Core Concept | Notebook |
|---|---|---|---|
| 1 | Financial Analytics Dashboard | Code execution inside an agent | `azure-ai-agents/2-code-interpreter.ipynb` |
| 2 | Financial Market Research | Real-time knowledge grounding | `azure-ai-agents/4-bing-grounding.ipynb` |
| 3 | Platform Operations Assistant | Live system integration via MCP | `azure-ai-agents/7-mcp-tools.ipynb` |
| 4 | Insurance Claims Processing | Multi-agent orchestration | `azure-ai-agents/6-multi-agent-solution-with-workflows.ipynb` |
| 5 | Personalized Banking Assistant | Cross-conversation memory | `azure-ai-agents/9-agent-memory-search.ipynb` |
| *bonus | Persistent Financial Advisor | Session continuity & thread management | `agent-framework/agents/azure-ai-agents/9-azure-ai-with-existing-multi-turn-thread.ipynb` |

---

## Use Case 1 — Financial Analytics Dashboard / Loan & Portfolio Calculator
### *Giving the agent the ability to compute*

**Notebook:** `azure-ai-agents/2-code-interpreter.ipynb`

### What You Will Build
A Loan Calculator Agent that generates amortization schedules, compares mortgage scenarios side-by-side, and analyzes a multi-loan portfolio — all by writing and executing Python code on the fly inside the conversation.

### Learning Objectives
- Attach `CodeInterpreterTool` to an agent and understand the `CodeInterpreterToolAuto` container
- Understand how the agent uses the formula `M = P * [r(1+r)^n] / [(1+r)^n - 1]` embedded in its instructions as a grounding reference
- Observe how a single natural-language prompt triggers structured Python computation
- Recognize that portfolio data is passed inline in the prompt, not read from a file by the agent

### Key Concepts
| Concept | What It Means |
|---|---|
| **Code Interpreter** | A built-in tool that lets the agent write and execute Python in a sandboxed environment |
| **`CodeInterpreterToolAuto`** | The container configuration that provisions the sandbox automatically |
| **Tool call / tool output** | The agent emits a tool call; the platform executes it and returns stdout + any generated files |
| **Run steps** | The granular execution log — lets you see exactly what Python the agent wrote and ran |
| **Inline data prompt** | Passing structured data as text inside the user message so the agent can compute against it |

---

### Notebook Walkthrough

#### Cell 1 — Import libraries, authenticate, and create sample loan data
Imports standard libraries plus `InteractiveBrowserCredential`, `AIProjectClient`, `PromptAgentDefinition`, `CodeInterpreterTool`, and `CodeInterpreterToolAuto`. Loads `.env` from two directories up (`parent.parent / '.env'`). Creates both `project_client` and `openai_client` in this cell — you need both, the project client to manage agent lifecycle and the OpenAI client to drive conversations. Then calls `create_sample_data()`, which writes a `loan_portfolio.json` file with seven loans: John Smith (Mortgage, $350k, 6.5%, 30yr, Current), Sarah Johnson (Auto, $45k, 7.2%, 5yr, Current), Mike Chen (Personal, $25k, 9.5%, 3yr, Current), Emily Davis (Mortgage, $500k, 6.25%, 15yr, Current), Robert Wilson (Business, $150k, 8.0%, 7yr, 30 Days Late), Lisa Anderson (Home Equity, $75k, 7.5%, 10yr, Current), and David Brown (Auto, $32k, 6.9%, 4yr, 60 Days Late). This file is not uploaded to the agent — it is referenced when building the portfolio analysis prompt in Cell 5.

#### Cell 2 — Create the Loan Calculator agent with `CodeInterpreterTool`
Instantiates `CodeInterpreterTool(container=CodeInterpreterToolAuto())` — the `container` parameter is required and `CodeInterpreterToolAuto` tells Foundry to provision the sandbox automatically. Creates a `PromptAgentDefinition` with the agent named `"loan-calculator-agent"` and instructions that embed the amortization formula `M = P * [r(1+r)^n] / [(1+r)^n - 1]` so the agent references it correctly in generated code. Attaches the tool via the `tools=[code_interpreter_tool]` parameter and calls `create_version()`.

#### Cell 3 — Define `calculate_loan_with_agent()` and run a $350k mortgage scenario
Creates a conversation with `openai_client.conversations.create()`, then sends a structured prompt asking the agent to: calculate the monthly payment, total amount paid, total interest paid, and show the first 12 months of the amortization schedule — all using Python code. The specific test case is $350,000 at 6.5% for 30 years. Calls `openai_client.responses.create()` with the conversation ID and an agent reference body. The agent writes Python, executes it in the sandbox, and returns computed results.

#### Cell 4 — Define `compare_loan_options()` and request a three-way mortgage comparison
Creates a fresh conversation and sends a prompt comparing three options on a **$400,000** loan: 30-year fixed at 6.5%, 15-year fixed at 5.75%, and 20-year fixed at 6.25%. Asks the agent to compute monthly payments, total interest for each, interest savings from shorter terms, and a comparison table. The agent loops through all three scenarios in a single code block. Notice the conversation is a new one — each function call is independent, not a continuation of Cell 3.

#### Cell 5 — Define `analyze_loan_portfolio()` and request portfolio-level risk metrics
Creates a conversation and passes the seven-loan portfolio as a **formatted markdown table directly in the prompt** — the JSON file from Cell 1 is not passed to the agent. Asks for: total portfolio value, weighted average interest rate, expected monthly revenue, identification of at-risk loans (Robert Wilson 30-days late, David Brown 60-days late), breakdown by loan type, delinquency rate percentage, and risk recommendations. The agent writes Python to parse the table and compute all metrics.

#### Cell 6 — `cleanup_all()`: delete agent and local file
Calls `project_client.agents.delete_version(agent_name=loan_agent.name, agent_version=loan_agent.version)` to remove the agent and `os.remove(sample_file)` to delete the local JSON. Both operations are wrapped in individual try/except blocks so one failure does not prevent the other. Cleanup is called immediately by default — comment it out if you want to continue experimenting.

---

### Reflection Questions
1. Cell 5 passes portfolio data inline rather than uploading the JSON file. What are the trade-offs of each approach?
2. The amortization formula is written into the agent's instructions. What happens if you remove it — does the agent still compute correctly, and does that change how much you trust the output?

---

## Use Case 2 — Financial Market Research
### *Getting the right information to the agent at the right moment*

**Notebook:** `azure-ai-agents/4-bing-grounding.ipynb`

### What You Will Build
A Market Research Agent that answers questions about Federal Reserve decisions, banking sector performance, and inflation forecasts by performing live Bing web searches — grounding every response in current sources rather than model training data.

### Learning Objectives
- Distinguish **grounding** (retrieved context injected at inference time) from **native knowledge** (model training data, which may be months old)
- Configure `BingGroundingAgentTool` using `BingGroundingSearchToolParameters` and `BingGroundingSearchConfiguration`
- Understand the `GROUNDING_WITH_BING_CONNECTION_NAME` env var and why the connection must be pre-registered in the Foundry portal
- Observe the graceful fallback pattern when the Bing connection is unavailable

### Key Concepts
| Concept | What It Means |
|---|---|
| **Grounding** | Retrieving external facts and injecting them into the model's context before generation |
| **`BingGroundingAgentTool`** | The tool class that attaches Bing search capability to an agent |
| **`BingGroundingSearchConfiguration`** | Holds the `project_connection_id` that links to the registered Bing connection in Foundry |
| **Graceful fallback** | If the Bing connection is missing or fails, the notebook creates an agent without grounding so the rest of the cells still run |
| **Model requirement** | Bing grounding requires a supported model (e.g., `gpt-4o-0513`) and the `"x-ms-enable-preview": "true"` header |

---

### Notebook Walkthrough

#### Cell 1 — Import libraries and initialize `AIProjectClient`
Imports `BingGroundingAgentTool`, `BingGroundingSearchToolParameters`, and `BingGroundingSearchConfiguration` alongside the standard Azure SDK. Uses `InteractiveBrowserCredential(tenant_id=tenant_id)` — browser-based auth is chosen here because Azure CLI credential caching can interfere with Foundry connection lookups in some environments. Loads `.env` from `parent.parent / '.env'`.

#### Cell 2 — `create_bing_grounded_agent()`: create agent with Bing tool or fallback
The function first checks if `GROUNDING_WITH_BING_CONNECTION_NAME` is set in `.env`. If it is not set, it creates an agent **without** grounding and prints a warning — this lets you still run Cells 3 and 4 even without a Bing connection. If the variable is set, it calls `project_client.connections.get(name=bing_conn_name)` to retrieve the connection object and extracts `conn_id`. If that lookup fails, it lists all available connections via `project_client.connections.list()` to help with debugging. When the connection is found, it builds the tool with the nested structure: `BingGroundingAgentTool(bing_grounding=BingGroundingSearchToolParameters(search_configurations=[BingGroundingSearchConfiguration(project_connection_id=conn_id)]))` — the `search_configurations` must be a list with exactly one element. Creates the agent named `"financial-market-research-agent"` with instructions to use Bing for current data, include source citations, and never recommend specific investments.

#### Cell 3 — `ask_financial_research_question()` and three market research queries
Defines a helper that creates a conversation (or reuses one via `conversation_id`), then calls `openai_client.responses.create()` with the agent reference. Loops through three hardcoded research questions: (1) Federal Reserve interest rate decisions and their impact on mortgage rates, (2) latest trends in banking sector performance and major bank stock movements, (3) what financial experts are saying about inflation forecasts for the upcoming year. Appends each `(conversation_id, response)` tuple to `bing_responses` for inspection. The agent internally decides to call Bing for each question and incorporates the retrieved content with inline citations.

#### Cell 4 — `cleanup_bing_agent()` and best practices
Calls `project_client.agents.delete_version(agent_name=agent.name, agent_version=agent.version)`. The markdown above the cell documents four production considerations worth reading: (1) always verify Bing citation accuracy before showing users, (2) Bing's display requirements mean you should show both website URLs and Bing search query URLs, (3) watch for rate limits, and (4) filter search queries to avoid sending sensitive customer data to Bing.

---

### Reflection Questions
1. Cell 2 lists all available connections when the named connection fails. Why is this more useful than a simple error message?
2. The agent answers from training data when Bing is unavailable. For what categories of financial questions does this matter most, and for which does it matter least?

---

## Use Case 3 — Platform Operations Assistant
### *How agents reach into your own platforms during a conversation*

**Notebook:** `azure-ai-agents/7-mcp-tools.ipynb`

### What You Will Build
An AI Development Assistant connected to the Foundry MCP Server at `https://mcp.ai.azure.com` — an agent that can discover and invoke Foundry platform tools at runtime for model exploration, deployment guidance, evaluation workflows, and agent management.

### Learning Objectives
- Understand MCP (Model Context Protocol) and why a hosted server removes the need to hardcode tool schemas
- Configure `MCPTool` with `server_label`, `server_url`, `require_approval`, and `project_connection_id`
- Understand the `process_mcp_response()` approval loop: why it exists and how `previous_response_id` chains the approval back to the original request
- Recognize the difference between `require_approval="never"` (demo mode) and `require_approval="always"` (production mode)

### Key Concepts
| Concept | What It Means |
|---|---|
| **MCP (Model Context Protocol)** | An open standard for exposing tools and resources to AI agents via a discoverable server |
| **Foundry MCP Server** | A cloud-hosted MCP service at `https://mcp.ai.azure.com` providing model catalog, deployment, evaluation, and agent management tools |
| **SSE transport** | Server-Sent Events — the persistent HTTP connection over which the MCP server streams tool listings and results |
| **`project_connection_id`** | The connection ID registered in the Foundry portal; carries OAuth/Entra ID credentials so no secrets appear in code |
| **Approval loop** | When an MCP tool call is pending, the client sends an `McpApprovalResponse` referencing the original `approval_request_id` and re-submits using `previous_response_id` |
| **Tool discovery** | The agent reads the tool catalog from the MCP server at runtime — no schemas are hardcoded in your code |

---

### Notebook Walkthrough

#### Cell 1 — Import libraries and read `FOUNDRY_MCP_CONNECTION_ID`
Imports `MCPTool` from `azure.ai.projects.models` and `McpApprovalResponse` and `ResponseInputParam` from `openai.types.responses.response_input_param`. Loads `.env` from `parent.parent / '.env'` and prints all four configuration values: tenant ID, project endpoint, model deployment, and `FOUNDRY_MCP_CONNECTION_ID`. Uses `AzureCliCredential` (not browser-based) — MCP connections use service principal credentials that Azure CLI manages automatically.

#### Cell 2 — Initialize `AIProjectClient` with `AzureCliCredential`
Creates `credential = AzureCliCredential(tenant_id=tenant_id)`, then `project_client` and `openai_client`. The comment in the cell is a reminder to run `az login` before executing — without a valid CLI session, the credential will fail silently at the first API call rather than here.

#### Cell 3 — Configure `MCPTool` for the Foundry MCP Server
Creates `MCPTool(server_label="foundry-mcp", server_url="https://mcp.ai.azure.com/sse", require_approval="never", project_connection_id=foundry_mcp_connection_id)`. `require_approval="never"` means all MCP tool calls execute automatically in this demo — no user input required. The `/sse` suffix on the URL is the SSE endpoint; the server pushes tool listings and execution results over this persistent connection. The `project_connection_id` is the value from the Foundry portal that stores the OAuth credentials — your code never handles tokens directly.

#### Cell 4 — Define agent instructions and create the agent
Sets `agent_name = "foundry-mcp-assistant"` and writes instructions positioning the agent as an AI Development Assistant with five capability areas: model exploration, deployment and quota management, evaluation orchestration, agent lifecycle management, and Azure AI Search knowledge bases. Calls `project_client.agents.create_version()` with a `PromptAgentDefinition` attaching `mcp_tool`. At runtime the agent discovers the tool catalog from the MCP server dynamically — the instructions describe *what the agent can help with*, not what tools it has access to.

#### Cell 5 — Create a conversation
Calls `openai_client.conversations.create()` and stores the ID. This conversation is reused across Cells 6 and 7, giving the agent context from earlier turns when answering later questions.

#### Cell 6 — Define `process_mcp_response()` and run three queries
The function iterates over `response.output`, checks each item for `item.type == "mcp_approval_request"`, and auto-approves by sending `McpApprovalResponse(type="mcp_approval_response", approve=True, approval_request_id=item.id)` back via `openai_client.responses.create(input=approval_requests, previous_response_id=response.id, ...)`. The `previous_response_id` is what chains the approval to the right pending request. The three queries sent are: (1) "What AI models would you recommend for document analysis use cases?", (2) "Explain how the Foundry MCP Server helps with AI development workflows.", (3) "What security features does the Foundry MCP Server provide for enterprise use?" — these are realistic AI development questions, not direct tool invocations.

#### Cell 7 — Execute a custom query
Sends: "What capabilities does the Foundry MCP Server provide for building AI agents?" through the same conversation. This question exercises the agent's ability to describe its own tool catalog — the MCP server exposes a `list_tools` operation that the agent can call to introspect its own capabilities.

#### Cell 8 — Cleanup
Calls `project_client.agents.delete_version(agent_name=agent.name, agent_version=agent.version)`.

---

### Reflection Questions
1. `require_approval="never"` is used in this demo. What kinds of MCP operations would warrant switching to `"always"` in production, and what would the user experience look like?
2. The `project_connection_id` stores credentials in the Foundry portal rather than in your code. What security problem does this solve compared to passing an API key directly?

---

## Use Case 4 — Insurance Claims Processing
### *How to coordinate teams of specialist agents on complex tasks*

**Notebook:** `azure-ai-agents/6-multi-agent-solution-with-workflows.ipynb`

### What You Will Build
A multi-agent claims processing system where four specialist agents collaborate through a YAML-declared workflow — a Validity Agent, Department Assignment Agent, Payout Estimation Agent, and Claims Orchestrator — all exposed as a single `WorkflowAgentDefinition` that a caller interacts with like any other agent.

### Learning Objectives
- Understand why specialist agents with narrow scopes produce more reliable output than one agent doing everything
- Write a YAML workflow using `SetVariable`, `InvokeAzureAgent`, and `EndConversation` actions
- Understand why all agents run in the **main conversation** — so the orchestrator sees the full accumulated history when it synthesizes
- Stream workflow execution events using `ResponseStreamEventType` to observe each agent firing in sequence

### Key Concepts
| Concept | What It Means |
|---|---|
| **`WorkflowAgentDefinition`** | Wraps a YAML workflow as a single deployable agent — callers send one message and get one synthesized response |
| **YAML declarative workflow** | Workflow logic defined in configuration, not Python — readable and editable without SDK knowledge |
| **`SetVariable`** | A workflow action that captures the incoming user message into a variable for downstream agents |
| **`InvokeAzureAgent`** | A workflow action that calls a named agent and injects its output into the main conversation |
| **`EndConversation`** | Terminates the workflow after the orchestrator delivers its final report |
| **Main conversation context** | All `InvokeAzureAgent` actions run in the same conversation, so the orchestrator sees every specialist's output when it synthesizes |

---

### Notebook Walkthrough

#### Cell 1 — Import libraries and load environment
Imports `AIProjectClient`, `PromptAgentDefinition`, `WorkflowAgentDefinition`, `ResponseStreamEventType`, and `ItemType`. Uses `AzureCliCredential()` without a `tenant_id` argument — the credential uses whatever tenant is active in the CLI session. Loads `.env` from `parent_dir / '.env'` (one level up, not two).

#### Cells 2–5 — Define four specialist agent instruction strings
Four plain strings are written before any SDK calls. Each string defines one specialist's behavior with explicit output constraints:
- **Validity Agent** (`"claim-validity-agent"`): Returns exactly one of three statuses — *Valid*, *Requires Review*, or *Denied* — plus a brief explanation
- **Department Agent** (`"department-assignment-agent"`): Routes to Auto, Home, Life, Health, or Commercial Claims based on incident type
- **Payout Agent** (`"payout-estimation-agent"`): Returns Low (<$5,000), Medium ($5,000–$25,000), or High (>$25,000) with justification
- **Orchestrator Agent** (`"claims-orchestrator-agent"`): Reads the full conversation history, identifies inconsistencies, and formats its output as a structured report with six sections: CLAIM SUMMARY, VALIDITY STATUS, ASSIGNED DEPARTMENT, PAYOUT ESTIMATE, FINAL RECOMMENDATION, NEXT STEPS

Writing instructions before agent creation keeps each definition readable and easy to tune without touching SDK calls.

#### Cell 6 — Initialize `AIProjectClient` and `openai_client`
Creates `credential = AzureCliCredential()` and `project_client`. Retrieves `openai_client` via `project_client.get_openai_client()`. Both clients are needed — the project client manages agent creation and deletion; the OpenAI client runs conversations and streaming.

#### Cell 7 — Create all four specialist agents
Calls `project_client.agents.create_version()` four times, each producing a named, versioned agent in Foundry. Deploying them separately means each can be updated, tested, and monitored independently of the workflow.

#### Cell 8 — Build the YAML workflow
Constructs the workflow YAML as an f-string interpolating each agent's `.name` property. The action sequence is:
1. `SetVariable` — stores `System.LastMessageText` into `Local.LatestMessage`
2. `InvokeAzureAgent` (validity) — sends `Local.LatestMessage` to the validity agent
3. `InvokeAzureAgent` (department) — sends `Local.LatestMessage` to the department agent
4. `InvokeAzureAgent` (payout) — sends `Local.LatestMessage` to the payout agent
5. `InvokeAzureAgent` (orchestrator) — sends a fixed synthesis prompt: *"Now synthesize all the above assessments into a comprehensive claims report."*
6. `EndConversation` — terminates the workflow

All agents run in the main conversation so the orchestrator at step 5 has the full accumulated transcript — validity output, department output, and payout output — as context before it writes the final report.

#### Cell 9 — Create the `WorkflowAgentDefinition`
Passes the YAML string to `project_client.agents.create_version()` wrapped in `WorkflowAgentDefinition(workflow=workflow_yaml)`. The resulting agent `"claims-processing-workflow"` is what callers interact with — they send a claim and receive a synthesized report. Foundry executes the YAML internally; the caller never knows there are five agents.

#### Cell 10 — Define two sample insurance claims
Two claim strings are created as multiline text including Claim ID, Policy Type, Incident date, Description, and financial details. CLM-2024-001 is an auto collision with $3,200 estimated damage and a $500 deductible. CLM-2024-002 is a burst pipe/water damage case with $15,000 estimated damage and a $250,000 policy limit.

#### Cell 11 — `process_claim_with_workflow()` and streaming execution
Creates a conversation, then calls `openai_client.responses.create()` with `stream=True`. The streaming loop handles six `ResponseStreamEventType` variants: `RESPONSE_OUTPUT_ITEM_ADDED` (prints which action started), `RESPONSE_OUTPUT_ITEM_DONE` (prints which action completed and captures any output), `RESPONSE_OUTPUT_TEXT_DELTA` (accumulates text delta into `final_output`), `RESPONSE_CONTENT_PART_ADDED`, `RESPONSE_CONTENT_PART_DONE`, and `RESPONSE_COMPLETED` (extracts `output_text` from the final response object). After processing, the conversation is deleted with `openai_client.conversations.delete(conversation_id=conversation.id)`. Both sample claims are processed and results printed.

#### Cell 12 — Cleanup: delete all five agents
Calls `delete_version()` for all five agents in order: workflow agent first, then the four specialists. Deleting the workflow agent first avoids a state where the workflow exists but its referenced specialist agents do not.

---

### Reflection Questions
1. All specialist agents run in the main conversation so the orchestrator sees their outputs. What would break if each specialist ran in its own isolated sub-conversation instead?
2. The payout scale uses fixed dollar thresholds ($5k/$25k). For a real claims system, where should those thresholds come from, and how would you make them configurable without redeploying the agent?

---

## Use Case 5 — Personalized Banking Assistant
### *Agents that remember across turns, sessions, and instances*

**Notebook:** `azure-ai-agents/9-agent-memory-search.ipynb`

### What You Will Build
A Personalized Banking Advisor that extracts and stores customer preferences (age, risk tolerance, investment capacity, emergency fund goals) from conversations, then retrieves those memories in completely new conversations to deliver personalized guidance without the customer repeating themselves.

### Learning Objectives
- Create a `MemoryStoreDefaultDefinition` with `user_profile_enabled` and `chat_summary_enabled` options
- Configure `MemorySearchTool` with a `scope` (customer ID) and `update_delay` to isolate and control when memories are extracted
- Run four sequential conversations that demonstrate: preference capture, memory recall, preference update, and update verification
- Understand what the `update_delay` represents and why production values are much higher than the 5-second demo value

### Key Concepts
| Concept | What It Means |
|---|---|
| **Memory Store** | External persistent storage for extracted preferences and conversation summaries |
| **`MemoryStoreDefaultDefinition`** | Configures the store with a chat model (for extraction) and an embedding model (for semantic search) |
| **`MemoryStoreDefaultOptions`** | Enables `user_profile_enabled` (preferences and traits) and `chat_summary_enabled` (conversation highlights) |
| **`MemorySearchTool`** | The agent tool that searches the store at the start of each conversation and queues memory extraction after inactivity |
| **`scope`** | The customer identifier — memories are isolated per scope so different customers cannot see each other's data |
| **`update_delay`** | Seconds of inactivity before the agent extracts and writes new memories; 5s in demo, minutes or hours in production |

---

### Notebook Walkthrough

#### Cell 1 — Package check
Prints "Packages ready" and notes that `azure-ai-projects>=2.0.0b1`, `azure-identity`, `openai`, and `python-dotenv` should already be installed via `requirements.txt`. Uncomment the `%pip install` line only if packages are missing.

#### Cell 2 — Load environment and initialize clients
Imports `MemoryStoreDefaultDefinition`, `MemorySearchTool`, `MemoryStoreDefaultOptions`, and `PromptAgentDefinition`. Reads four env vars: `TENANT_ID`, `AI_FOUNDRY_PROJECT_ENDPOINT`, `AZURE_AI_MODEL_DEPLOYMENT_NAME` (used for both agent chat and memory extraction), and `EMBEDDING_MODEL_DEPLOYMENT_NAME` (used for semantic search over stored memories — defaults to `"text-embedding-3-large"`). Creates `AIProjectClient` with `AzureCliCredential(tenant_id=tenant_id)` and retrieves `openai_client`.

#### Cell 3 — Create the memory store
First attempts `project_client.memory_stores.delete(memory_store_name)` and catches `ResourceNotFoundError` — this ensures each notebook run starts with a clean store rather than accumulating memories from previous runs. Then creates `MemoryStoreDefaultDefinition(chat_model=memory_chat_model, embedding_model=memory_embedding_model, options=MemoryStoreDefaultOptions(user_profile_enabled=True, chat_summary_enabled=True))` and calls `project_client.memory_stores.create(name="banking-customer-memory-store", description=..., definition=memory_definition)`. The two models serve different roles: the chat model reads conversations and extracts facts worth remembering; the embedding model converts those facts into vectors so they can be retrieved by semantic similarity later.

#### Cell 4 — Configure `MemorySearchTool`
Sets `customer_id = "customer_john_doe_12345"` — in production this would be a real customer identifier or `"{{$userId}}"` for automatic authenticated-user scoping. Creates `MemorySearchTool(memory_store_name=memory_store.name, scope=customer_id, update_delay=5)`. The `update_delay=5` means the agent waits 5 seconds of inactivity before triggering memory extraction — low enough for a demo but too aggressive for a real deployment where customers pause mid-sentence.

#### Cell 5 — Create the memory-enabled banking agent
Writes detailed instructions that explicitly tell the agent how to use memory: reference stored preferences with phrases like *"Based on your preference for low-risk investments..."*, ask clarifying questions when memories are missing, and personalize product recommendations based on the stored profile. Includes example interactions showing first-conversation capture vs. subsequent-conversation recall. Creates `project_client.agents.create_version()` with `PromptAgentDefinition` attaching `tools=[memory_tool]` — this is the only change from a non-memory agent.

#### Cell 6 — Define `chat_with_agent()` and run Conversation 1 (preference capture)
`chat_with_agent()` is a thin wrapper around `openai_client.responses.create()` passing `input`, `conversation`, and the agent reference body. Creates `conversation1` and sends three messages that establish the customer profile: "I'm a new customer. I'm 45 years old and I prefer conservative, low-risk investments. I'm saving for retirement in about 20 years." then emergency fund preference (6 months of expenses, liquid savings) and income/investment capacity ($120,000 annual income, $1,500/month available to invest).

#### Cell 7 — Wait 30 seconds for memory extraction
`wait_time = 30` seconds; counts down in 5-second increments. This simulates the `update_delay` period during which the agent extracts preference facts from Conversation 1 and writes them to the memory store. The delay happens server-side — the sleep here just makes the timing visible.

#### Cell 8 — Conversation 2: memory recall test
Creates a brand-new conversation (`conversation2`) with no shared thread to Conversation 1. Sends three questions: (1) "Hi, I spoke with someone earlier. Can you recommend some investment options for me?", (2) "What about my emergency fund? How should I set that up?", (3) "Given my situation, should I max out my 401k contributions?" The agent retrieves stored memories before responding, so it answers using the customer's known age, risk tolerance, retirement timeline, emergency fund preference, and investment capacity — without the customer re-stating any of it.

#### Cell 9 — Conversation 3: preference update
Creates `conversation3` and sends two messages that change the stored profile: (1) "I've been thinking, and I'd like to be a bit more aggressive with my investments. I can handle moderate risk now." (2) "I also got a raise! My income is now $140,000 and I can invest $2,000 per month." Waits 15 seconds for these updated facts to be extracted, overwriting the earlier conservative/lower-income profile.

#### Cell 10 — Conversation 4: verify updated memories
Creates `conversation4` and sends a single message: "Based on everything you know about me, what's your top investment recommendation right now?" The agent should now reference the **updated** profile — moderate risk, $140k income, $2k/month capacity — not the original conservative/lower values from Conversation 1.

#### Cell 11 — Cleanup
Deletes all four conversations, the agent with `delete_version()`, and the memory store with `project_client.memory_stores.delete()`. Each deletion is wrapped in its own try/except so one failure doesn't abort the rest.

---

### Reflection Questions
1. The store is deleted and recreated at the start of each run to ensure a clean demo. In a production system, when would you actually delete a customer's memory store, and who should be able to trigger that action?
2. `update_delay=5` seconds is used here. What problems would a 5-second delay cause in a real customer service scenario, and how would you choose the right production value?

---

## Use Case 6 — Persistent Financial Advisor *(bonus)*
### *Agents that survive across turns, deployments, and infrastructure*

**Notebook:** `agent-framework/agents/azure-ai-agents/9-azure-ai-with-existing-multi-turn-thread.ipynb`

### What You Will Build
A Loan Application Advisor using the `agent_framework` SDK layer (`AzureAIAgentsProvider`) that creates a persistent Azure-managed thread, attaches an agent to it by thread ID, and runs a multi-turn mortgage consultation where each message builds on prior context without any re-stating.

### Learning Objectives
- Use `AzureAIAgentsProvider` and `AgentsClient` from the `agent_framework` package (the higher-level SDK layer, distinct from `AIProjectClient`)
- Create a thread first with `agents_client.threads.create()`, then attach an agent to it via `agent.get_new_thread(service_thread_id=...)`
- Understand `thread.is_initialized` as a validation assertion before running turns
- Use async context managers (`async with`) for all three clients and always delete threads in a `finally` block

### Key Concepts
| Concept | What It Means |
|---|---|
| **`AzureAIAgentsProvider`** | The higher-level `agent_framework` wrapper around `AgentsClient` that simplifies agent creation and tool binding |
| **`AgentsClient`** | The low-level async client for Azure AI Agent Service — manages threads and runs directly |
| **Thread-first pattern** | Create the thread with `AgentsClient` before creating the agent, then attach by ID — the thread can outlive agent versions |
| **`agent.get_new_thread(service_thread_id=...)`** | Attaches an existing Azure-managed thread to an agent instance; thread history is stored server-side |
| **`thread.is_initialized`** | A boolean you can assert to confirm the thread attachment succeeded before running queries |
| **`finally` cleanup** | Threads are always deleted in a `finally` block so they are cleaned up even if a run raises an exception |

---

### Notebook Walkthrough

#### Cell 1 — Import libraries and load environment
Imports `AzureAIAgentsProvider` from `agent_framework.azure`, `AgentsClient` from `azure.ai.agents.aio` (async), and `AzureCliCredential` from `azure.identity.aio` (async version). Also imports `Annotated` and `Field` from Pydantic for function tool definitions. Loads from `'../../.env'` (two levels up from the notebook). Prints endpoint and model to confirm environment is configured.

#### Cell 2 — Verify `AI_FOUNDRY_PROJECT_ENDPOINT`
Reads the endpoint variable and prints a confirmation or an actionable error message. This guard prevents confusing `None`-type errors deeper in the notebook.

#### Cell 3 — Define two banking function tools
`get_loan_prequalification(loan_amount, credit_score, annual_income)`: computes a simplified debt-to-income ratio as `loan_amount / (annual_income * 30)`. Three outcome branches: credit ≥ 700 and DTI < 0.43 → "Pre-Qualified ✅" with 5.99%–6.75% rate range; credit ≥ 650 and DTI < 0.50 → "Conditionally Pre-Qualified ⚠️" with 7.25%–8.50%; else "Additional Review Required 📋" with 8.50%–12.00%. Returns a formatted multi-line string. `get_required_documents(loan_type)`: a lookup dictionary keyed on `"mortgage"`, `"auto"`, and `"personal"`. Mortgage requires 7 document types (ID, pay stubs, two years of W-2s and tax returns, bank statements, proof of assets, property info); auto requires 4; personal requires 3. Returns "Please specify: mortgage, auto, or personal loan" for unknown types. Both use `Annotated` type hints with `Field(description=...)` — the framework generates the JSON schema the model needs to call the function from these annotations.

#### Cell 4 — `main()`: single-turn thread example
An `async def` using three nested `async with` context managers: `AzureCliCredential()`, `AgentsClient(endpoint=..., credential=credential)`, and `AzureAIAgentsProvider(agents_client=agents_client)`. Creates a thread first: `created_thread = await agents_client.threads.create()`. Creates the agent with `provider.create_agent(name="LoanApplicationAdvisor", instructions=..., tools=[get_loan_prequalification, get_required_documents])`. Attaches to the existing thread: `thread = agent.get_new_thread(service_thread_id=created_thread.id)`. Asserts `thread.is_initialized`. Sends one mortgage prequalification query: "I'm interested in applying for a mortgage. Can you check if I'd prequalify for $350,000 with a credit score of 720 and annual income of $95,000?" Deletes the thread in a `finally` block regardless of outcome.

#### Cell 5 — `await main()`
Runs the async function in the Jupyter event loop.

#### Cell 6 — `multi_turn_loan_application()`: four-turn conversation
Creates a new thread and a new `LoanApplicationAdvisor` agent with the same tools and more comprehensive instructions. Runs four sequential messages through the same thread: (1) "Hi, I'm looking to buy my first home and need information about mortgage options." (2) "Can you check if I'd prequalify? My credit score is 680, annual income is $72,000, and I'm looking at homes around $280,000." (3) "Based on my prequalification status, what documents would I need for a conventional mortgage?" (4) "Given my situation, would you recommend I improve my credit score first before applying?" Each turn calls `await advisor.run(message, thread=thread)`. The thread context means the advisor's answer to turn 3 references the specific prequalification result from turn 2, and turn 4 references the full picture. Deletes the thread in `finally`.

#### Cell 7 — `await multi_turn_loan_application()`
Executes the multi-turn conversation and prints the advisor's response to each of the four turns.

---

### Reflection Questions
1. `main()` creates the thread with `AgentsClient` before creating the agent. What does this ordering enable that would not be possible if the thread were created inside `provider.create_agent()`?
2. The DTI formula `loan_amount / (annual_income * 30)` is a simplification. What does the `/30` represent, and how would you change the tool to use a more accurate debt-to-income calculation?

---

## Capstone: Putting It All Together

After completing all use cases, consider how each capability composes into a production system:

```
User message
    │
    ▼
Persistent thread (Azure-managed) ──── memory retrieval (cross-session preferences)
    │
    ▼
Orchestrator agent  ←── YAML workflow coordinates specialists
    ├── Specialist: Research  (Bing Grounding — live market data)
    ├── Specialist: Analytics (Code Interpreter — loan calculations)
    └── Specialist: Operations (MCP tools — platform actions)
    │
    ▼
Human-in-the-loop approval (MCP require_approval="always" for high-risk actions)
    │
    ▼
Synthesized response with citations, computed results, and tool call audit trail
```

Each layer maps directly to one use case you completed.

---

## Quick Reference — Notebook Index

| Notebook | Use Case | Core Pattern |
|---|---|---|
| `azure-ai-agents/2-code-interpreter.ipynb` | Financial Analytics Dashboard | `CodeInterpreterTool` + `CodeInterpreterToolAuto` |
| `azure-ai-agents/4-bing-grounding.ipynb` | Financial Market Research | `BingGroundingAgentTool` + `BingGroundingSearchConfiguration` |
| `azure-ai-agents/7-mcp-tools.ipynb` | Platform Operations Assistant | `MCPTool` + `McpApprovalResponse` approval loop |
| `azure-ai-agents/6-multi-agent-solution-with-workflows.ipynb` | Insurance Claims Processing | `WorkflowAgentDefinition` + YAML `InvokeAzureAgent` |
| `azure-ai-agents/9-agent-memory-search.ipynb` | Personalized Banking Assistant | `MemorySearchTool` + `MemoryStoreDefaultDefinition` |
| `agent-framework/agents/azure-ai-agents/9-azure-ai-with-existing-multi-turn-thread.ipynb` | Persistent Financial Advisor | `AzureAIAgentsProvider` + `service_thread_id` attachment |
