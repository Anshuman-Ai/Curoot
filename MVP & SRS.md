# **Master Project Report & Software Requirements Specification (SRS)**

**Project:** The "Figma for Supply Chain" Platform

**Document Purpose:** Single Source of Truth for Engineering, Product, and Design Teams

**Targeted UN SDGs:** SDG 9 (Industry, Innovation & Infrastructure), SDG 12 (Responsible Consumption & Production), SDG 13 (Climate Action)

## **1\. Executive Summary & Vision**

Modern global supply chains operate in highly volatile environments but continue to rely on fragmented, single-player legacy software (e.g., disconnected ERPs, static spreadsheets, and siloed email threads). In a post-2020 landscape, these rigid architectures are no longer viable. When disruptions occur—whether due to natural disasters, geopolitical friction, or sudden port closures—the lack of Tier-2+ visibility and cross-entity interoperability results in massive latency, critical inventory shortages, and high carbon-emission rerouting.

**The Solution:** A real-time, universal visual canvas that connects Original Equipment Manufacturers (OEMs), Tier-1/Tier-2 suppliers, and multi-modal logistics providers in a single multiplayer workspace. By treating supply chain nodes as interactive, collaborative elements rather than static database rows, the platform allows dynamic route optimization, autonomous AI-driven tradeoff analysis, community-driven templates, and instant communication to resolve crises in real-time. This "Figma" paradigm shifts supply chain management from retrospective reporting to proactive, collaborative orchestration.

## **2\. Core Platform Components & Features**

The platform is built upon 7 core interconnected components. This section defines the business logic, intended functionality, and behavioral nuances of each module.

### **2.1. Omni-Format AI Ingestion & Generation Layer (The Entry Point)**

**Definition:** A dual-track, zero-trust data integration gateway that combines an intelligent multimodal parser for instant cold-start onboarding with an AI-generated Agentic Polling Loop (via Model Context Protocol) for continuous, secure enterprise synchronization.

**How it Works:** The layer operates across three distinct tracks managed by a Smart Router:

1. **The Cold Start (Unstructured):** Using multimodal AI (Gemini 2.5), it runs NLP and OCR on unstructured data dumps (PDFs, emails, CSVs) to extract entities, relationships, and geographic coordinates.  
2. **The Continuous Sync (Zero-Trust Pull):**Objective: Safely extract operational data from fragile, on-premise legacy databases (e.g., old ERPs, Oracle, SAP) without exposing the platform to network vulnerabilities or crashing the client's servers.  
   Architecture:  
* AI-Generated MCP Container: The platform dynamically generates a localized Docker container containing a customized Python Model Context Protocol (MCP) script.  
* SQLite Shock Absorber: To prevent read-heavy polling from crashing the legacy database, the MCP script performs low-frequency reads and writes the data to a lightweight, localized SQLite database inside the container.  
* Append-Only Sync: The Docker container acts as an adapter, pushing an append-only sync from the local SQLite buffer outward to the platform's Supabase instance via secure HTTPS.  
    
3. **Modern Push (Webhooks):** Active data streams pass through a deterministic Universal Filter (Python/Pydantic) that instantly strips unauthorized keys (e.g., pricing) before formatting the telemetry.  
4. **Smart Routing:** Standard coordinate/status updates bypass the LLM entirely to update the Supabase Master DB instantly. Unstructured crisis data (e.g., "delayed due to strike") is routed directly to the AI Co-Pilot.

**Business Logic & Capabilities:** Instead of forcing enterprises to build custom APIs, expose raw databases, or perform tedious manual entry, the system dynamically writes its own secure integration layer. The AI evaluates the setup and prompts: *"I have generated the secure MCP connector for your Oracle ERP. Should I begin mapping live telemetry to the Main Canvas?"* The architecture ensures maximum data privacy while preserving LLM API quotas, only invoking advanced AI compute for complex crisis resolution and initial entity mapping, rather than standard logistics tracking.

**Target Audience Note:** This feature is primarily designed to solve the ultimate B2B friction point: Data Sovereignty. It allows massive, established players (OEMs, Tier-1s) to connect legacy systems without triggering months of security audits, as they retain complete kill-switch control over their local MCP container. Simultaneously, the unstructured dump capability ensures smaller regional suppliers without robust IT infrastructure can still be mapped into the real-time multiplayer ecosystem instantly.

### **2.2. Community-Driven "Quick Setup" & Auto-Apply**

