# Workshop Curriculum Guide

Six notebooks, in order. Each builds on patterns introduced before it: external platform integration, stateful session management, sandboxed computation, live data grounding, cross-session memory, and persistent agent lifecycle.

---

## Learning Path Overview

| # | Use Case | Core Concept | Notebook |
|---|---|---|---|
| 1 | Platform Operations Assistant | External tool integration via MCP | `azure-ai-agents/7-mcp-tools.ipynb` |
| 2 | Insurance Claim Processing Continuity | Session suspend and resume | `agent-framework/threads/3-suspend-resume-thread.ipynb` |
| 3 | Financial Analytics Dashboard | Sandboxed Python execution inside the agent | `agent-framework/agents/azure-ai-agents/5-azure-ai-with-code-interpreter.ipynb` |
| 4 | Financial Market Research Portal | Live web grounding via Bing | `agent-framework/agents/azure-ai-agents/7-azure-ai-with-bing-grounding.ipynb` |
| 5 | Personalized Banking Assistant | Cross-session memory and preference recall | `azure-ai-agents/9-agent-memory-search.ipynb` |
| 6 | Persistent Financial Advisor | Registering and reusing a pre-existing agent | `agent-framework/agents/azure-ai-agents/3-azure-ai-with-existing-ai-agent.ipynb` |

---

## Use Case 1 — Platform Operations Assistant
### Connecting the agent to live platform capabilities via MCP

**Notebook:** `azure-ai-agents/7-mcp-tools.ipynb`

### What You Will Build

An AI Technology Advisor that connects to the **Microsoft Learn MCP Server** — a public, no-auth Model Context Protocol service at `https://learn.microsoft.com/api/mcp` — to answer questions about Microsoft Foundry models, AI concepts, and Azure services using official, up-to-date Microsoft documentation. The agent discovers its tool catalog at runtime from the server; no tool schemas are hardcoded in your code.

### Learning Objectives
- Configure `MCPTool` with `server_label`, `server_url`, and `require_approval` for a public MCP server
- Understand that `project_connection_id` is only required when the server needs credentials stored in Foundry — public servers need none
- Understand the MCP approval loop: detect `mcp_approval_request` in a response and send `McpApprovalResponse` using `previous_response_id` to chain it back
- Use `openai_client.responses.create()` with the `extra_body` agent reference pattern

### Key Concepts

| Concept | What It Means |
|---------|---------------|
| MCP (Model Context Protocol) | An open protocol for exposing tools to agents via a discoverable server; tools are listed at runtime, not hardcoded |
| Microsoft Learn MCP Server | Microsoft’s public MCP server at `learn.microsoft.com/api/mcp`; exposes `microsoft_docs_search`, `microsoft_docs_fetch`, and `microsoft_code_sample_search` — the same knowledge service behind Ask Learn and Copilot for Azure |
| Streamable HTTP | The modern MCP transport; the Learn server uses this rather than the older SSE transport |
| `MCPTool` | The SDK class that wires a specific MCP server endpoint into the agent’s tool set |
| `project_connection_id` | Only needed when the MCP server requires credentials stored in Foundry (e.g. a private server with API key auth); omitted for public servers |
| `require_approval` | Controls whether each MCP tool call needs explicit user consent before executing — `”never”` for read-only servers; `”always”` for servers that can modify data |
| Approval loop | When `require_approval=”always”`, the response contains `mcp_approval_request` items; you send `McpApprovalResponse` objects referencing `approval_request_id` back via a second call that chains to the first via `previous_response_id` |

### Notebook Walkthrough

This notebook is organized into setup → tool wiring → agent creation → conversation turns:

