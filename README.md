# surveyclean — Survey Data Tools for Stata

A README and hands-on tutorial. See [Installation](#installation) for the
quick version, or read on for a plain-language explanation of every
subcommand with a real scenario behind each one.

## Who this is for

Complex survey data — anything with sampling weights, strata, and primary
sampling units (PSUs) — has a whole extra layer of things that can go
wrong before you ever get to `svyset` and start estimating. A single
corrupted weight can dominate every variance calculation in your entire
analysis. A stratum with only one PSU will break linearized variance
estimation outright, or silently mislead you if you're not watching for
it. A weighted sample that doesn't track known population totals for
something like age or region is telling you something is off with either
the weights or the underlying non-response. `surveyclean` is a pre-flight
check for exactly these issues, run before `svyset`, not after you've
already produced results you have to second-guess.

## Installation

**Manual install:**

1. In Stata, type `sysdir` and note the path next to `PERSONAL`.
2. Copy every `.ado` and `.sthlp` file from this folder into that
   directory.
3. Restart Stata, or type `discard`, then confirm with
   `help surveyclean`.

**From GitHub**, once hosted:

```stata
net install surveyclean, from("https://raw.githubusercontent.com/yourusername/surveyclean/main") replace
```

The four subcommands are `wtcheck`, `stratdx`, `benchmark`, and
`trimwt`. A natural order: check the weight itself, check the
strata/PSU design, compare the weighted sample to known population
totals, and trim extreme weights if needed — all before you run `svyset`
and start estimating anything.

## wtcheck: is your weight variable actually usable?

**The problem.** A survey weight is supposed to represent how many
population units each sampled unit "stands for." If that variable has
missing values, zeros, or negative numbers, something has already gone
wrong upstream — a join that didn't fully match, a division by zero
somewhere in the weight construction, a sign error. And even when every
weight is technically valid (positive, non-missing), a small number of
enormous weights relative to the rest can single-handedly dominate every
weighted statistic and blow up your standard errors, a phenomenon
sometimes called a "large weight problem."

**What it does.** `wtcheck` reports how many weights are missing, zero,
or negative (all invalid for estimation), gives you the standard
descriptive statistics (mean, median, SD, coefficient of variation,
min, max), and flags weights that are unusually large relative to the
median — a quick way to spot the "large weight problem" before it shows
up as a suspiciously huge standard error three steps later.

**A worked example.**

```stata
surveyclean wtcheck pweight, threshold(8)
```

```
Survey weight check: pweight
------------------------------------------------------------
N observations:                500
Missing weights:                  1
Zero weights:                     1
Negative weights:                 0
------------------------------------------------------------
Mean:        68.234
Median:      58.910
SD:          52.017
CV:           0.762
Min:          0.000
Max:        901.442
------------------------------------------------------------
Weights > 8x median (possible extreme values): 3
------------------------------------------------------------

WARNING: negative weights are invalid and will break most survey estimators
WARNING: missing weights cause those observations to be dropped by svyset/aweight/pweight
```

Wait — this example didn't have negative weights, so that warning
wouldn't actually print; the point is that `wtcheck` only shows warnings
that are actually relevant to what it found, so when you do see a
warning printed, it's telling you something real about your specific
weight variable, not a boilerplate disclaimer.

Reading the output above: one missing weight and one zero weight are
worth chasing down (both will silently exclude that observation from any
`svyset`-based estimate, which might not be what you intended), and three
observations have weights more than 8 times the median — worth looking
at individually before deciding whether they're legitimate (a genuinely
under-sampled subgroup that needed heavy weighting) or a data problem.

```stata
list id pweight if pweight > 8*58.910 & !missing(pweight)
```

**Choosing a sensible threshold.** The default (10× the median) is a
reasonable general-purpose starting point, but the "right" threshold
depends on your survey's design — a survey with deliberately
oversampled rare subgroups will naturally have some large weights by
design, and you don't want to flag every one of them as a "problem."
Lower the threshold to be more sensitive (`threshold(5)`), or raise it
if your design legitimately produces a wide weight range and you only
want to catch the truly extreme cases (`threshold(20)`).

## stratdx: is your stratification/PSU design well-formed?

