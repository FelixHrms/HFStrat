clear all
snapshot erase _all

global key "C:\\Users\\hermesf\\Projects\\HF_Strategies\\key dataframe"

cap log close
log using "$key\\dealer_fragility.log", replace text

**# Step 1: country-specific CDS shocks
* daily log changes, leave-one-out demeaned across the other three countries,
* rescaled to bp by the lagged own level, cumulated over a 20-day window

tempfile cds_all
local first = 1
foreach c in Germany France Italy Spain {
	import delimited "$key\\`c'_CDS.csv", varnames(1) clear
	capture drop v3
	gen country = cond("`c'"=="Germany","DE", cond("`c'"=="France","FR", cond("`c'"=="Italy","IT","ES")))
	if `first' == 0 append using `cds_all'
	local first = 0
	save `cds_all', replace
}
gen date = date(period, "DMY")
format date %td
sort country date
by country: gen log_change = log(cds) - log(cds[_n-1])
by country: gen cds_lag = cds[_n-1]
drop if missing(log_change)
bysort date: egen sum_log_change = total(log_change)
bysort date: gen n_countries = _N
keep if n_countries == 4
gen shock_rel = log_change - (sum_log_change - log_change)/3 /*own move minus avg move of the other three*/
gen shock_daily = shock_rel*cds_lag /*back to bp using own lagged level*/
bysort country: egen sd_rel = sd(shock_rel)
gen tail_daily = shock_daily*(abs(shock_rel) > 2*sd_rel) /*only moves beyond 2 sd count*/

local W = 20 /*business-day window*/
sort country date
by country: gen running_sum = sum(shock_daily)
by country: gen running_sum_tail = sum(tail_daily)
by country: gen shock_cum = running_sum - running_sum[_n-`W']
by country: gen tail_cum = running_sum_tail - running_sum_tail[_n-`W']
drop if missing(shock_cum)
keep country date shock_cum tail_cum
reshape wide shock_cum tail_cum, i(date) j(country) string
tempfile country_shocks
save `country_shocks'

log close
