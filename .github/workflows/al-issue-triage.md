---
description: "Auto-triage new issues for Business Central AL development"
on:
  workflow_dispatch:
    inputs:
      issue_number:
        description: "Issue number to triage in the current repository"
        required: true
        type: string
      issue_action:
        description: "Original issue event action that triggered triage (opened or reopened)"
        required: false
        type: string
permissions:
  contents: read
  issues: read
  pull-requests: read
tools:
  github:
    toolsets: [default]
safe-outputs:
  github-token: ${{ secrets.GH_AW_GITHUB_MCP_SERVER_TOKEN }}
  add-labels:
    max: 6
    target: "*"
    allowed: [bug, enhancement, documentation, question, security, needs-triage, "priority: critical", "priority: high", "priority: medium", "priority: low", ready-to-implement]
  add-comment:
    max: 1
    target: "*"
  update-issue:
    max: 1
    target: "*"
engine:
  id: copilot
  model: claude-sonnet-4.6
network:
  allowed:
    - github
env:
  AL_ISSUE_TRIAGE_ISSUE_NUMBER: ${{ github.event.inputs.issue_number }}
  AL_ISSUE_TRIAGE_ACTION: ${{ github.event.inputs.issue_action || 'opened' }}
---

# Issue Triage Agent – BC AL

When the issue triage dispatcher requests analysis for an issue in this repository, perform the following steps:

## 0. Resolve the Issue and Pre-check for Skips

Before doing anything else:

1. Read the runtime inputs from environment variables and print them first:
   - `echo "Issue number: $AL_ISSUE_TRIAGE_ISSUE_NUMBER"`
   - `echo "Issue action: $AL_ISSUE_TRIAGE_ACTION"`
2. If `AL_ISSUE_TRIAGE_ISSUE_NUMBER` is empty, call `missing_data` with `data_type: "issue_number"` and stop immediately. After a successful `missing_data` tool call, do not continue, do not add narrative text, and do not retry with other tools.
3. Read that issue explicitly by number from the current repository.
4. Because this workflow runs via `workflow_dispatch`, **all safe output writes must provide the issue number explicitly**:
   - `update-issue` → always set `issue_number: $AL_ISSUE_TRIAGE_ISSUE_NUMBER`
   - `add-labels` → always set `item_number: $AL_ISSUE_TRIAGE_ISSUE_NUMBER`
   - `add-comment` → always set `item_number: $AL_ISSUE_TRIAGE_ISSUE_NUMBER`

Then inspect the issue title, body, and labels.

- If the issue title contains any of the following strings, **stop immediately and do nothing**:
  - `Org Issue Scan`
  - `Triage Report`
  - `[agentics]`
  - `[agent]`

- If **any** of the following is true, **stop immediately and do nothing**:
  - the issue title starts with `CI Failure:`
  - the issue body contains `<!-- ci-analysis-context -->`
  - the issue already has the label `ci-failure-analysis`

These are self-generated pipeline report or CI-tracking issues and do not need triage. Call the `noop` tool with the message: "Skipped: automated pipeline report or CI tracking issue."

After the `noop` tool call succeeds for this skip path, stop immediately. Do not continue to later steps, do not make any additional tool calls, and do not add extra narrative output.

- If `AL_ISSUE_TRIAGE_ACTION` is `reopened`, check whether the issue body already contains a `### Context (added by skc-bc-internal-agents triage)` section **and** the issue already has a type label (`bug`, `enhancement`, `documentation`, `question`, `security`). If so, skip Steps 3 and 4 (enrichment and labelling) and jump directly to Step 7 to post a re-opened acknowledgement comment.

Otherwise, proceed with the steps below.

## 1. Read the Issue

Read the issue title and body carefully. Note the reporter's exact words — do not interpret yet.

**Detect images and attachments**: Scan the issue body for `<img` tags, `![` markdown image syntax, and URLs ending in `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, or GitHub `user-attachments/assets/` links.

**Native image reading**: You can view images directly. When images are detected in the issue body:

- **Fetch and examine each image URL** — GitHub private image URLs (e.g. `private-user-images.githubusercontent.com`) are accessible to you via the authenticated network.
- **Extract from the image**: page/report title, ALL visible column headers (exactly as shown), sample data rows, groupings/totals, filter fields, layout type (list/card/document/matrix), and any BC table or field names visible.
- **Use this information directly** when enriching the issue body, writing acceptance criteria, and deciding `ready-to-implement`.
- **Do NOT** ask the reporter to describe information that is visible in the image.
- Record how many images were found and what you were able to extract from each.

---

## 2. Research: Find Relevant AL Source

1. Extract 2–4 keywords from the issue title (e.g. `ECDF`, `Wizard`, `Payment`, `Vendor`).
2. Search the repository file tree for `.al` files whose names match those keywords.
3. If matches are found, read the most relevant file (prefer `Page` objects for UI issues; `Codeunit` or `Table` for logic/data issues). Read up to 150 lines around the relevant object or procedure.
4. Also read `app.json` to get the namespace, ID range, and suffix from `AppSourceCop.json` if it exists.
5. Record: object type, object name, ID, and the names of any `action`, `field`, `trigger`, or `procedure` that relates to the issue.
6. If no matching AL file is found, note that the affected area could not be located in source.

---

## 3. Enrich and Optimise the Issue Body

Using what you found in step 2, rewrite the issue body to make it implementation-ready. Follow these rules:

- **Keep the reporter's original intent intact** — do not change what they are asking for.
- Add a structured section below the original text with the following headings (only include headings where you have information):

```markdown
---
### Context (added by skc-bc-internal-agents triage)