* **Definition:** A marketplace of modular supply chain templates tailored for startups and scaling businesses that lack established, enterprise-grade logistics networks.  
* **How it Works:** Veteran users can publish their optimized, sanitized supply chain setups to the community. A new user can browse and "Auto-Apply" a template that fits their niche, such as "Ethical Sourcing Textiles \- South Asia."  
* **Business Logic:** Applying a template triggers an automated "Request for Proposal (RFP) / Lead Generation" pipeline. This process sends automated requests to supplier nodes, providing realistic timelines for commercial onboarding. Each supplier node enters a "Pending" (yellow) state, with a maximum cooldown of one day (or utilizing a rate limit of max 2 requests per day on specified nodes) to allow time for the supplier to respond. If the supplier confirms, the node's status turns green (Active). If no confirmation is received, the system is prompted to suggest alternatives.

* **Fallback:** The standard timeframe for an RFP reply is one month, not one day (this is a default setting that can be adjusted in user preferences). A 1-day cooldown period is implemented after two requests (RFP submissions) are made on the same specific field (node). This measure is in place to prevent bot abuse and enforce user rate limiting, ensuring the platform remains usable and efficient by discouraging the submission of excessive RFPs.

### **2.3. Node Discovery & Onboarding**

**Definition** A centralized, single-entry workflow originating directly from the Main Canvas. By clicking the \[+\] button, users open a unified modal that handles both geographic discovery (searching for unknown nodes) and targeted provisioning (inviting known partners), seamlessly routing them into the user's 1-Hop network.

**Phase 1: The Single Entry Point (The \[+\] Modal)** To initiate any network expansion, the user clicks the floating \[+\] button on their live canvas. This opens the "Add Node" interface, presenting two primary paths within the same window: **Search** or **Invite**.

**Phase 2: Path A \- Search & Discover (The Tri-Layer Pull)** If the user needs to find a new supplier, they use the search bar and radius sliders within the modal. The system executes a strict, cost-optimized hierarchy:

* **Priority 1 (Active Platform Network):** Instantly pulls matching local/global nodes already active on the platform.  
* **Priority 2 (Community Ecosystem):** Pulls structured supplier data from community templates (requires a "Pending" cooldown to activate).  
* **Priority 3 (Google Maps Fallback):** Utilizes the Google Maps free tier to find entirely unregistered businesses in the designated radius.  
* **Local Caching:** External API queries (Priority 3\) act as one-time pull requests, caching up to two alternative nodes locally for subsequent searches.

**Phase 3: Path B \- Direct Invite (Targeted Provisioning)** If the user already knows their supplier or the search yields no ideal results, they toggle to the "Invite" tab within the same \[+\] modal.

* **Initiation:** The user enters the target organization's basic details (Name, Email/Contact Number, Connection Type).  
* **Execution:** The system generates and sends a secure, time-boxed invitation link (valid for 7 days) via email or WhatsApp redirect.

**Phase 4: Visual Canvas Placement & Lifecycle** Regardless of whether a node is Discovered (Path A) or Invited (Path B), it is instantly dropped onto the canvas and enters a specific visual lifecycle:

* **The Unverified / Pending State:** Newly dropped nodes appear on the canvas but require action. Invited nodes wait for the supplier to complete account creation and schema validation in their isolated network room. Discovered external nodes (Priority 3\) wait for the user to manually verify them.  
* **Static Operation (The Faded State):** If a verified node does not fully integrate into the platform (lacking live telemetry), its opacity is permanently reduced by 50% to 75%. It completes the visual topology and can still receive macro-environmental alerts based on its geographic location.  
* **Live Conversion (100% Opacity):** Once an invited partner completes onboarding, or a static node is successfully converted via the communication layer, the secure 1-Hop data bridge is formed. The node transitions to full opacity, signaling real-time data exchange (e.g., Active/Delayed status). Both organizations remain in isolated rooms to ensure strict data sovereignty.  
* **Note:** Both organizations remain in isolated network rooms, and no cross-organization data is shared at this stage.

### **2.4. Multiplayer Main Canvas**

**Definition:** The core interactive workspace where organizations map, monitor, and manage their supply chain network. Unlike traditional shared-graph platforms, this system enforces a strict "1-Hop" architectural boundary to guarantee absolute commercial data privacy by default.

**How it Works: Strict 1-Hop Visibility & Data Sovereignty**

●       **The 1-Hop Boundary:** An organization's canvas exclusively displays its *immediate* upstream suppliers and *immediate* downstream buyers. Visibility ends strictly at one degree of separation.

