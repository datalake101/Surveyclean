{smcl}
{* *! version 1.0.0  30aug2026}{...}
{viewerjumpto "Syntax" "surveyclean##syntax"}{...}
{viewerjumpto "Description" "surveyclean##description"}{...}
{viewerjumpto "Subcommands" "surveyclean##subcommands"}{...}
{viewerjumpto "Examples" "surveyclean##examples"}{...}
{title:Title}

{phang}
{bf:surveyclean} {hline 2} Survey data tools

{marker syntax}{...}
{title:Syntax}

{p 8 15 2}
{cmd:surveyclean} {it:subcommand} ...

{p 8 15 2}where {it:subcommand} is one of:

{p2colset 9 26 28 2}
{p2col:{cmd:wtcheck}}validate a survey weight variable{p_end}
{p2col:{cmd:stratdx}}check strata/PSU design structure{p_end}
{p2col:{cmd:benchmark}}compare sample shares against known population shares{p_end}
{p2col:{cmd:trimwt}}trim/cap extreme survey weights{p_end}
{p2colreset}{...}

{marker description}{...}
{title:Description}

{pstd}
{cmd:surveyclean} checks the plumbing of a complex-survey dataset before
you {cmd:svyset} it and start estimating: are the weights sane, is the
strata/PSU design well-formed, does the weighted sample track known
population totals, and are a handful of huge weights about to dominate
your standard errors.

{marker subcommands}{...}
{title:Subcommands}

{dlgtab:wtcheck}

{p 8 15 2}{cmd:surveyclean wtcheck} {it:weightvar} [{cmd:,} {cmdab:threshold(}{it:#}{cmd:)}]

{pstd}Reports missing, zero, and negative weights (all invalid for
estimation), plus mean/median/SD/CV/min/max, and flags weights more
than {cmd:threshold()} times the median (default 10). Returns
{cmd:r(n_miss)}, {cmd:r(n_zero)}, {cmd:r(n_neg)}, {cmd:r(n_extreme)},
{cmd:r(mean_w)}, {cmd:r(cv_w)}.

{dlgtab:stratdx}

{p 8 15 2}{cmd:surveyclean stratdx, } {cmdab:strata(}{it:varname}{cmd:)} {cmdab:psu(}{it:varname}{cmd:)}

{pstd}Reports the number of strata and PSUs, PSUs per stratum, and flags
two common design problems: singleton strata (only one PSU, which
breaks linearized variance estimation unless handled) and PSU codes
that are not uniquely nested within a single stratum (common when PSU
IDs are only unique {it:within} a stratum, e.g. "PSU 1" in every
stratum). Returns {cmd:r(n_strata)}, {cmd:r(n_psu)},
{cmd:r(n_singleton)}, {cmd:r(n_badpsu_nesting)}.

{dlgtab:benchmark}

{p 8 15 2}{cmd:surveyclean benchmark} {it:catvar} {cmd:,} {cmdab:weight(}{it:varname}{cmd:)} {cmdab:popshare(}{it:numlist}{cmd:)}

{pstd}Compares the unweighted and weighted sample share of each level of
{it:catvar} against known population shares you supply in
{cmd:popshare()}, one percentage value per level of {it:catvar} in
ascending order. A weighted share far from the population share can
indicate a weighting or non-response problem. Returns
{cmd:r(n_levels)}.

{dlgtab:trimwt}

{p 8 15 2}{cmd:surveyclean trimwt} {it:weightvar} [{cmd:,} {cmdab:method(}percentile|median{cmd:)} {cmdab:pctile(}{it:#}{cmd:)} {cmdab:mult(}{it:#}{cmd:)} {cmdab:generate(}{it:name}{cmd:)} {cmdab:replace}]

{pstd}Caps {it:weightvar} at either a given percentile (default: 99th)
or a multiple of the median (default: 5x), a standard ad hoc way to
limit the influence of a few extreme design weights. By default creates
{cmd:trimw_*}; use {cmd:replace} to modify in place. Returns
{cmd:r(cap)}, {cmd:r(n_trimmed)}.

{marker examples}{...}
{title:Examples}

{phang}{cmd:. surveyclean wtcheck pweight, threshold(8)}{p_end}
{phang}{cmd:. surveyclean stratdx, strata(stratum) psu(psu)}{p_end}
{phang}{cmd:. surveyclean benchmark region, weight(pweight) popshare(25 25 30 20)}{p_end}
{phang}{cmd:. surveyclean trimwt pweight, method(median) mult(5)}{p_end}
{phang}{cmd:. svyset psu [pweight=trimw_pweight], strata(stratum)}{p_end}

{title:Author}

{pstd}Bishwajit Ghose {hline 2} gb@infoart.ca {hline 2} infoart.ca{p_end}
