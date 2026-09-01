clear all
snapshot erase _all

global key "C:\\Users\\hermesf\\Projects\\HF_Strategies\\key dataframe"

cap log close
log using "$key\\dealer_fragility.log", replace text

**# Country-specific CDS shocks, daily
* daily log changes, leave-one-out demeaned across the other three countries

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
drop if missing(log_change)
bysort date: egen sum_log_change = total(log_change)
bysort date: gen n_countries = _N
keep if n_countries == 4
gen shock_rel = log_change - (sum_log_change - log_change)/3 /*own move minus avg move of the other three*/
bysort country: egen sd_rel = sd(shock_rel)

**# Events
* a stress day is a relative widening beyond two standard deviations, an event
* is a stress day with no other stress day in the previous 20 business days

gen stress_day = shock_rel > 2*sd_rel
sort country date
by country: gen cum_stress = sum(stress_day)
by country: gen stress_20d = cum_stress - cond(_n > 20, cum_stress[_n-20], 0)
gen event = stress_day == 1 & stress_20d == 1
keep if event
keep country date
rename date event_date
gen event_id = _n
list event_id country event_date, clean
tempfile events
save `events'

**# Dealer nationality

import delimited "$key\\dealer_nationality.csv", varnames(1) clear
tempfile dealer_nat
save `dealer_nat'

**# Flow panel around events, pre and post windows of 30 calendar days
* new business per pair, window, and collateral country

import delimited "$key\\fund_dealer_country_day_flow.csv", varnames(1) clear
capture drop v1
foreach v in borrowing_flow lending_flow {
	replace `v' = 0 if missing(`v')
}
gen date = date(business_date, "YMD")
format date %td
cross using `events'
keep if inrange(date, event_date - 30, event_date + 29)
gen post = date >= event_date
collapse (sum) borrowing_flow lending_flow, by(fund_id dealer_id collateral_country country event_id post)

reshape wide borrowing_flow lending_flow, i(fund_id dealer_id collateral_country country event_id) j(post)
foreach v in borrowing_flow0 borrowing_flow1 lending_flow0 lending_flow1 {
	replace `v' = 0 if missing(`v')
}
merge m:1 dealer_id using `dealer_nat', keep(match) nogen
gen treated = nationality == country
label var treated "Dealer from the stressed country"
tempfile pair_country_events
save `pair_country_events'

**# KM intensive margin: change in new business, within fund x event
* pairs with positive flows before and after, treated vs untreated dealers

collapse (sum) borrowing_flow0 borrowing_flow1 lending_flow0 lending_flow1 (max) treated, by(fund_id dealer_id country event_id)
gen dlog_borrowing = log(borrowing_flow1) - log(borrowing_flow0)
gen dlog_lending = log(lending_flow1) - log(lending_flow0)
egen fund_event = group(fund_id event_id)
egen dealer_num = group(dealer_id)
label var dlog_borrowing "Change in log new borrowing, post minus pre"
label var dlog_lending "Change in log new lending, post minus pre"

foreach y in dlog_borrowing dlog_lending {
	reghdfe `y' treated, a(fund_event dealer_num) vce(cluster dealer_id)
}

**# Extensive margin: exit among pre-active pairs, entry among post-active pairs

gen exit_borrowing = borrowing_flow0 > 0 & borrowing_flow1 == 0
gen entry_borrowing = borrowing_flow0 == 0 & borrowing_flow1 > 0
gen exit_lending = lending_flow0 > 0 & lending_flow1 == 0
gen entry_lending = lending_flow0 == 0 & lending_flow1 > 0

foreach l in borrowing lending {
	reghdfe exit_`l' treated if `l'_flow0 > 0, a(fund_event dealer_num) vce(cluster dealer_id)
	reghdfe entry_`l' treated if `l'_flow1 > 0, a(fund_event dealer_num) vce(cluster dealer_id)
}
tempfile pair_events
save `pair_events'

**# Non-home collateral split: supply shows up in other countries' collateral
* fund x collateral country x event effects absorb the stressed market's demand

use `pair_country_events', clear
gen dlog_borrowing = log(borrowing_flow1) - log(borrowing_flow0)
gen dlog_lending = log(lending_flow1) - log(lending_flow0)
gen treated_own = treated*(collateral_country == country)
gen treated_other = treated*(collateral_country != country)
egen fund_country_event = group(fund_id collateral_country event_id)
egen dealer_num = group(dealer_id)
label var treated_own "Treated dealer, stressed country collateral"
label var treated_other "Treated dealer, other collateral"

foreach y in dlog_borrowing dlog_lending {
	reghdfe `y' treated_other treated_own, a(fund_country_event dealer_num) vce(cluster dealer_id)
}

**# Fund level: can funds replace the treated dealers, within event
* exposure = share of the fund's pre window flow via treated dealers

use `pair_events', clear
gen treated_borrowing0 = treated*borrowing_flow0
gen treated_lending0 = treated*lending_flow0
collapse (sum) borrowing_flow0 borrowing_flow1 lending_flow0 lending_flow1 treated_borrowing0 treated_lending0, by(fund_id event_id)
gen exposure_borrowing = treated_borrowing0/borrowing_flow0
gen exposure_lending = treated_lending0/lending_flow0
gen dlog_borrowing = log(borrowing_flow1) - log(borrowing_flow0)
gen dlog_lending = log(lending_flow1) - log(lending_flow0)
label var exposure_borrowing "Pre window borrowing share via treated dealers"
label var exposure_lending "Pre window lending share via treated dealers"

foreach l in borrowing lending {
	reghdfe dlog_`l' exposure_`l', a(event_id) vce(cluster fund_id)
}

log close