1. _Initial Setup_ Load `.env`, read the required settings (project endpoint, model deployment), and initialise `DefaultAzureCredential` — no `az login` required; Service Principal credentials are picked up automatically from the environment.
2. _Initialise the AI Project Client_ Create `AIProjectClient` and obtain the `openai_client` you’ll use for conversations.
3. _Define the Microsoft Learn MCP Tool_ Instantiate `mcp_tool = MCPTool(server_label=”microsoft-learn”, server_url=”https://learn.microsoft.com/api/mcp”, require_approval=”never”)` — no connection ID needed for this public server.
4. _Create an Agent with MCP Tools_ Register a versioned agent using `PromptAgentDefinition(..., tools=[mcp_tool])` so it can discover and call the Learn MCP tool catalog at runtime.
5. _Create a Conversation_ Create a conversation ID that anchors the multi-turn session you run next.
6. _Run Sample Queries_ Send queries about Foundry models, SLMs vs LLMs, and MCP itself — the agent calls `microsoft_docs_search` and `microsoft_docs_fetch` transparently.
7. _Custom Interactive Query_ Swap in your own question to validate the agent can use the same MCP wiring for a new prompt.
8. _Cleanup_ Delete the agent version when you’re done to avoid leaving workshop resources behind.

**What to look for in this notebook:**
- The agent answers questions grounded in official Microsoft documentation — not just general model knowledge — which proves the MCP tool catalog is being discovered and used.
- Responses cite specific documentation sources, confirming the `microsoft_docs_fetch` tool is being called.
- Because `require_approval=”never”` is set, tool calls proceed without an approval loop — contrast this with what you’d need for a server that can modify resources.

### Reflection Questions
1. This notebook uses `require_approval=”never”` because the Learn server is read-only. In a production workflow connecting to an MCP server that can deploy models or modify data, what governance policy would determine when to use `”always”`, and what automated system would handle approval decisions in a CI/CD pipeline?
2. The Learn MCP Server requires no authentication. If you replaced it with a private MCP server backed by your own Azure AI Search index, what two things would you need to add to the `MCPTool` configuration?

---

## Use Case 2 — Insurance Claim Processing Continuity
### Suspending and resuming agent conversations across sessions

**Notebook:** `agent-framework/threads/3-suspend-resume-thread.ipynb`

### What You Will Build

An insurance claims advisor that can pause a conversation mid-session and resume it later — in a different process, on a different machine, or after an arbitrary delay — without losing context. The notebook runs two implementations side by side: a **service-managed thread** where Azure holds all state (serialized form is a short ID), and an **in-memory thread** where the application holds the full message list (serialized form is the entire history).

### Learning Objectives
- Use `thread.serialize()` and `agent.deserialize_thread()` to checkpoint and restore a conversation
- Distinguish service-managed from in-memory threading and understand what each serializes
- Recognize that `agent.run(query, thread=thread)` works identically for both thread types — the API surface is the same
- Understand the portability difference between a 50-byte thread ID and a full message-list payload

### Key Concepts

| Concept | What It Means |
|---------|---------------|
| Service-managed thread | Conversation history stored in Azure; `thread.serialize()` returns a small dict containing only a thread ID — the state lives server-side |
| In-memory thread | Conversation history stored in the application process; `thread.serialize()` returns the full message array |
| `thread.serialize()` | Returns a JSON-serializable snapshot — the exact shape depends on which thread implementation backs the agent |
| `agent.deserialize_thread()` | Reconstructs a thread object from its serialized form so `agent.run()` can continue the conversation |
| `agent.get_new_thread()` | Creates a new thread; the backing store is determined by which client type the agent was created with |
| `AzureAIAgentClient` | Framework client backed by the Azure AI Agents service; threads are service-managed |
| `AzureOpenAIChatClient` | Framework client backed by Azure OpenAI; threads are in-memory |

### Notebook Walkthrough

This notebook is organized into tools → thread checkpointing → storage model comparison:

1. _Prerequisites_ Load `.env` and make sure authentication is ready — Service Principal credentials (`AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`) are picked up automatically by `DefaultAzureCredential`; no `az login` required.
2. _Define Insurance Claim Tools_ Implement the two simple claim tools the agent will call (`get_claim_status`, `submit_additional_documents`).
3. _Example 1: Service-Managed Thread (Azure AI)_ Start a thread, ask a question, serialize to a small server-side thread identifier, then deserialize and continue the conversation.
4. _Example 2: In-Memory Thread (AzureOpenAIChatClient)_ Repeat the same suspend/resume flow, but note serialization returns the full message history (and requires `AZURE_OPENAI_ENDPOINT` plus a chat deployment name).
5. _APIs Used_ Skim the client and thread APIs being exercised so you can map the pattern into an app.