●       **Zero-Knowledge Upstream Propagation:** To protect trade secrets and supplier relationships, disruptions in Tier-2+ networks are abstracted before reaching an OEM. If a Tier-2 supplier faces a localized delay, the Tier-1 node on the OEM's canvas simply reflects an abstracted operational payload (e.g., Status: Delayed 48 hrs | Reason: Upstream Exception). The OEM is alerted to the delay without ever discovering the identity or location of the Tier-2 supplier.

●   	**Elimination of Global Rooms:** There are no shared "collaboration rooms" or multi-tenant graph spaces. Every organization interacts solely with a personalized, ego-centric projection of their immediate operational network.

**Intelligent Risk & Abstraction Engine:** The canvas ingests macro-environmental data (geopolitical alerts, weather, financial signals) and maps it against known nodes. When a disruption occurs, the engine automatically calculates the cascading delay and pushes localized, abstracted alerts to immediate downstream partners, transforming the visual map into a proactive decision-making engine without violating NDA boundaries.

### **2.5. Real-Time Disruption Alerts & Macro-Environment Side Panel**

●       **Definition:** A dual-layered early warning system designed to catch both immediate physical disruptions and abstract geopolitical shifts.

●       **How it Works:**

○       **Disruption Alerts:** The system actively monitors weather, traffic, and physical blockage APIs. When a physical disruption intersects an active route, the specific nodes or routing edges instantly flash red on the live canvas.

○       **Macro-Environment Side Panel:** A dedicated UI panel tracking abstract risks. It aggregates real-time news feeds, social media sentiment (e.g., local strikes, boycotts), geopolitics, and sudden legal/regulatory changes affecting the specific countries where your active nodes operate. This flags risks *before* they manifest as physical delays.

### **2.6. Actionable Insights & Tradeoffs Tab**

●       **Definition:** The analytical brain of the canvas, powered by AI, to handle exception management.

●       **How it Works:** When a node goes down, the system doesn't just show a static error. It provides **Actionable Insights** directly on the canvas (e.g., *"Reroute through Border X to save 12 hours"*). If the user utilizes the Node Discovery layer to select an alternative supplier, the **Tradeoffs Tab** appears. This tab calculates the hard math of the switch, comparing the current node against the alternative across four primary metrics: Financial Cost, Time/Latency, Carbon Footprint (ESG), and Historical Reliability.

### **2.7. Direct Call Options & Instant Resolution**

●       **Definition:** An integrated, frictionless communication layer designed to eliminate the "swivel-chair effect" of switching context during a crisis.

