# forge-app · Phase 2 — Signed application supply chain

**End-to-end software supply chain for a real application:** SecurityScanService (FastAPI) built on a hardened golden base, with **hash-pinned dependencies**, a full **SBOM + SLSA provenance**, and a **keyless signature produced by the pipeline itself** (Sigstore: OIDC → Fulcio → Rekor) — every artifact cryptographically verifiable, with **zero signing secrets to manage**.

> **📍 Phase 3 is live in this repo:** the AKS cluster now rejects any image
> not signed by this pipeline's identity. → **[Admission gate — Phase 3](docs/phase3-admission-gate.md)**

> **The 10-second version:** the app inherits hardening from a signed base (`FROM forge-base@sha256:…`), installs **16 dependencies locked to exact version + SHA-256 hash** (`0` CVEs in app deps, `0` in the OS), and ships **signed by digest, logged in Rekor** — verifiable against the *exact pipeline identity* that built it. Build-time trust, closed.

![Trust chain — build-time to deploy-time](docs/img/forge-cadena-confianza.png)

---

## Why this matters

Phase 1 answered *"is my base image the one I built, hardened and untampered?"*. Phase 2 answers the harder question for the artifact that **actually runs in production**: *"is the application image exactly what I built — with a known inventory, from a known base, signed by a process I can point to?"*

The industry default is `FROM python:3.11-slim`, `pip install -r requirements.txt` (unpinned), and no signature. This project replaces every link of that chain with a verifiable one — and does it the way mature platform teams do: hardening is **inherited**, not re-implemented per app.

---

## Key results

| Dimension | Industry default | `forge-app` (this project) |
|---|---|---|
| Base image | `python:3.11-slim` (Debian, ~20 inherited CVEs) | `FROM forge-base@sha256:…` — hardened Wolfi, **0 OS CVEs** |
| Dependencies | unpinned `requirements.txt` | **version + SHA-256 hash**, 16 packages incl. transitives |
| CVEs in app dependencies | unknown | **0** (Trivy gate, `--require-hashes` at build) |
| Runs as | root | **non-root (uid 65532)**, inherited from base |
| Inventory | none | **SBOM CycloneDX** (464 packages: OS + Python) |
| Provenance | none | **SLSA attestation** at build |
| Signature | none | **keyless, by digest, pipeline identity, logged in Rekor** |
| Base reference | mutable tag | **immutable digest** + OCI `base.digest` label |

