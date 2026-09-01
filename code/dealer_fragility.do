clear all
snapshot erase _all

global key "C:\\Users\\hermesf\\Projects\\HF_Strategies\\key dataframe"

cap log close
log using "$key\\dealer_fragility.log", replace text

**# Country-specific CDS shocks
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

**# Dealer home shocks, dealer x day
* home shock = the cumulated shock of the dealer's home country, zero for non EA dealers

import delimited "$key\\dealer_nationality.csv", varnames(1) clear
tempfile dealer_nat
save `dealer_nat'

use `country_shocks', clear
cross using `dealer_nat'
gen home_shock = 0
gen home_shock_tail = 0
foreach c in DE FR IT ES {
	replace home_shock = shock_cum`c' if nationality == "`c'"
	replace home_shock_tail = tail_cum`c' if nationality == "`c'"
}
keep dealer_id date nationality home_shock home_shock_tail
tempfile dealer_shocks
save `dealer_shocks'

**# Fund wallet weights across dealers (two-sided), lagged quarter
* share of each dealer in the fund's total repo activity

import delimited "$key\\fund_dealer_day.csv", varnames(1) clear
capture drop v1
foreach v in borrowing_volume lending_volume {
	replace `v' = 0 if missing(`v')
}
gen volume = borrowing_volume + lending_volume
gen date = date(business_date, "YMD")
gen quarter = qofd(date) + 1 /*weights used one quarter later*/
collapse (sum) volume, by(fund_id dealer_id quarter)
bysort fund_id quarter: egen total = total(volume)
gen wallet_share = volume/total
keep fund_id dealer_id quarter wallet_share
tempfile fund_weights
save `fund_weights'

**# Fund exposure = wallet-weighted home shock of its dealers, fund x day

use `dealer_shocks', clear
gen quarter = qofd(date)
joinby dealer_id quarter using `fund_weights'
gen product = wallet_share*home_shock
collapse (sum) fund_exposure_all = product, by(fund_id date)
tempfile fund_exposures
save `fund_exposures'

**# Panel, fund x dealer x day

import delimited "$key\\fund_dealer_day.csv", varnames(1) clear
capture drop v1
gen date = date(business_date, "YMD")
format date %td
gen month = mofd(date)

merge m:1 dealer_id date using `dealer_shocks', keep(match) nogen

gen quarter = qofd(date)
merge m:1 fund_id date using `fund_exposures', keep(master match) nogen
merge m:1 fund_id dealer_id quarter using `fund_weights', keep(master match) nogen
gen other_exposure = fund_exposure_all
replace other_exposure = fund_exposure_all - wallet_share*home_shock if !missing(wallet_share) /*leave out the own dealer*/

gen log_borrowing = log(borrowing_volume) /*financing of longs, KM intensive margin*/
gen log_lending = log(lending_volume) /*cash lending, the short side*/

egen fund_day = group(fund_id date)
egen fund_num = group(fund_id)
egen pair = group(fund_id dealer_id)

label var home_shock "Home country shock (20d cum.)"
label var home_shock_tail "Home country shock (>2sd)"
label var other_exposure "Wallet-weighted home shock of the fund's other dealers"

**# Support: multi-dealer funds

bysort fund_day (pair): gen multi_dealer = pair[1] != pair[_N]
tab multi_dealer

**# Part 1: bank lending channel, within fund x day across dealers
* home_shock = effect on the shocked dealer, other_exposure = substitution toward this dealer

foreach y in log_borrowing log_lending {
	reghdfe `y' home_shock other_exposure, a(fund_day pair) vce(cluster month)
}

**# Part 2: fund borrowing channel, fund x day totals

collapse (sum) borrowing_volume lending_volume, by(fund_id fund_num date month)
merge m:1 fund_id date using `fund_exposures', keep(match) nogen
gen log_borrowing = log(borrowing_volume)
gen log_lending = log(lending_volume)
label var fund_exposure_all "Fund exposure, wallet-weighted home shock (20d cum.)"

foreach y in log_borrowing log_lending {
	reghdfe `y' fund_exposure_all, a(fund_num date) vce(cluster month)
}

log close
