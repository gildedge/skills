# Canonical report shape

Copy this, then fill from the raw input. Preserve the emoji headers and section order —
this is the exact shape the 72-report library and `MASTER-REPORT.md` use, and the three
**bold** parseable strings must survive verbatim.

```markdown
# 🎙️ Call Intelligence Report
## <Title Case Report Name>

---

# 🎙️ ARIA Call Intelligence Report

## 📋 Call Summary
- **Duration:** <m:ss or "X minutes">
- **Call Type:** <Cold Call | Follow-Up | Negotiation | Closing | Pitch>
- **Participants:** <Rep (Company)> <-> <Seller/Agent (role)>
- **Outcome:** <one-line outcome — parsed by extractOutcome()>
- **One-Line Summary:** <one sentence: structure, property, result>

## 📝 Key Transcript Highlights
**<Speaker>:** "<verbatim quote>" (0:21)
**<Speaker>:** "<verbatim quote>" (3:57)
<!-- keep quotes exact; include the (m:ss) timestamp -->

## 🏠 Extracted Deal Data
| Field | Value |
|-------|-------|
| Property Address | <addr or "Not explicitly stated"> |
| Property Type | <Single-Family / Multi-Family / Condo / Other> |
| Asking Price | <\$X or "Not explicitly stated"> |
| Market Value / ARV | <\$X or NOT PROVIDED — est. \$X> |
| Rent Estimate | <\$X/mo or est.> |
| Existing Mortgage Balance | <\$X or NOT PROVIDED> |
| Deal Structure | <Cash / Seller Finance / Subject-To / Wrap / Hybrid / MLO / Section 8> |
| Offer Price | <\$X> |
| Down Payment / Entry Fee | <\$X (Y% of price)> |
| Seller Finance Terms | <rate / term / balloon / monthly P&I, or n/a> |
| Balloon | <Yes (N yrs) — RISK / No> |
| Assignment / Wholesale Fee | <\$X or n/a> |
| Commission | <% + net split> |
| Seller Motivation / Reason | <why they're selling> |
| Closing Timeline | <N days> |

## 📊 Deal Analysis
<!-- Only when there are enough numbers. Follow aiService SYSTEM_PROMPTS.dealAnalysis gates. -->
| Metric | Value | Target | Pass? |
|--------|-------|--------|-------|
| Monthly Cashflow | \$X | >= \$200 | check |
| Cash-on-Cash | X% | >= 13% | check |
| DSCR | X | >= 1.25 | check |
| Cap Rate | X% | >= 6% | check |

**Verdict:** <GO / NO-GO / NEGOTIATE> — <2–3 sentence reasoning>.
<!-- If numbers are missing, state exactly which inputs are needed instead of guessing. -->

## 🎯 Scores
Seller Motivation Score: <N>/100
Agent Performance Scorecard: <N>/100
Risk Score: <1–10> <green/yellow/red>
```

## CSV row to append to `deal-extraction-summary.csv`

Columns: `File,Motivation Score,Agent Score,Outcome,Property Address,Asking Price,Deal Structure,Call Type,Duration`

Quote any field containing a comma or quote (double internal quotes). Example:

```
"Seller Finance Pitch 31 - Duplex in Fremont",88,90,"Follow-Up Scheduled (LOI to be sent)","Jackson Street; Fremont","Not explicitly stated","Hybrid (Cash Down + Seller Finance)","Negotiation","07:52"
```