**What to look for in this notebook:**
- The serialized payload size difference is obvious in the output (service-managed is tiny; in-memory is the full transcript).
- The follow-up query after deserialization is answered correctly without re-stating context (resume worked).
- Both demos use the same `agent.run(..., thread=...)` shape; only the thread backing store changes.

### Reflection Questions
1. Service-managed serialization is roughly 50 bytes; in-memory can be kilobytes or more. In what production scenario would you choose in-memory despite the larger payload — and what does that choice imply about your deployment architecture?
2. If the Azure AI Agents service is unavailable, a service-managed thread cannot be resumed. What architectural pattern would you apply to protect a multi-day insurance claim workflow from this failure mode?

---

## Use Case 3 — Financial Analytics Dashboard
### Giving the agent the ability to compute

**Notebook:** `agent-framework/agents/azure-ai-agents/5-azure-ai-with-code-interpreter.ipynb`

### What You Will Build

Three purpose-scoped financial analytics agents — a compound interest calculator, a loan amortization engine, and a portfolio analyst — each backed by `HostedCodeInterpreterTool`. The tool gives the agent a sandboxed Python runtime; it writes and executes code to answer quantitative questions rather than relying on language model arithmetic, which is unreliable for precise financial computation.

### Learning Objectives
- Attach `HostedCodeInterpreterTool` to an agent via `AzureAIProjectAgentProvider.create_agent()`
- Understand why the agent writes and executes code rather than computing inline in its language generation
- Inspect the code the agent generated using `response.raw_representation` and `RunStepDeltaCodeInterpreterDetailItemObject`
- Recognize the pattern of creating a purpose-scoped agent per task rather than one general-purpose agent

### Key Concepts

| Concept | What It Means |
|---------|---------------|
| `HostedCodeInterpreterTool` | Agent Framework wrapper for the Code Interpreter built-in; tells the agent it may write and run Python |
| `AzureAIProjectAgentProvider` | Framework provider that manages agent creation, run dispatch, and lifecycle against the Azure AI Agents service |
| Sandboxed execution | Code runs inside an Azure-managed Python process, not the notebook kernel; it has no access to local files or environment variables |
| `RunStepDeltaCodeInterpreterDetailItemObject` | A streaming chunk type from `azure.ai.agents.models`; its `.input` field contains the Python source the agent generated |
| `response.raw_representation` | The raw streaming object attached to the framework response; must be iterated to access code interpreter inputs |

### Notebook Walkthrough

This notebook is organized into setup → code-interpreter wiring → worked examples:

1. _Prerequisites_ Confirm your Foundry project endpoint + model deployment are set (the notebook prints checks).
2. _Import Libraries_ Bring in `AzureAIProjectAgentProvider` plus `HostedCodeInterpreterTool` (and the optional streaming type used for introspection).
3. _Initial Setup_ Load `.env` and verify required values are present before creating an agent.
4. _Helper Function for Code Interpreter Data_ (Optional) Print the generated Python so you can audit the computation path.
5. _Create and Run the Financial Analytics Agent_ Create an agent with `HostedCodeInterpreterTool` attached.
6. _Execute the Example_ Run the compound-interest prompt end-to-end to confirm the pattern works.
7. _Loan Amortization Analysis Example_ Run the amortization prompt and inspect the payment + breakdown output.
8. _Portfolio Analysis Example_ Run the portfolio prompts to validate multi-step quantitative reasoning via Python.
9. _Key Takeaways_ Review the recommended patterns and caveats for production use.

**What to look for in this notebook:**
- The agent writes/executes Python for numeric outputs (results are computed, not “best guess” arithmetic).
- The optional introspection path shows the exact Python used, so you can spot-check formulas and assumptions.
- The same provider/agent wiring supports multiple finance questions without changing the tool setup.