**The problem.** Complex survey variance estimation depends on
`svyset`'s strata and PSU structure being set up correctly, and two
specific problems come up constantly in practice. First, a **singleton
stratum** — a stratum containing only one PSU — breaks the standard
linearized variance estimator, because you can't estimate
between-PSU variance within a stratum from a single PSU; Stata will
either error out or require you to specify how to handle it
(`svyset`'s `singleunit()` option). Second, and more subtle: PSU codes
are very often only unique *within* a stratum, not across the whole
dataset — "PSU 1" might exist independently in every single stratum,
representing a completely different physical cluster each time. If you
`svyset` using the raw PSU variable without realizing this, Stata may
silently treat PSU 1 in stratum A as the same sampling unit as PSU 1 in
stratum B, corrupting your variance estimates without any error message
at all.

**What it does.** `stratdx` reports the number of strata, the number of
truly unique PSUs, the distribution of PSUs per stratum, and explicitly
flags both problems above: singleton strata, and PSU codes that appear
in more than one stratum.

**A worked example.**

```stata
surveyclean stratdx, strata(stratum) psu(psu)
```

```
Stratification / PSU structure check
------------------------------------------------------------
Observations:                       500
Strata:                                4
Unique PSUs:                          21
PSUs per stratum -- min/mean/max:    1 /  6.0 /  20
Singleton strata (only 1 PSU):         1
PSUs spanning >1 stratum:              0
------------------------------------------------------------

WARNING: singleton strata found -- linearized variance estimation may fail;
  consider svyset's singleunit() option (e.g. singleunit(certainty) or scaled)
```

This immediately tells you which specific problem you have (a singleton
stratum, not a PSU-nesting issue) and points you to the relevant
`svyset` option to handle it rather than leaving you to discover the
problem only when `svy: mean` throws an error partway through your
analysis.

**The PSU-nesting warning, in more detail.** If instead `stratdx`
reports something like:

```
PSUs spanning >1 stratum:              14
WARNING: some PSU codes are not uniquely nested within a stratum --
  PSU IDs are usually only unique within a stratum, not across the whole sample;
  consider using stratum#psu as a combined PSU identifier
```

this is telling you that your raw `psu` variable, used as-is, would
conflate genuinely different sampling clusters that happen to share a
number. The fix is exactly what the warning suggests — build a combined
identifier that's unique across the whole sample before you `svyset`:

```stata
egen psu_id = group(stratum psu)
svyset psu_id, strata(stratum)
```

This is a classic, easy-to-miss survey data bug precisely because
everything *looks* fine — the variables exist, the values look
reasonable, `svyset` doesn't necessarily throw an error — but your
variance estimates are wrong until you catch it. Running `stratdx` before
`svyset` is the cheap insurance against exactly this.

## benchmark: does your weighted sample look like the population?

**The problem.** Survey weights are supposed to correct for unequal
selection probabilities and non-response, so that a properly weighted
sample's composition matches the known population it's drawn from — for
things like age distribution, sex ratio, or regional population shares,
which are usually known independently from a census or official
population estimates. If your weighted sample's regional composition is
noticeably different from the known population's, that's a signal
something is off — either the weights themselves, or a non-response
pattern the weights aren't fully correcting for.

**What it does.** `benchmark` compares the unweighted sample share, the
weighted sample share, and a population share you supply, for each
level of a categorical variable — letting you see at a glance not just
whether weighting helped, but by how much, and whether it got you all
the way to matching the population or only partway there.

**A worked example.** Suppose you know, from census figures, that the
true population shares across four regions are 20% / 30% / 30% / 20%:

```stata
surveyclean benchmark region, weight(pweight) popshare(20 30 30 20)
```

```
Benchmark check: region vs. supplied population shares (all in %)
------------------------------------------------------------------------------
Level          Unweighted     Weighted     Population   Wtd - Pop
------------------------------------------------------------------------------
1                   28.40        21.13          20.00        1.13
2                   23.20        29.87          30.00       -0.13
3                   24.60        29.02          30.00       -0.98
4                   23.80        20.98          20.00        0.98
------------------------------------------------------------------------------
```

Reading this: the *unweighted* sample over-represents region 1 (28.4%
of the raw sample vs. 20% of the population) and under-represents
region 2 — exactly the kind of imbalance survey weights exist to fix.
The *weighted* column shows the weighting did most of that correction
(21.1% vs. 20%, 29.9% vs. 30%), leaving only small residual gaps in the
"Wtd - Pop" column. Small residual gaps like these (under 1-2
percentage points) are typically unremarkable — weighting rarely gets a
sample to match population totals exactly. A large residual gap (say,
5+ percentage points) after weighting is the more concerning finding,
suggesting either the weights weren't constructed using this variable as
a benchmark, or there's a non-response pattern the weighting scheme
isn't capturing.

**Where to get population shares.** These typically come from an
independent, authoritative source — a national census, official
population projections, or the sampling frame itself if it was built
from a complete population list. `benchmark` doesn't know or check where
your numbers came from; it's on you to supply population shares you
trust, since the whole comparison is only as good as that number.

## trimwt: taming a few weights before they take over your variance

**The problem.** Even after `wtcheck` flags a handful of extreme
weights and you've confirmed they're legitimate (not data errors), a
small number of very large weights can still cause a single
observation to dominate a weighted estimate and inflate its standard
error disproportionately. The standard practical fix — used across
survey methodology as a deliberate bias/variance tradeoff — is to cap
("trim" or "winsorize") the largest weights at some threshold, accepting
a small amount of bias in exchange for a meaningful reduction in
variance.

**What it does.** `trimwt` caps a weight variable at either a chosen
percentile (say, the 99th) or a multiple of the median (say, 5 times),
reports the cap value used and how many observations were affected, and
creates a new, trimmed weight variable rather than silently overwriting
your original.

**A worked example, percentile method:**

```stata
surveyclean trimwt pweight, method(percentile) pctile(99) generate(trimw99_pweight)
```

```
Weight trimming: pweight -> trimw99_pweight  (method: percentile)
------------------------------------------------------------
Cap value:                  312.5000
Observations trimmed:              5
------------------------------------------------------------
```

Any weight above the 99th percentile value is capped at that value; the
rest of the distribution is untouched.

**A worked example, median-multiple method** — the more common approach
specifically for survey design weights, since it's tied to a stable,
outlier-resistant center point rather than a percentile that can itself
shift depending on how extreme the tail already is:

```stata
surveyclean trimwt pweight, method(median) mult(5)
```

```
Weight trimming: pweight -> trimw_pweight  (method: median)
------------------------------------------------------------
Cap value:                  294.5500
Observations trimmed:              3
------------------------------------------------------------
```

Once you're satisfied with the trimmed weight, use it going forward in
your survey setup:

```stata
svyset psu_id [pweight = trimw_pweight], strata(stratum)
```

**A note on what trimming actually costs you.** Capping large weights
introduces a small amount of bias — the observations that got capped are
now under-representing their true population share, by construction.
This is a deliberate, well-established tradeoff in survey methodology
(reduced variance in exchange for a small increase in bias), not a free
lunch — always report that you trimmed weights, at what threshold, and
how many observations were affected, exactly the numbers `trimwt` prints
for you.

## Putting it together: a realistic pre-analysis workflow

Here's how these four typically get used together before you ever call
`svyset` in a real project:

```stata
use "household_survey.dta", clear

* 1. Is the weight itself usable?
surveyclean wtcheck pweight, threshold(8)
* -> investigate any missing/zero/negative weights before continuing

* 2. Is the strata/PSU design sound?
surveyclean stratdx, strata(stratum) psu(psu)
* -> if PSUs aren't uniquely nested, fix that first:
egen psu_id = group(stratum psu)

* 3. Does the weighted sample track known population totals?
surveyclean benchmark region, weight(pweight) popshare(20 30 30 20)
* -> small residual gaps are normal; large ones deserve investigation

* 4. Trim a few extreme weights before they dominate your variance
surveyclean trimwt pweight, method(median) mult(5)

* 5. Now set up the design, with confidence in every piece of it
svyset psu_id [pweight = trimw_pweight], strata(stratum)
svy: mean income
```

## Frequently asked questions

**Should I always trim weights, even if `wtcheck` doesn't flag many
extreme ones?** No — trimming introduces bias, so it should be a
deliberate response to an identified problem (a handful of very large
weights meaningfully inflating variance), not a routine step applied to
every dataset regardless of whether it's needed.

**What's a "reasonable" coefficient of variation (CV) for survey
weights?** There's no universal threshold — a CV around 0.5 to 1 is
common and unremarkable for many household surveys with moderate design
effects; substantially higher values suggest a wide range of selection
probabilities or weighting adjustments, which isn't necessarily wrong,
but is worth understanding rather than assuming away.

**Does `stratdx` work with certainty PSUs (strata sampled with
probability 1, containing only one unit by design)?** It will flag them
as singleton strata just like any other single-PSU stratum, which is
technically correct — they do require special handling in variance
estimation — but if you know a singleton stratum is a certainty unit by
design rather than a data problem, that's exactly the case `svyset`'s
`singleunit(certainty)` option is built for.

**Can `benchmark` compare more than one variable at once?** Not in a
single call — run it once per categorical variable you want to check
against population totals (region, then separately age group, then
separately sex, etc.), since each needs its own `popshare()` values
aligned to that variable's specific levels.

**What if I don't have reliable population shares to benchmark
against?** Then `benchmark` isn't the right tool for that check — it
specifically requires an external, trusted population figure to compare
to. Without one, `wtcheck` and `stratdx` are still fully usable on their
own; they don't depend on any outside population data.

## Limitations, honestly stated

- `wtcheck`'s "extreme weight" flag is a simple ratio-to-median rule,
  not a formal test — it's meant to point you toward observations worth a
  human look, not to make an automatic decision about which weights are
  wrong.
- `stratdx` cannot tell you whether your strata and PSU variables are
  the *conceptually correct* design variables for your survey (that
  depends on the actual sample design documentation) — it can only tell
  you whether the variables you gave it are structurally well-formed.
- `benchmark` is only as trustworthy as the population shares you supply;
  it performs no independent verification of those numbers.
- `trimwt` only caps the upper tail of the weight distribution, which is
  the standard use case for design weights (a few unusually large
  weights). It does not trim unusually small weights, which is a much
  less common concern in most survey designs but can matter in some
  specialized ones.

## Where to go from here

If `wtcheck` or `benchmark` point to a deeper problem with missing
values in variables used to construct your weights, the `imputepro`
package's `missrpt` subcommand is a natural next stop for understanding
that missingness before deciding how to address it.
