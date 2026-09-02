*! surveyclean_trimwt.ado - version 1.0.0 - 30aug2026
*! caps extreme survey weights at a percentile or a multiple of the
*! median, and reports how many observations were affected
program define surveyclean_trimwt, rclass
    version 14.0
    syntax varname(numeric) [if] [in], [METHOD(string) PCTILE(real 99) MULT(real 5) GENerate(name) REPLACE]

    marksample touse
    local wv `varlist'

    local method = lower("`method'")
    if "`method'" == "" local method "percentile"
    if !inlist("`method'", "percentile", "median") {
        di as error "method() must be percentile or median"
        exit 198
    }

    if "`generate'" == "" local generate "trimw_`wv'"

    if "`replace'" != "" {
        local newv "`wv'"
    }
    else {
        local newv "`generate'"
        capture confirm new variable `newv'
        if _rc {
            di as error "`newv' already exists; choose a different generate() name"
            exit 110
        }
        quietly gen `newv' = `wv'
    }

    if "`method'" == "percentile" {
        quietly centile `newv' if `touse', centile(`pctile')
        local cap = r(c_1)
    }
    else {
        quietly summarize `newv' if `touse', detail
        local med = r(p50)
        local cap = `mult' * `med'
    }

    quietly count if `newv' > `cap' & `touse'
    local ntrim = r(N)

    quietly replace `newv' = `cap' if `newv' > `cap' & `touse'

    di as text ""
    di as text "{hline 60}"
    di as text "Weight trimming: `wv' -> `newv'  (method: `method')"
    di as text "{hline 60}"
    di as text "Cap value:              " as result %12.4f `cap'
    di as text "Observations trimmed:   " as result %9.0f `ntrim'
    di as text "{hline 60}"

    return scalar cap = `cap'
    return scalar n_trimmed = `ntrim'
end