### Reflection Questions
1. The agent writes code to compute answers rather than generating numbers directly. For which categories of financial question would you trust the sandboxed output without review, and for which would you require human verification?
2. Each example function creates a new agent with `provider.create_agent()`. What are the implications of this pattern at scale for a system handling many concurrent users?

---

## Use Case 4 — Financial Market Research Portal
### Grounding agent responses in live web search

**Notebook:** `agent-framework/agents/azure-ai-agents/7-azure-ai-with-bing-grounding.ipynb`

### What You Will Build

A Financial Market Research Analyst agent that uses Bing Grounding to retrieve current information — Fed rate expectations, bank earnings, mortgage market trends, fintech developments — and synthesizes it into dated, source-cited research responses. The agent instructs itself to cite sources explicitly, making grounding auditable.

### Learning Objectives
- Configure the Bing Grounding tool as a plain Python dict rather than an SDK class, and understand why
- Understand what `BING_CONNECTION_ID` represents and why the Bing connection must be registered in the portal first
- Recognize that the same `AzureAIProjectAgentProvider` pattern used in Use Case 3 works unchanged with a different tool type
- Distinguish model training knowledge (static, potentially stale) from Bing-retrieved knowledge (live, cited)

### Key Concepts

| Concept | What It Means |
|---------|---------------|
| Bing Grounding | A built-in Azure AI tool that gives the agent access to Bing web search; results are injected into the model's context before generation |
| `BING_CONNECTION_ID` | An ARM resource ID pointing to a Bing connection registered in the Foundry portal; required to authenticate search requests |
| Tool as a dict | Bing Grounding is configured as a raw Python dict with `"type": "bing_grounding"`, not an SDK class; the provider serializes it as-is |
| `search_configurations` | Array within the tool dict that specifies the `project_connection_id`; the array structure allows multiple Bing connections if needed |

### Notebook Walkthrough

This notebook is organized into setup → grounding tool config → single query → research loop:

1. _Prerequisites_ Confirm required environment variables are set (`AI_FOUNDRY_PROJECT_ENDPOINT`, `AZURE_AI_MODEL_DEPLOYMENT_NAME`, and `BING_CONNECTION_ID`).
2. _Import Libraries_ Load the provider + credential types (there is no SDK “Bing tool class” here).
3. _Initial Setup_ Load `.env` and print the key configuration so missing values fail fast.
4. _Verify Bing Connection Setup_ Explicitly validate `BING_CONNECTION_ID` and follow the portal instructions if it’s missing.
5. _Create Bing Grounding Search Tool_ Define the Bing tool as a dict and wire in the portal connection via `project_connection_id`.
6. _Create and Run the Financial Market Research Agent_ Create the agent with grounding enabled and instructions that require citations + dates.
7. _Execute the Example_ Run a single market question to validate grounding is working.
8. _Try Additional Market Research Queries_ Run the provided query set to see repeatability across topics.
9. _Key Takeaways_ Review recommended patterns (non-determinism, verification, and guardrails).

**What to look for in this notebook:**
- Responses include dates and source citations (that’s the signal grounding is being used and is auditable).
- Missing/incorrect `BING_CONNECTION_ID` fails early in the verification step (common workshop setup issue).
- Running the same prompt on different days yields different results (design evaluations around this non-determinism).

### Reflection Questions
1. Bing search results are non-deterministic — the same query on different days returns different content. How would you design evaluations for this agent given that non-determinism?
2. The instructions require the agent to cite sources and include dates. If you removed those instructions, what specific failure mode would emerge in a financial services deployment?

---

## Use Case 5 — Personalized Banking Assistant
### Persisting and recalling customer preferences across sessions

**Notebook:** `azure-ai-agents/9-agent-memory-search.ipynb`

### What You Will Build

A banking advisor that extracts customer preferences from conversations — risk tolerance, income, savings goals, emergency fund sizing — stores them in a persistent memory store backed by an embedding model, and retrieves them automatically in new sessions via semantic search. The notebook simulates a four-conversation lifecycle: establish preferences, recall them, update them, and verify the update took effect.