**How it Works:** Instead of leaving the platform to coordinate a fix, users can click a node and select communication options. The system utilizes WhatsApp link-based redirects (e.g., wa.me/ links using the supplier's registered contact number) for instantaneous mobile-friendly chat. Alongside WhatsApp and standard email mailto: triggers, the platform offers an internal, in-platform messaging system to negotiate terms, ensuring a logged audit trail of the crisis resolution.

### **3\. High-Level System Architecture (Tech Stack)**

The architecture is specifically engineered for real-time performance, cost-efficiency, and strict data sovereignty, combining modern frameworks with secure zero-trust integration protocols.

**Layer 1: Frontend Engine & Client Workspace**

* **Core Framework:** Flutter (Web/Desktop).  
* **Component Logic Integration:** Flutter provides the high-performance rendering required for the complex, interactive supply chain network graph. It powers the centralized \[+\] Modal for unified geographic discovery and targeted provisioning. It also handles the visual lifecycles of nodes, dynamically rendering states from "Unverified/Pending" to "Static Operation" (50% to 75% opacity) up to "Live Conversion" (100% opacity).

**Layer 2: Backend API, Routing & Business Logic**

* **Core Framework:** Python with FastAPI & Pydantic.  
* **Component Logic Integration:** FastAPI directs standard coordinate and status updates directly to the database via a Smart Router, intentionally bypassing the LLM to save compute. Meanwhile, it routes unstructured crisis data straight to the AI Co-Pilot. Pydantic acts as a Universal Filter, instantly stripping unauthorized keys (like pricing) from incoming modern webhooks.

**Layer 3: State, Auth, Caching & Data Sovereignty**

* **Core Framework:** Supabase (PostgreSQL \+ WebSockets) & SQLite.  
* **Component Logic Integration:** Supabase manages the master schema and real-time updates. To guarantee absolute commercial data privacy, PostgreSQL architecture enforces a strict "1-Hop" boundary, ensuring an organization's canvas exclusively displays its immediate upstream and downstream connections. SQLite is utilized in two ways: locally caching up to two alternative nodes during external Google Maps searches to minimize API costs , and acting as a localized "Shock Absorber" inside client containers to prevent legacy database crashes.

**Layer 4: Intelligence, Edge Connectivity & External Integrations**

* **Core AI Agent:** Google Vertex AI / Gemini 2.5. This multimodal AI runs NLP and OCR on unstructured data dumps (like PDFs and emails) for cold-start onboarding and calculates tradeoff metrics for exception management.  
* **Zero-Trust Integration (MCP):** The platform generates localized Docker containers running Python Model Context Protocol (MCP) scripts to extract operational data from fragile, on-premise ERPs securely.  
* **Discovery & Telemetry APIs:** The system queries the Google Maps free tier as a Priority 3 fallback to locate unregistered businesses and ingests weather, traffic, and physical blockage APIs to power Disruption Alerts.

---

### **4\. Engineering Workflow: How it Works in Practice**

This workflow outlines the exact data flow of the platform during a crisis event, reflecting the updated isolated environment constraints and the \[+\] modal discovery logic.

* **Ingestion & Detection:** The system actively monitors physical APIs; when a weather event or blockage intersects an active routing edge, the specific nodes instantly flash red on the live canvas. Concurrently, the Macro-Environment Side Panel tracks abstract risks like sudden legal changes or local strikes in the specific countries where nodes operate.  
* **Analysis & Actionable Insights:** Rather than displaying a static error, the Actionable Insights engine immediately provides on-canvas suggestions, such as rerouting through specific borders to save time.  
* **Discovery & Network Expansion:** To find an emergency supplier, the user clicks the floating \[+\] button to open the unified "Add Node" modal. Selecting "Path A \- Search & Discover," the system triggers a Tri-Layer Pull. It sequentially checks the Active Platform Network (Priority 1\) , Community Templates (Priority 2\) , and finally falls back to Google Maps (Priority 3\) to find unregistered businesses in the area.  
* **Optimization & Tradeoff Calculation:** When the user selects a new alternative node, the Tradeoffs Tab automatically calculates the hard math of the switch. It compares the current failing node against the alternative across Financial Cost, Time/Latency, Carbon Footprint, and Historical Reliability.  
* **Verification & Instant Resolution:** The newly discovered node is dropped onto the canvas in an "Unverified" state. The user utilizes the Direct Call Options layer, clicking the node to initiate a WhatsApp link-based redirect for instant, mobile-friendly negotiation.  
* **Live Conversion:** Once the supplier confirms capacity and completes their isolated account validation , the secure 1-Hop data bridge is formed. The node transitions from a faded state to 100% opacity, signaling real-time data exchange , while both organizations safely remain in isolated network rooms with no cross-organization data leakage.

---

### **5\. Platform Synergy: The Seamless User Journey**

To understand how the newly defined architecture components synthesize into a frictionless workflow, consider this end-to-end user lifecycle:

* **Phase 1: Zero-Trust Cold Start Onboarding:** An electronics manufacturer enters the platform with fragmented data. They utilize the Omni-Format AI layer to upload unstructured PDFs and CSVs. The AI (Gemini 2.5) extracts the entities and geographic coordinates , while dynamically prompting to generate a secure MCP connector for their legacy Oracle ERP. The supply chain instantly populates on the visual canvas.  
* **Phase 2: Filling Gaps via Community Templates:** Realizing they lack regional distribution partners, the user browses the Community-Driven "Quick Setup" and auto-applies a template (e.g., "Ethical Sourcing Textiles \- South Asia"). This triggers an automated Request for Proposal (RFP) pipeline. The targeted supplier nodes drop onto the canvas in a "Pending" (yellow) state, governed by a strict 1-day cooldown to prevent bot abuse.  
* **Phase 3: Real-Time Disruptions & Abstraction:** Months later, a localized delay hits a Tier-2 supplier. Because of the strict Zero-Knowledge Upstream Propagation rules, the Tier-1 node on the manufacturer's canvas simply displays an abstracted payload (e.g., *Status: Delayed 48 hrs | Reason: Upstream Exception*). The manufacturer is instantly alerted without discovering the Tier-2 supplier's identity.  
* **Phase 4: Targeted Provisioning & Resolution:** To secure a backup, the manufacturer clicks the \[+\] button and toggles to "Path B \- Direct Invite". They enter a known regional partner's details, generating a time-boxed, 7-day invitation link.  
* **Phase 5: The 1-Hop Synergy:** The invited partner completes onboarding within their isolated room. The platform establishes the secure bridge, transitioning the node on the manufacturer's canvas to 100% full opacity. The crisis is collaboratively resolved in real-time, shifting the manufacturer's operations from retrospective reporting to proactive orchestration.