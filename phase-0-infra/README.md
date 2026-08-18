# Forge Infrastructure: Foundations & SecOps 🛡️☁️

This repository holds the Infrastructure-as-Code (IaC) for **Phase 0** of the **Forge** project. The goal is to establish a solid, secure and automated foundation on Azure using Terraform, applying DevSecOps principles from the very start of the development lifecycle.

```mermaid
flowchart LR
    subgraph Local ["💻 Your local environment (WSL Ubuntu — user: kali)"]
        direction TB
        User((👤 kali))

        subgraph Files ["📂 Terraform code (your machine)"]
            direction TB
            Main["📄 main.tf<br/>(the orchestrator)"]
            ModNet["📁 module/network"]
            ModACR["📁 module/acr"]
            ModAKS["📁 module/aks"]

            Main -.-> ModNet & ModACR & ModAKS
        end

        CLI["🛠️ Terraform CLI<br/>(init, plan, apply)"]

        User -->|"Writes commands"| CLI
        CLI -.->|"Reads your code"| Files
    end

    subgraph Backend ["☁️ Remote backend (Azure Storage — Step 0)"]
        direction TB
        State["📄 forge.tfstate<br/>(Terraform's memory)"]
        Lock["🔒 State lock<br/>(safety lock)"]
    end

    subgraph Cloud ["☁️ Azure cloud"]
        direction TB
        API["⚙️ Azure Resource Manager<br/>(Azure's brain)"]
        Infra["🏗️ Your infrastructure<br/>(VNet, ACR, AKS)"]

        API ==>|"Executes the physical build"| Infra
    end

    %% Main connections
    CLI <==>|"1. Checks current state and locks the file"| State
    CLI -.->|"Activates"| Lock
    CLI ===>|"2. Sends creation instructions"| API

    %% Styles
    classDef wsl fill:#2c3e50,stroke:#fff,stroke-width:2px,color:#fff
    classDef files fill:#ecf0f1,stroke:#7f8c8d,stroke-width:1px,color:#000
    classDef tf fill:#5c4ee5,stroke:#fff,stroke-width:2px,color:#fff
    classDef backend fill:#f39c12,stroke:#fff,stroke-width:2px,color:#fff
    classDef azure fill:#00a4ef,stroke:#fff,stroke-width:2px,color:#fff

    class Local,User wsl
    class Files,Main,ModNet,ModACR,ModAKS files
    class CLI tf
    class State,Lock backend
    class API,Infra azure
```
---

## 🏗️ Architecture & components

The deployment provisions the foundational resources on Microsoft Azure using a modularized design:
*   **Azure Kubernetes Service (AKS):** base cluster with the free control plane for workload orchestration.
*   **Azure Container Registry (ACR):** private container registry on the *Basic* tier.
*   **Azure Virtual Network (VNet):** virtual network and dedicated subnets to isolate the cluster.
*   **Azure Storage Account:** secure storage for the Terraform backend and *state* locking.
> 💡 **Architecture note on remote state:** as shown in the diagram below, the **Azure Storage Account** that manages Terraform state (`.tfstate`) is deliberately kept *outside* the perimeter of the main resource group (`forge-rg`). For reasons of security, persistence and decoupling, it lives isolated in its own independent group (`forge-tfstate-rg`). This strategic separation guarantees that when tearing down ephemeral infrastructure (`make destroy`), the cluster's "memory" stays intact and shielded from accidental deletion.
```mermaid
flowchart TB
    subgraph Azure ["☁️ Microsoft Azure (region: eastus)"]
        direction TB

        subgraph RG ["📦 Resource group: forge-rg"]
            direction TB

            ACR["🐳 Azure Container Registry<br/>(forgeacr1739)"]

            subgraph VNet ["🕸️ Virtual network: forge-vnet<br/>Range: 10.0.0.0/16"]
                direction TB

                subgraph Subnet ["🗂️ Subnet: forge-aks-subnet<br/>Range: 10.0.1.0/24"]

                    subgraph AKS ["☸️ AKS cluster: forge-aks"]
                        direction TB
                        API["🧠 Control plane<br/>(managed by Microsoft)"]
                        Node["🖥️ Worker node<br/>(aks-default-41526441-vmss000000)<br/>Size: Standard_D2s_v3"]

                        API ~~~ Node
                    end

                end
            end

            %% Managed Identity relationship (Role Assignment)
            Node -.->|"🔑 Managed identity<br/>(role: AcrPull)"| ACR

        end
    end

    %% Color styles (applied automatically in compatible viewers)
    classDef azure fill:#f0f6ff,stroke:#0072C6,stroke-width:2px,color:#000
    classDef rg fill:#ffffff,stroke:#0072C6,stroke-width:2px,stroke-dasharray: 5 5,color:#000
    classDef vnet fill:#e6f2ff,stroke:#0072C6,stroke-width:1px,color:#000
    classDef subnet fill:#cce6ff,stroke:#0072C6,stroke-width:1px,color:#000
    classDef aks fill:#326ce5,stroke:#fff,stroke-width:2px,color:#fff
    classDef acr fill:#00a4ef,stroke:#fff,stroke-width:2px,color:#fff
    classDef api fill:#2c3e50,stroke:#fff,color:#fff

    class Azure azure
    class RG rg
    class VNet vnet
    class Subnet subnet
    class AKS aks
    class ACR acr
    class API,Node api
```