**Affected Object:** `<ObjectType> <ID> <ObjectName>` (file: `<path/to/file.al>`)
**Related Procedure / Action:** `<name>` (line ~<N>)

**What the current code does:**
<1–2 sentences describing what the relevant procedure/action currently does, based on the AL source.>

**What needs to change:**
<Concrete restatement of the request, referencing the actual object and procedure names.>

**Acceptance Criteria:**
- [ ] <Criterion 1 — specific, testable>
- [ ] <Criterion 2>
- [ ] Compiles with zero errors and zero AppSourceCop/LinterCop violations
```

- If the issue was too brief (e.g. one-line description), fill in the "What needs to change" and "Acceptance Criteria" sections with your best interpretation based on the source context, and add a note: `> ⚠️ Description was brief — the above is inferred from source. Reporter should confirm.`
- If no source was found, still add the structured section but leave "Affected Object" as `Unknown — please provide the AL page or codeunit name`.
- Update the issue body with this enriched version using the `update-issue` safe output tool, always setting `issue_number: $AL_ISSUE_TRIAGE_ISSUE_NUMBER` explicitly.

---

## 4. Classify the Issue

Based on the original text **and** the source research, identify:

- The **type** of the issue (bug, feature request, documentation, question, security, performance).
- The **affected area / module** — use the folder containing the AL file found in step 2.
- The **priority** based on business impact:
  - **critical** – core business process is broken, data loss, or security vulnerability
  - **high** – a main feature is not working correctly
  - **medium** – minor functional issue or improvement request
  - **low** – cosmetic, documentation, or minor enhancement

---

## 5. Apply Labels

Apply the appropriate labels based on your analysis:

### Type labels (apply one)
- `bug` – something is broken or behaving incorrectly
- `enhancement` – new feature or improvement request
- `documentation` – documentation update needed
- `question` – needs clarification or information
- `security` – potential security concern

### Priority labels (apply one)
- `priority: critical`
- `priority: high`
- `priority: medium`
- `priority: low`

Always provide `item_number: $AL_ISSUE_TRIAGE_ISSUE_NUMBER` explicitly when adding labels.

---

## 6. Evaluate Readiness for Automatic Implementation

Evaluate whether the issue (after enrichment) is ready for automatic AL code implementation by checking **all** of the following:

- The type is `enhancement` or `bug`
- The enriched issue body has a **clear, unambiguous description** of what needs to be done
- The expected behaviour or desired outcome is explicitly described (either by the reporter or filled in by step 3)
- There are no open questions that require human input before work can begin
- The issue does not depend on external decisions (e.g., licensing, business approval, design sign-off)
- The issue is not marked `needs-triage`, `question`, or `wontfix`

If **all** criteria are met, apply `ready-to-implement` (only if it exists as a label in the repository).

If any criterion is not met, do **not** apply `ready-to-implement`.

---

## 7. Post an Acknowledgement Comment

Post a single comment that includes:

1. A brief summary referencing the actual AL object found (e.g. "This affects `Page 50100 ECDF Declaration Wizard`").
2. The classification applied.
3. If it is a **bug**: ask for BC version and steps to reproduce if still missing after enrichment.
4. If `ready-to-implement` was applied: mention that it is queued for automatic implementation and a PR will be opened shortly.
5. If `ready-to-implement` was **not** applied: state exactly what is still missing.
6. If the description was inferred from source (brief original): mention this and ask the reporter to confirm the interpretation in the issue body.
7. A note that the AL-Go CI pipeline will validate any proposed fix.

**If `AL_ISSUE_TRIAGE_ACTION` is `reopened`** (issue was previously closed and is now re-opened), use this comment template instead:

> 🔄 **This issue has been re-opened.**
>
> The previous fix appears to be incomplete or a regression was introduced. The skc-bc-internal-agents triage agent has reviewed the issue state:
>
> - **Classification:** `<type>` / `<priority>`
> - **Previous context:** [retained from the triage section in the issue body]
>
> If the original acceptance criteria are still valid, applying `ready-to-implement` will queue a new implementation run. If the requirements have changed, please update the issue body before re-applying the label.
>
> _Acknowledged by the skc-bc-internal-agents triage pipeline._

## Important Rules

- Do NOT assign the issue to any user.
- Do NOT close or dismiss the issue.
- Only apply labels that already exist in the repository.
- If you are uncertain about classification, apply `needs-triage` and note the uncertainty in the comment.
- Only apply `ready-to-implement` if it already exists as a label in the repository — do not create it.
- Always provide the explicit issue number on every safe output write because this workflow is not triggered directly by the issue event.