# A/B Test Design: Fast-Track Delivery Intervention

> This document designs the randomised experiment that would validate the causal claim from `delivery_review_causal.ipynb` — that reducing late deliveries increases customer satisfaction.

---

## 1. Background

The observational regression shows late deliveries lower review scores by roughly **0.5–0.7 stars** (OLS, controlling for price, category, and state). The hypothesis is that a faster-delivery service feature — e.g. priority carrier routing for randomly selected orders — can close this gap and measurably lift satisfaction.

---

## 2. Hypothesis

| | Statement |
|---|---|
| **H₀** | Priority shipping has no effect on P(review_score ≥ 4) |
| **H₁** | Priority shipping increases P(review_score ≥ 4) |

This is a one-sided test; we do not expect the intervention to harm satisfaction.

---

## 3. Metrics

### Primary
- **Customer satisfaction rate** — proportion of orders where `review_score ≥ 4`
  - Baseline (from dataset): **~77 %**
  - Rationale: directly tied to the causal finding; binary metric is clean for hypothesis testing

### Secondary
- Mean `review_score` (continuous; more statistical power)
- Late-delivery rate (confirms the mechanism is working)
- Mean `delivery_days`

### Guardrail (must not move)
| Metric | Direction | Reasoning |
|---|---|---|
| GMV per order | ≥ baseline | Priority shipping carries extra cost; must not erode margins |
| Refund / return rate | ≤ baseline | Faster delivery should not increase damage claims |
| Order cancellation rate | ≤ baseline | Confirm the feature is not confusing or deterring purchases |

---

## 4. Randomisation

**Unit:** `order_id`

**Why not customer?** ~97 % of Olist customers make only one purchase; customer-level randomisation would require months to reach adequate sample size and cannot improve over order-level assignment in this low-repeat-rate regime.

**Assignment:** deterministic hash of `order_id` → 50 % treatment / 50 % control (no personal data required; consistent for re-analysis).

**Eligibility:** orders that (a) reach *approved* status, (b) are shipped by a carrier that offers the priority tier, and (c) are in regions where coverage exists. Document the eligibility rule before launch to prevent p-hacking.

---

## 5. Sample Size and Duration

### Assumptions
| Parameter | Value |
|---|---|
| Baseline satisfaction rate (p₁) | 0.77 |
| Minimum detectable effect (MDE) | + 2 pp → p₂ = 0.79 |
| Significance level (α, one-sided) | 0.05 |
| Power (1 − β) | 0.80 |

### Calculation (two-proportion z-test)

```
n_per_arm = (z_α + z_β)² × [p₁(1−p₁) + p₂(1−p₂)] / (p₂ − p₁)²
          = (1.645 + 0.842)² × [0.77×0.23 + 0.79×0.21] / (0.02)²
          = 6.18 × 0.343 / 0.0004
          ≈ 5,300 orders per arm
          ≈ 10,600 orders total
```

### Duration
At Olist's 2018 peak daily order volume (~600–1,000 orders/day) with 50 % assignment:

| Scenario | Orders/day in treatment arm | Duration |
|---|---|---|
| Conservative (600/day) | 300 | ~18 days |
| Optimistic (1,000/day) | 500 | ~11 days |

**Recommended minimum run time: 4 weeks** regardless of when n is reached, to capture day-of-week and week-of-month variation in purchase and delivery patterns.

---

## 6. Analysis Plan (pre-registered)

### Primary analysis
```python
from scipy.stats import chi2_contingency

contingency = pd.crosstab(df['group'], df['satisfied'])
chi2, p_val, _, _ = chi2_contingency(contingency)
```
Report relative risk, absolute risk difference, and 95 % CI. Use one-sided p-value.

### Sensitivity / heterogeneous treatment effects
OLS regression controlling for product category and customer state (same specification as the observational study) to:
1. Improve precision (reduce variance)
2. Check for differential effects by state (distances vary)
3. Confirm the mechanism: late-delivery rate ↓ in treatment arm

### Exclusion criteria (pre-specified)
- Orders cancelled before shipment
- Orders outside the priority-shipping coverage zone
- Duplicate order_ids (data quality guard)

Analyse on the **intent-to-treat (ITT)** population (all randomised eligible orders), not only those that actually received faster delivery. ITT is the correct estimand for a business decision on whether to roll out the feature.

---

## 7. Risks and Limitations

| Risk | Mitigation |
|---|---|
| **SUTVA violation** — a customer who receives one late and one fast-tracked order may cross-contaminate responses | Low risk given ~3 % repeat-purchase rate; acceptable |
| **Novelty effect** — early adopters over-rate the new experience | Run for ≥ 4 weeks; monitor weekly satisfaction separately |
| **Coverage gap** — priority shipping not available everywhere | Stratify randomisation by region; document eligibility clearly |
| **Review non-response** — only ~99 % of Olist orders have reviews, but this could be differential | Compare review response rates between arms as a sanity check |
| **Cost** — marginal cost per shipment may negate GMV benefit | Monitor cost per review-score-point-gained alongside guardrails |

---

## 8. Decision Rule

At experiment close:

- **Ship if:** p-value < 0.05 (one-sided) AND all guardrail metrics within pre-set bounds AND cost per incremental satisfied customer is below business threshold.
- **Iterate if:** effect is positive but below MDE — consider targeting the subset of orders with longest expected delivery times (where effect should be largest).
- **Kill if:** satisfaction moves against treatment OR any guardrail breaches.