### Learning Objectives
- Create a `MemoryStoreDefaultDefinition` with `user_profile_enabled` and `chat_summary_enabled` options, and understand what each enables
- Attach `MemorySearchTool` to an agent and understand what `scope` and `update_delay` control
- Observe the extraction delay: memories are not available immediately after a conversation ends — they require the `update_delay` inactivity window to expire
- Use `create_version()` and the `extra_body` agent reference pattern to run versioned agents via the OpenAI client

### Key Concepts

| Concept | What It Means |
|---------|---------------|
| `MemoryStoreDefaultDefinition` | Configures the memory store's backing models and extraction behaviors |
| `MemoryStoreDefaultOptions` | Two boolean flags: `user_profile_enabled` extracts preferences and traits; `chat_summary_enabled` condenses conversation highlights |
| `MemorySearchTool` | Agent tool that searches the memory store before generating a response, and triggers extraction after `update_delay` seconds of inactivity |
| `scope` | A partition key string (e.g. customer ID) that isolates memories — different scopes are completely independent |
| `update_delay` | Seconds of inactivity before the memory system extracts and indexes new memories from the session; 5s in the demo, 300+ in production |
| Embedding model | Used by the memory store for semantic similarity search across stored facts; requires a separate deployment from the chat model |
| `create_version()` | Creates a versioned agent definition; both `name` and `version` are required in the `extra_body` agent reference |

### Notebook Walkthrough

This notebook is organized into setup → memory store creation → memory-enabled agent → four conversations:

1. _Authentication Setup_ Load `.env` and authenticate so the notebook can create agents, conversations, and a memory store.
2. _Step 1: Install Required Packages_ Confirm dependencies are installed (this repo expects installs via `requirements.txt`).
3. _Step 2: Load Configuration and Initialize Clients_ Create `AIProjectClient` and `openai_client`, and confirm the chat + embedding deployments are set.
4. _Step 3: Create a Memory Store_ Create the memory store that will persist preferences across sessions.
5. _Step 4: Configure the Memory Search Tool_ Create `MemorySearchTool` with a fixed `scope` and a short demo `update_delay`.
6. _Step 5: Create the Memory-Enabled Banking Agent_ Register the versioned agent with the memory tool attached.
7. _Step 6: Establish Customer Preferences (Conversation 1)_ Run an initial conversation that contains the preferences you want extracted.
8. _Step 7: Wait for Memory Extraction_ Pause long enough for `update_delay` to elapse so extraction can happen server-side.
9. _Step 8: Test Memory Recall (Conversation 2)_ Start a new conversation and confirm the agent recalls preferences without being re-told.
10. _Step 9: Update Preferences (Conversation 3)_ Change key values (risk/income/budget) and wait again for extraction.
11. _Step 10: Verify Updated Memory (Conversation 4)_ Start a fresh conversation and confirm the agent is using the updated profile.
12. _Step 11: Cleanup Resources_ Delete conversations, agent version, and the memory store so the notebook is repeatable.

**What to look for in this notebook:**
- Conversation 2 demonstrates true cross-session recall (the agent uses memory, not message history).
- The wait step is essential: if you don’t let `update_delay` elapse, recall may appear “broken” because extraction hasn’t run yet.
- The `scope` value is the partition boundary; keeping it constant links sessions, changing it isolates customers.

### Reflection Questions
1. Memory extraction is asynchronous and controlled by `update_delay`. What happens to a customer's stated preference if they send a follow-up message before the delay expires — is it captured in the same extraction pass?
2. The scope is a hardcoded string in the demo. The documentation recommends `"{{$userId}}"` for production. What does this sentinel resolve to, and why does it matter for a multi-tenant banking deployment where customer data must not leak across accounts?

---

## Use Case 6 — Persistent Financial Advisor
### Reusing a pre-registered agent without recreating it

**Notebook:** `agent-framework/agents/azure-ai-agents/3-azure-ai-with-existing-ai-agent.ipynb`

### What You Will Build

A Financial Advisor that is registered once using the raw `AgentsClient` from `azure.ai.agents.aio`, then wrapped with Agent Framework features using `provider.as_agent()`. The pattern separates agent registration (done once — in a provisioning script, a portal session, or a setup notebook) from agent use (done at runtime). This is the production model for stable, long-lived agents that multiple sessions or deployments share.

