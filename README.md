
# 🛡️ Forge — Secure Software Supply Chain on Azure

> **Can I prove that what runs in my cluster is exactly what I built — hardened, auditable, and untampered?**
> The industry default answer is *"we trust so."* This project's answer is **"I can prove it"** — cryptographically, for every build, with no human in the loop.

A four-phase DevSecOps project that builds a **complete, verifiable software supply chain**: from Infrastructure-as-Code foundations, through a hardened signed base image and a signed application, to a Kubernetes **admission gate where the cluster itself refuses to run anything the pipeline didn't sign.**

---

## The chain, in one picture

```text
   📝 source + IaC
        │
   ── BUILD-TIME · produces cryptographic evidence ────────────────
        │
   Phase 0  ──►  Phase 1  ──►  Phase 2
   IaC scanned   hardened      hash-pinned deps
   before apply  signed base   SBOM + provenance + signature
        │
        │   ⏸  the artifact then sits in the registry for days/weeks
        │
   ── DEPLOY-TIME · enforces that evidence ────────────────────────
        │
   Phase 3  ──►  the cluster REJECTS any image not signed
                 by this exact pipeline identity
        │
        ▼
   🟢 verified pod running in AKS
```

**Build securely → sign → deploy only what verifies.** Both build-time and deploy-time covered — most projects stop at one.

---

## The four phases

| | Phase | Question it answers | Headline result | Detail |
|:-:|:--|:--|:--|:--|
| **0** | **Foundations** | Is the infrastructure correct and secure from the start? | IaC scanned *before* apply · secretless auth · IP-restricted API | [`phase-0-infra/`](./phase-0-infra) |
| **1** | **Hardened base** | Is the base image the one I built, untampered? | **22 → 3 HIGH/CRITICAL CVEs (−86%), 0 in the OS** | [`phase-1-images/`](./phase-1-images) |
| **2** | **Supply chain** | Is the app exactly what I built, from a known base? | **16 deps pinned by version + SHA-256 hash, 0 CVEs** | [`phase-2-app/`](./phase-2-app) |
| **3** | **Admission gate** | Does my platform *require* all of the above? | Cluster **rejects unsigned images at deploy time** | [phase 3 →](./phase-2-app/docs/phase3-admission-gate.md) |

Each phase has its own detailed README. Read top to bottom — the project is linear and cumulative.

---

## The three ideas it rests on

**🔑 The signature belongs to a *process*, not a *person*.**
The signer is the pipeline itself (`gitlab-ci.yml@refs/heads/main`), not a human with a key on a laptop. Keyless signing (OIDC → Fulcio → Rekor) means there is **no long-lived key to store, rotate, or leak** — the ephemeral build identity *is* the credential.

**🔗 Rekor is the pivot.**
The pipeline signs in one place; the cluster verifies in another; **they never exchange a secret** — only a public, immutable, auditable fact travels between them. That is what decouples build-time from deploy-time without either side custodying anything.

**⚡ Passive evidence → active control.**
Phases 0–2 *produce* proof (Trivy, SBOM, signature) — but none of them *prevents* anything. Phase 3 is the link that **exercises** the evidence: verification stops being a step someone remembers and becomes the platform's default. The difference between *"I have a signature"* and *"my platform requires one."*

---

## What this demonstrates (for the reader in a hurry)

| | |
|:--|:--|
| 🧱 **Defense in depth, end to end** | SAST → IaC scan → hardened base → signed supply chain → admission gate |
| 🔐 **Least privilege, tested under fire** | The verifier got a read-only token scoped to one repository — not the CI Service Principal. When it leaked in a CLI log, blast radius was *one repo, read-only, 7 days*. **Least privilege doesn't prevent leaks — it caps what they cost.** |
| 📋 **Chosen risk, not inherited** | Every security exception documented with written justification and a review date — not silenced |
| 🔍 **Diagnose before you patch** | Every pipeline failure resolved by root cause, distinguishing config error from transient infra failure |
| 📐 **Real-world adaptation** | The runbook was treated as intent, not script — its assumptions (private registry, deprecated API fields, a self-blocking policy) were found and fixed against the live environment |

---

## The moment it became real

Days after the app was built, scanned clean, signed, and deployed, **a new HIGH CVE was published for the Python in the base image.** A routine push turned the pipeline red — *same bytes, different verdict.*

Resolved at the source (rebuild the base, bump the pinned digest), never silenced with an exception — because a patch existed, and **fix comes before except.** The incident surfaced three truths a permanently-green pipeline never would:

- A green scan is a **photograph, not a contract** — it certifies the world on scan day → production needs continuous re-scanning, not a build check that expires.
- A misconfigured CI dependency (`needs:`) **silently bypassed a gate** — only visible once a gate actually fired.
- The digest pin **absorbed a real tag-repointing attack** — the running pod never flinched, because the cluster had pinned it to its verified digest.

*The attacks the earlier phases argue about in theory were observed and neutralized in practice.*

---

## Tech stack

**Cloud & orchestration** — Azure (AKS · ACR · VNet) · Kubernetes
**IaC & policy** — Terraform · Checkov · Kyverno
**Supply chain** — Chainguard Wolfi · Docker Buildx (SLSA provenance) · Trivy · Syft (SBOM) · cosign / Sigstore (Fulcio + Rekor)
**Dependency integrity** — pip-tools (`--generate-hashes`)
**CI/CD & identity** — GitLab CI · OIDC · Workload Identity

## Repository map

```text
forge/
├── phase-0-infra/     Terraform foundations (AKS · ACR · VNet · Workload Identity)
├── phase-1-images/    Hardened signed golden base (Wolfi · Trivy · cosign)
├── phase-2-app/       Signed application supply chain
│   └── docs/phase3-admission-gate.md   ← Phase 3: Kyverno admission gate
└── docs/              Cross-phase documentation
```

## Status

| Phase | State |
|:--|:--|
| 0 · Foundations | ✅ Complete |
| 1 · Hardened base | ✅ Complete |
| 2 · Supply chain | ✅ Complete |
| 3 · Admission gate | ✅ Complete |

---

*Platform Security Engineering · a portfolio about proving, not trusting.*