### Verification in the Azure portal
The correct creation of the resource groups and the network/compute components was validated directly from the Azure Manager console:

![Resource groups created](docs/resource-groups.png)

![Detail of components in the main resource group](docs/azure-resources.png)

---

## 🔒 Design & security decisions (SecOps)

This project follows professional security guidelines and cloud engineering best practices:

*   **Remote state with locking:** the Terraform state file (`.tfstate`) is stored remotely in an Azure Storage Account, preventing accidental exposure of secrets and enabling safe collaboration through *state locking*.
*   **Network security & restricted API:** the AKS cluster's control plane (API server) is protected via `authorized_ip_ranges`, allowing administration exclusively from trusted IPs. Any external request outside that range is silently dropped by the firewall.

```mermaid
flowchart TD
    subgraph Local ["💻 Your local environment (public IP: 85.156.89.208)"]
        User(("👤 kali (WSL)"))
        Kubeconfig["🔑 ~/.kube/config<br/>(access certificate)"]
        Cmd["🗣️ Command: kubectl get nodes"]

        User --> Cmd
        Cmd -.->|"Signs the request with"| Kubeconfig
    end

    subgraph Firewall ["🛡️ Barrier 1: Azure firewall (API access profile)"]
        CheckIP{"Is the traffic coming from<br/>IP 85.156.89.208?"}
    end

    subgraph AKS ["☸️ Kubernetes cluster (forge-aks)"]
        subgraph ControlPlane ["🧠 Control plane (API server)"]
            Auth{"🛡️ Barrier 2: Authentication<br/>Is the certificate valid?"}
            Process["⚙️ Processes the request and<br/>queries the worker nodes"]
        end

        Node["🖥️ Node: aks-default-41526441...<br/>(responds 'Ready')"]
    end

    %% Communication flow
    Cmd ===>|"Encrypted transit (HTTPS)"| CheckIP

    CheckIP -- "❌ NO" --> Drop(("🗑️ Packet dropped<br/>(silently ignored)"))
    CheckIP -- "✅ YES" --> Auth

    Auth -- "❌ NO" --> Deny(("🚫 Access denied<br/>(401 Unauthorized)"))
    Auth -- "✅ YES" --> Process

    Process <==>|"Azure secure internal network"| Node

    %% Styles
    classDef local fill:#2c3e50,stroke:#fff,stroke-width:2px,color:#fff
    classDef firewall fill:#c0392b,stroke:#fff,stroke-width:2px,color:#fff
    classDef logic fill:#f39c12,stroke:#fff,stroke-width:2px,color:#fff
    classDef aks fill:#326ce5,stroke:#fff,stroke-width:2px,color:#fff
    classDef cert fill:#27ae60,stroke:#fff,stroke-width:2px,color:#fff

    class Local,User local
    class Firewall firewall
    class CheckIP,Auth logic
    class AKS,ControlPlane,Node aks
    class Kubeconfig cert
```

*   **Secretless authentication (managed identities):** the AKS cluster is authorized to pull images from ACR through a managed identity with the `AcrPull` role, without static credentials. OIDC and *Workload Identity* were also enabled to support native, secretless pod authentication in later phases.

---

## ⚠️ Security & compliance (IaC analysis)

The infrastructure scan run with **Checkov** reports 21 findings. Most of these exceptions are technically justified because this environment is a **budget-constrained lab** (use of *Basic* SKUs, no regional high availability, and simplified network configurations).

![Checkov findings in the console](docs/checkov-scan.png)

Every exception is documented in detail, with its engineering rationale, inside the `.checkov.yaml` file. These security configurations are planned to be enabled incrementally as the project moves toward production phases.

![Configuration file with the justified skipped checks](docs/checkov-yaml.png)

---

## 🤖 Continuous Integration (CI/CD)

The infrastructure lifecycle is 100% automated with GitLab CI, embedding static analysis (SAST) directly in the pipeline before any change to real state is allowed.

![GitLab CI pipeline executed successfully](docs/pipeline-success.png)

*   **validate:** syntactic (`terraform fmt`) and structural validation.
*   **scan:** security policy compliance analysis with Checkov.
*   **plan:** detailed preview of the resource changes.
*   **apply / destroy:** gated behind manual execution, for security and budget-control reasons.

---

## 💰 Cost control & ephemeral infrastructure

To keep the lab viable and maintain financial hygiene, the project assumes an **ephemeral infrastructure** approach. No orphaned resources are left running.

A convenience `Makefile` unifies the complex Terraform and Azure CLI commands. It makes it easy to stand the architecture up quickly at the start of the day and tear it down cleanly at the end of the working session.

**Daily developer workflow:**
```bash
# 1. Stand up the full environment
make apply

# 2. Configure local credentials to interact with kubectl
make creds

# 3. Destroy all infrastructure to avoid residual costs
make destroy
```

### 📝 Validation checklist (Phase 0 complete)

The integrity and correct operation of the environment were validated through the following technical checks, run locally:

- [x] Remote state on Azure Storage working with no syntax or connection errors.
- [x] `terraform apply` stands up the RG, VNet, ACR and AKS successfully.
- [x] `kubectl get nodes` returns 1 node in `Ready` state.
- [x] `az acr login` authenticates correctly against the private registry.
- [x] Azure RBAC integration (`AcrPull`) confirmed between services.
- [x] Workload Identity and OIDC issuer enabled on the cluster.
- [x] GitLab pipeline green, and infrastructure cleaned up successfully with `make destroy`.