### Learning Objectives
- Use `AgentsClient` from `azure.ai.agents.aio` to create an agent directly on the service, bypassing the framework layer
- Wrap an existing service-registered agent object with `AzureAIAgentsProvider.as_agent()` to inject framework-managed tools
- Define function tool schemas using `Annotated[type, Field(description=...)]` type annotations on function parameters
- Understand why the `finally` block intentionally skips deletion — persistent agents are meant to outlive the session

### Key Concepts

| Concept | What It Means |
|---------|---------------|
| `AgentsClient` | The low-level async client from `azure.ai.agents.aio`; directly creates, retrieves, and manages agents on the Azure AI service |
| `AzureAIAgentsProvider` | Agent Framework provider that accepts an existing `AgentsClient` rather than creating its own connection — separation of connection management from agent wrapping |
| `provider.as_agent()` | Wraps a service-registered agent object with framework capabilities (tool dispatch, run management) without re-registering it on the service |
| `Annotated[str, Field(...)]` | Pydantic-style type annotation on function parameters; the framework reads these at import time to generate the JSON schema the model sees for each tool argument |
| Persistent agent | A service-registered agent with a stable ID; survives beyond the notebook session and can be retrieved by any process that knows its ID or name |

### Notebook Walkthrough

This notebook is organized into setup → tool schema definition → service registration → runtime wrapping:

1. _Prerequisites_ Confirm your project endpoint + model deployment are set; authentication uses `DefaultAzureCredential` with Service Principal credentials from `.env` — no `az login` required.
2. _Import Libraries_ Bring in `AgentsClient`, `AzureAIAgentsProvider`, and `Annotated[..., Field(...)]` so tool schemas can be declared inline.
3. _Initial Setup_ Load `.env` and fail fast if required variables are missing.
4. _Check Environment Variables_ Verify the key env vars before making any service calls.
5. _Define Function Tools_ Define tool functions with rich parameter descriptions so the model gets usable schemas.
6. _Create and Use Existing Agent_ Create/register the agent on the service, then wrap it with `provider.as_agent()` and attach tools at runtime.
7. _Execute the Example_ Run a prompt that forces multi-tool use (balance lookup + rate lookup).
8. _Key Takeaways_ Review the key patterns for “persistent agent” workflows and production use.

**What to look for in this notebook:**
- Service registration vs runtime wrapping are separate steps (the same service agent can be wrapped with different tool sets).
- Tool parameter descriptions from `Annotated[..., Field(...)]` materially affect whether the model calls tools correctly.
- The notebook intentionally avoids deleting the agent; treat this as a long-lived resource and plan lifecycle/cleanup separately.

### Reflection Questions
1. Tools are attached at the framework layer in `provider.as_agent()`, not in the service agent definition. What is the behavioral implication if the same service-registered agent is wrapped in two different processes with different tool sets attached to each?
2. `AgentsClient` is instantiated directly in this notebook rather than being obtained via `AIProjectClient.get_agents_client()`. When would you prefer each approach in a production codebase?

---

## Pattern Summary

| Use Case | How the tool or capability is attached | Session state location |
|---|---|---|
| Platform Operations Assistant | `MCPTool` in `PromptAgentDefinition.tools` | Conversation ID via `openai_client.conversations` |
| Claim Processing Continuity | Tools registered in `as_agent()` context manager | Serialized thread (service ID or full message list) |
| Financial Analytics Dashboard | `HostedCodeInterpreterTool()` passed to `provider.create_agent()` | None — each `agent.run()` is stateless |
| Financial Market Research Portal | Bing Grounding dict passed to `provider.create_agent()` | None — each `agent.run()` is stateless |
| Personalized Banking Assistant | `MemorySearchTool` in `PromptAgentDefinition.tools` | Memory store (persists across sessions by `scope`) |
| Persistent Financial Advisor | Tools injected via `provider.as_agent()` at runtime | Not managed by this notebook |
