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

**# Dealer collateral-country weights, lagged quarter
* share of each country's collateral in the dealer's full repo book,
* time-averaged over the previous quarter

import delimited "$key\\dealer_country_day.csv", varnames(1) clear
capture drop v1
keep if inlist(collateral_country, "DE", "FR", "IT", "ES")
foreach v in borrowing_volume lending_volume {
	replace `v' = 0 if missing(`v')
}
gen volume = borrowing_volume + lending_volume
gen date = date(business_date, "YMD")
gen quarter = qofd(date) + 1 /*weights used one quarter later*/
collapse (sum) volume, by(dealer_id collateral_country quarter)
bysort dealer_id quarter: egen total = total(volume)
gen dealer_share = volume/total
drop volume total
reshape wide dealer_share, i(dealer_id quarter) j(collateral_country) string
foreach c in DE FR IT ES {
	replace dealer_share`c' = 0 if missing(dealer_share`c')
}
tempfile dealer_weights
save `dealer_weights'

**# Dealer shock = portfolio-weighted CDS shock, dealer x day

use `country_shocks', clear
gen quarter = qofd(date)
joinby quarter using `dealer_weights'
gen dealer_shock = dealer_shareDE*shock_cumDE + dealer_shareFR*shock_cumFR + dealer_shareIT*shock_cumIT + dealer_shareES*shock_cumES
gen dealer_shock_tail = dealer_shareDE*tail_cumDE + dealer_shareFR*tail_cumFR + dealer_shareIT*tail_cumIT + dealer_shareES*tail_cumES
keep dealer_id date dealer_shock dealer_shock_tail
tempfile dealer_shocks
save `dealer_shocks'

**# Fund wallet weights across dealers (two-sided), lagged quarter
* share of each dealer in the fund's total repo activity

import delimited "$key\\fund_dealer_isin_day.csv", varnames(1) clear
capture drop v1
foreach v in borrowing_volume lending_volume {
	replace `v' = 0 if missing(`v')
}
gen volume = borrowing_volume + lending_volume
gen date = date(business_date, "YMD")
gen quarter = qofd(date) + 1
collapse (sum) volume, by(fund_id dealer_id quarter)
bysort fund_id quarter: egen total = total(volume)
gen wallet_share = volume/total
keep fund_id dealer_id quarter wallet_share
tempfile fund_weights
save `fund_weights'

**# Fund exposure = wallet-weighted dealer shocks, fund x day

use `dealer_shocks', clear
gen quarter = qofd(date)
joinby dealer_id quarter using `fund_weights'
gen product = wallet_share*dealer_shock
gen product_tail = wallet_share*dealer_shock_tail
collapse (sum) fund_exposure_all = product fund_exposure_all_tail = product_tail, by(fund_id date)
tempfile fund_exposures
save `fund_exposures'

**# Panel

import delimited "$key\\fund_dealer_isin_day.csv", varnames(1) clear
capture drop v1
gen date = date(business_date, "YMD")
format date %td
gen country = substr(security_isin, 1, 2)
keep if inlist(country, "DE", "FR", "IT", "ES")
gen quarter = qofd(date)

merge m:1 date using `country_shocks', keep(match) nogen
merge m:1 dealer_id quarter using `dealer_weights', keep(match) nogen
gen dealer_exposure = 0
foreach c in DE FR IT ES {
	replace dealer_exposure = dealer_exposure + dealer_share`c'*shock_cum`c' if country != "`c'" /*exclude the collateral country of the bond*/
}

merge m:1 fund_id date using `fund_exposures', keep(master match) nogen
merge m:1 fund_id dealer_id quarter using `fund_weights', keep(master match) nogen
merge m:1 dealer_id date using `dealer_shocks', keep(master match) nogen
gen fund_exposure_other = fund_exposure_all
replace fund_exposure_other = fund_exposure_all - wallet_share*dealer_shock if !missing(fund_exposure_all, wallet_share, dealer_shock) /*leave out the own dealer*/
gen fund_exposure_other_tail = fund_exposure_all_tail
replace fund_exposure_other_tail = fund_exposure_all_tail - wallet_share*dealer_shock_tail if !missing(fund_exposure_all_tail, wallet_share, dealer_shock_tail)

foreach v in borrowing_volume lending_volume {
	replace `v' = 0 if missing(`v')
}
gen net_position = (borrowing_volume - lending_volume)/10^9 /*net long position in bn*/
gen log_total_volume = log(borrowing_volume + lending_volume) /*intermediation volume*/

gen month = mofd(date)
egen fund_country_day = group(fund_id country date)
egen dealer_country_day = group(dealer_id country date)
egen bond_day = group(security_isin date)
egen fund_num = group(fund_id)
egen dealer_num = group(dealer_id)

label var dealer_exposure "Dealer exposure (20d cum.)"
label var fund_exposure_other "Fund exposure via other dealers (20d cum.)"
label var fund_exposure_other_tail "Fund exposure via other dealers (>2sd)"

**# Support: multi-dealer / multi-fund cells, both-sided pairs

bysort fund_country_day (dealer_num): gen multi_dealer = dealer_num[1] != dealer_num[_N]
bysort dealer_country_day (fund_num): gen multi_fund = fund_num[1] != fund_num[_N]
tab multi_dealer if !missing(dealer_exposure)
tab multi_fund if !missing(fund_exposure_other)

**# Hop 1: shock -> dealer -> fund, within fund x country x day

reghdfe net_position dealer_exposure, a(fund_country_day bond_day dealer_num) vce(cluster month)
reghdfe log_total_volume dealer_exposure, a(fund_country_day bond_day dealer_num) vce(cluster month)

**# Hop 2: shocked dealers -> fund -> other dealer, within dealer x country x day

reghdfe net_position fund_exposure_other, a(dealer_country_day bond_day fund_num) vce(cluster month)
reghdfe log_total_volume fund_exposure_other, a(dealer_country_day bond_day fund_num) vce(cluster month)
reghdfe net_position fund_exposure_other_tail, a(dealer_country_day bond_day fund_num) vce(cluster month) /*tail robustness*/

**# Fund aggregate: does the shock reach the fund's total book

preserve
	collapse (sum) net_position, by(fund_id date month)
	merge m:1 fund_id date using `fund_exposures', keep(match) nogen
	egen fund_num = group(fund_id)
	reghdfe net_position fund_exposure_all, a(fund_num date) vce(cluster month)
restore

log close