The only 2 HIGH findings in the image live in the **bundled `trivy` binary inherited from the base** — not in the OS, not in the app, not in the dependencies. They are formally excepted with written justification (see [Risk management](#risk-management-what-was-not-fixed)).

---

## The differentiator: the pipeline is the signer

Signing an artifact is common. Signing it with a **human's personal identity from a laptop** is an anti-pattern — if that person leaves, or their credential leaks, the trust story collapses. This project makes the signature belong to a **process, not a person**:

```text
git push ──► GitLab CI ──► job 'sign'
                              │
     GitLab mints an OIDC id_token (pipeline identity, no browser, no stored key)
                              │
     Fulcio issues an ephemeral cert (~10 min) → cosign signs the image BY DIGEST
                              │
     signature recorded in Rekor (public, immutable transparency log)
                              ▼
     signer = https://gitlab.com/alejandrochuang/forge-app//.gitlab-ci.yml@refs/heads/main
```

There is **no long-lived signing key to store, rotate, or leak** — the ephemeral build identity *is* the credential. And the signature is attributable: anyone can verify the image was signed by *this exact pipeline*, not merely *that a signature exists*.

### Verify it yourself

```bash
APP_DIGEST=$(docker buildx imagetools inspect "$ACR_LOGIN_SERVER/forge-app:0.1.0" \
  --format '{{.Manifest.Digest}}' | grep -oE 'sha256:[a-f0-9]{64}' | sed -n '1p')

cosign verify \
  --certificate-identity-regexp "https://gitlab.com/alejandrochuang/forge-app//.gitlab-ci.yml.*" \
  --certificate-oidc-issuer "https://gitlab.com" \
  "$ACR_LOGIN_SERVER/forge-app@$APP_DIGEST" \
  | jq '.[0].optional.Subject, .[0].optional.Issuer'
```

The SBOM is attached as a **signed attestation** (`in-toto`), so the inventory itself is verifiable — not a trust-me document sitting loose in a CI artifact:

```bash
cosign verify-attestation \
  --certificate-identity-regexp "https://gitlab.com/alejandrochuang/forge-app//.gitlab-ci.yml.*" \
  --certificate-oidc-issuer "https://gitlab.com" \
  --type cyclonedx "$ACR_LOGIN_SERVER/forge-app@$APP_DIGEST"
```

---

## Pipeline architecture

Five chained stages, each a gate. The image **digest** computed at build is propagated to every later stage, so the exact same bytes are scanned, inventoried and signed — no TOCTOU window between "what I checked" and "what runs".

```text
build ──► trivy-scan ──► sbom ──► sign ──► attest-sbom
```

| Stage | Control | Tool | Guarantee |
|---|---|---|---|
| `build` | Build on hardened base + SLSA provenance, push by digest | `docker buildx` | Traceability: how and where it was built |
| `trivy-scan` | Blocking gate (`--exit-code 1`, fixable-only) | Trivy | No remediable HIGH/CRITICAL reaches the registry |
| `sbom` | CycloneDX inventory | Syft | Instant answer to "does this new CVE affect us?" |
| `sign` | Keyless signing with the pipeline's OIDC identity | cosign / Sigstore | Authenticity + integrity, no stored key |
| `attest-sbom` | SBOM attached as signed attestation | cosign | The inventory is cryptographically verifiable |

![Pipeline passed: 5 jobs green](docs/img/pipeline-green.png)

CI secrets are stored **Protected + Masked** — the Service Principal credentials never appear in the pipeline YAML or in logs.

![CI/CD variables: Protected and Masked](docs/img/ci-variables.png)

---

## Engineering decisions (the *why*, not just the *what*)

**Hash-pinning, not just version-pinning.** Locking `fastapi==0.139.0` protects against surprise updates, but not against someone substituting that package on the index with a malicious build under the same version (index compromise / typosquatting). `pip-compile --generate-hashes` locks every package — direct and transitive — to its exact SHA-256; `pip install --require-hashes` then **aborts the build if a single byte differs**. This closes the dependency-substitution vector and resolves technical debt carried over from a prior project (an unpinned `requirements.txt`).

**Inherit hardening, don't repeat it.** The Dockerfile is tiny (~25 lines, half of them comments) *because* the base carries the weight: Wolfi, non-root, nmap and trivy all come from `FROM forge-base`. This is the **golden base image** pattern — the app owns only its code and its dependencies. Separation of concerns as a supply-chain property, not a style choice.

**Prod/dev dependency split.** `pytest` and `httpx` live in a separate `requirements-dev.txt` that never enters the image. Fewer packages in the deployed artifact = smaller attack surface = fewer potential CVEs.

**Pin the base by digest, not tag.** A tag (`forge-base:0.1.0`) is mutable — someone with registry access could re-point it to a compromised image and the next build would inherit it silently. Pinning `FROM forge-base@sha256:…` guarantees the app is always built on the exact base that was audited and signed. The OCI `base.digest` label makes the provenance metadata state that truth too, rather than contradicting it.

**Fix before except.** The Trivy gate blocked on 2 HIGH in the bundled trivy binary; those are inherited from the base, inert at rest, with no patched upstream binary published — excepted in `.trivyignore` with written justification and a review date, not silenced.

---

## Production debugging: making the pipeline converge

A first CI pipeline against real cloud rarely passes on the first run. This one converged after diagnosing, in sequence:

| Failure | Diagnosis → fix |
|---|---|
| `azure-cli: no such package` | Not on Alpine (runner image) → authenticate to ACR with `docker login` + Service Principal, drop Azure CLI |
| `Attestation is not supported for the docker driver` | `--provenance`/`--sbom` need the `docker-container` driver → `buildx create --driver docker-container` |
| `TLS handshake timeout` to ACR (deterministic) | MTU mismatch in the nested BuildKit container network → run BuildKit with `--driver-opt network=host` |
| `build.env: Invalid Format` (dotenv 400) | `imagetools inspect` on an image *with attestations* returns **multiple digests** → select the manifest-list digest only |
| `exit 141` (SIGPIPE) | `grep \| head` under `pipefail` kills the upstream command → capture to variable, use `sed -n '1p'` |
| `exec: "sh" not found` in scan/sbom/sign | Official trivy/syft/cosign images are distroless (no shell) → run jobs on `docker:27`, fetch the binary at job start |

> The real learning wasn't the YAML — it was **distinguishing a configuration error** (fixed in the file) **from a transient infrastructure failure** (made resilient with retries). The TLS timeout looked transient; a cheap experiment (retry ×3, no code change) proved it deterministic *before* applying the complex fix. That discipline — diagnose before you patch — is the difference between debugging with judgment and firing blind.

---

## Risk management (what was *not* fixed)

An honest model beats an all-green one. Residual risk, identified and documented:

- 🟡 **2 HIGH CVEs in the bundled trivy binary** (`CVE-2026-50151`, `CVE-2026-39822`) — inherited from the base, inert at rest (the tool is invoked in a controlled way against a fixed allowlisted target), no fixed upstream binary yet. Excepted in `.trivyignore` with written justification, re-reviewed on every rebuild.
- 🟡 **Digest pinning is manual** — updating the base requires bumping the digest by hand. Production would automate this with digest-bump tooling (renovate/dependabot for images).
- 🟡 **Broad Service Principal** (Contributor, inherited from Phase 0) — known debt; production would scope it to the resource group.
- 🔵 **Out of scope for this phase:** CI runner compromise (production: ephemeral runners, higher SLSA level), runtime security (eBPF/Tetragon, a later project), and application logic — SSRF and argument-injection in `/api/scan` were covered by SAST in a prior project; this phase is supply chain, not AppSec.

---

## Stack

`Chainguard Wolfi` (inherited base) · `pip-tools` (`--generate-hashes`) · `Docker Buildx` (docker-container driver, SLSA provenance, host networking) · `Trivy` · `Syft` (SBOM CycloneDX) · `cosign` / `Sigstore` (Fulcio + Rekor) · `GitLab CI` (OIDC `id_tokens`) · `Azure Container Registry`

## Repository layout

```text
forge-app/
├── Dockerfile          # inherits FROM forge-base@sha256:… (non-root, hash-verified deps)
├── requirements.in     # first-level deps (declared intent)
├── requirements.txt    # compiled: exact version + SHA-256 hash, all transitives
├── requirements-dev.in # dev tooling — never enters the image
├── .trivyignore        # CVE exceptions — each one justified in writing
├── .dockerignore
├── .gitlab-ci.yml      # build → scan → sbom → sign → attest (keyless)
├── Makefile            # local convenience (pipeline is the source of truth)
├── app/                # SecurityScanService (FastAPI)
└── scripts/            # pin-deps / build / scan
```

## Project context

**Phase 0** (`forge-infra`): Azure foundations with Terraform — AKS, ACR, Workload Identity, remote state, Checkov IaC scanning. ✅
**Phase 1** (`forge-images`): hardened, signed golden base image (Wolfi, Trivy, keyless cosign). ✅
**Phase 2** (this repo): the application supply chain — inherits `FROM forge-base`, hash-pinned deps, SBOM + provenance + keyless signature of the app image. ✅
**Phase 3** (next): admission control (Kyverno) on AKS — the cluster rejects any image not signed by the expected pipeline identity. The signature verified here is exactly what the policy will enforce.
