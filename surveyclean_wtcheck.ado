*! surveyclean_wtcheck.ado - version 1.0.0 - 30aug2026
*! validates a survey weight variable: missing, zero, negative, and
*! extreme values relative to the median
program define surveyclean_wtcheck, rclass
    version 14.0
    syntax varname(numeric) [if] [in], [THRESHOLD(real 10)]

    marksample touse
    local wv `varlist'

    quietly count if `touse'
    local N = r(N)

    quietly count if missing(`wv') & `touse'
    local nmiss = r(N)
    quietly count if `wv' == 0 & `touse' & !missing(`wv')
    local nzero = r(N)
    quietly count if `wv' < 0 & `touse' & !missing(`wv')
    local nneg = r(N)

    quietly summarize `wv' if `touse' & !missing(`wv'), detail
    local mean_w = r(mean)
    local sd_w = r(sd)
    local min_w = r(min)
    local max_w = r(max)
    local med_w = r(p50)
    local cv_w = `sd_w' / `mean_w'

    quietly count if `wv' > `threshold' * `med_w' & `touse' & !missing(`wv')
    local nextreme = r(N)

    di as text ""
    di as text "{hline 60}"
    di as text "Survey weight check: `wv'"
    di as text "{hline 60}"
    di as text "N observations:          " as result %9.0f `N'
    di as text "Missing weights:         " as result %9.0f `nmiss'
    di as text "Zero weights:            " as result %9.0f `nzero'
    di as text "Negative weights:        " as result %9.0f `nneg'
    di as text "{hline 60}"
    di as text "Mean:    " as result %10.3f `mean_w'
    di as text "Median:  " as result %10.3f `med_w'
    di as text "SD:      " as result %10.3f `sd_w'
    di as text "CV:      " as result %10.3f `cv_w'
    di as text "Min:     " as result %10.3f `min_w'
    di as text "Max:     " as result %10.3f `max_w'
    di as text "{hline 60}"
    di as text "Weights > `threshold'x median (possible extreme values): " as result `nextreme'
    di as text "{hline 60}"

    if `nneg' > 0 {
        di as error "WARNING: negative weights are invalid and will break most survey estimators"
    }
    if `nmiss' > 0 {
        di as error "WARNING: missing weights cause those observations to be dropped by svyset/aweight/pweight"
    }

    return scalar n_miss = `nmiss'
    return scalar n_zero = `nzero'
    return scalar n_neg = `nneg'
    return scalar n_extreme = `nextreme'
    return scalar mean_w = `mean_w'
    return scalar cv_w = `cv_w'
end
