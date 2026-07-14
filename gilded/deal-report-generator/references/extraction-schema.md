# Extracted Deal Data — canonical field set

The `## 🏠 Extracted Deal Data` table must use these field labels, in this order, so every
report in the library is comparable. Field names map to `src/types/deal.ts`
(`PropertyInfo` / `FinancialInfo`) so a report can be promoted to a `SavedDeal`
(`dealService.saveDeal`) without renaming. Missing values → `NOT PROVIDED — est. $X`
or `Not explicitly stated` (never blank).

| Field (report label)        | deal.ts source                          | Notes |
|-----------------------------|-----------------------------------------|-------|
| Property Address            | `PropertyInfo.address`                  | Street + city; goes to CSV col `Property Address` |
| Property Type               | `PropertyInfo.propertyType`             | Single-Family / Multi-Family / Condo / Other |
| Units                       | `PropertyInfo.units`                    | Multi-family only |
| Asking Price                | `PropertyInfo.askingPrice`              | CSV col `Asking Price`; `Not explicitly stated` if unknown |
| Market Value / ARV          | `PropertyInfo.marketValue` / `.arv`     | |
| Rent Estimate               | `PropertyInfo.rentEstimate`             | Monthly gross |
| Existing Mortgage Balance   | `FinancialInfo.existingMortgage`        | Critical for Sub-To |
| Interest Rate (existing)    | `PropertyInfo.loanDetails.*.rate`       | |
| Deal Structure              | `PropertyInfo.dealType` / `OfferType`   | CSV col `Deal Structure`; e.g. Cash, Seller Finance, Subject-To, Wrap, Hybrid, MLO, Section 8 |
| Offer Price                 | `FinancialInfo.offerPrice`              | |
| Down Payment / Entry Fee    | `FinancialInfo.downPayment`             | ARIA gate: ≤ 15% of price |
| Seller Finance Terms        | `FinancialInfo.sellerFinanceTerms`      | rate / term / balloon / monthly P&I |
| Balloon                     | `FinancialInfo.hasBalloon` + years      | Always flag as a risk |
| Assignment / Wholesale Fee  | `FinancialInfo.assignmentFee`           | |
| Commission                  | `PropertyInfo.agentCommissions`         | % + who nets what |
| Seller Motivation / Reason  | narrative                               | Drives the Motivation Score |
| Closing Timeline            | `PropertyInfo.closingTimeline`          | Days |

## Scoring rubric

Both scores are **0–100** and MUST appear as these literal lines (parsed by
`callIntelligenceService.ts`):

```
Seller Motivation Score: <N>/100
Agent Performance Scorecard: <N>/100
```

**Seller Motivation Score (0–100)** — how ready/flexible the seller is:
- Stated pain (divorce, relocation, tired landlord, distress): up to 40
- Urgency / timeline (needs out fast): up to 30
- Flexibility on terms/price (open to creative, owner-carry): up to 30

**Agent Performance Scorecard (0–100)** — how well the acquisitions rep ran the call:
- Discovery / uncovering motivation: up to 25
- Framing & anchoring the terms: up to 25
- Objection handling (rate, non-assignment, "why creative"): up to 25
- Control of flow + clear next step / close: up to 25

**Risk Score (1–10, 1 = lowest risk)** — from `aiService` SYSTEM_PROMPTS.dealAnalysis:
- 1–3 🟢 Low · 4–6 🟡 Moderate · 7–10 🔴 High.
- Weigh: LTV > 80%, balloon timelines, due-on-sale exposure (Sub-To), tenant/lease quality,
  market vacancy, deferred maintenance, exit viability.

## Outcome (CSV col `Outcome`, and `**Outcome:**` line)

Short phrase matching library style, e.g. `Follow-Up Scheduled (LOI to be sent)`,
`Accepted Offer`, `Verbal Agreement`, `No — not willing to present offer`,
`Under Contract`. Keep it in ONE line after `**Outcome:**` so `extractOutcome()` catches it.

## Call Type (CSV col `Call Type`)

One of the `CallIntelligenceRequest.callType` values / library norms:
`Cold Call`, `Follow-Up`, `Negotiation`, `Closing`, `Pitch` (combine with `/` when a call spans phases).
