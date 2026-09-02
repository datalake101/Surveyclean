*! surveyclean.ado - version 1.0.0 - 30aug2026
*! Survey data tools
*! Author: [Your Name]
program define surveyclean
    version 14.0

    gettoken subcmd 0 : 0, parse(" ,")
    local subcmd = lower("`subcmd'")

    local valid "wtcheck stratdx benchmark trimwt"
    local ok : list subcmd in valid
    if !`ok' {
        di as error "surveyclean: unrecognized subcommand {bf:`subcmd'}"
        di as error "valid subcommands are: `valid'"
        di as error "type {stata help surveyclean} for details"
        exit 198
    }

    surveyclean_`subcmd' `0'
end
