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

local W = 20 /*business-day window, robustness at 5 10 40*/
sort country date
by country: gen running_sum = sum(shock_daily)
by country: gen shock_cum = running_sum - running_sum[_n-`W']
drop if missing(shock_cum)
keep country date shock_cum
reshape wide shock_cum, i(date) j(country) string
tempfile country_shocks
save `country_shocks'

**# Step 2: dealer home shocks, dealer x day
* home shock = the cumulated shock of the dealer's home country, by the
* nationality of the ultimate parent, zero for non EA dealers

import delimited "$key\\dealer_nationality.csv", varnames(1) clear
tempfile dealer_nat
save `dealer_nat'

use `country_shocks', clear
cross using `dealer_nat'
gen home_shock = 0
foreach c in DE FR IT ES {
	replace home_shock = shock_cum`c' if nationality == "`c'"
}
keep dealer_id date nationality home_shock
label var home_shock "Home country shock (20d cum.)"
tempfile dealer_shocks
save `dealer_shocks'

**# Step 3: panel, fund x dealer x day
* outstanding positions from the state data, log outcomes, KM style
* unbalanced, a pair day without positions is simply not in the sample

import delimited "$key\\fund_dealer_day.csv", varnames(1) clear
capture drop v1
gen date = date(business_date, "YMD")
format date %td
gen month = mofd(date)

merge m:1 dealer_id date using `dealer_shocks', keep(match) nogen

gen log_borrowing = log(borrowing_volume) /*financing of longs*/
gen log_lending = log(lending_volume) /*cash lending, the short side*/

egen fund_day = group(fund_id date)
egen pair = group(fund_id dealer_id)

**# Step 4: the lending channel, within fund x day across dealers
* beta = per bp of cumulated home CDS widening, the pair's deviation from its
* own level relative to the fund's other pairs on the same day, demand absorbed

bysort fund_day (pair): gen multi_dealer = pair[1] != pair[_N]
tab multi_dealer

foreach y in log_borrowing log_lending {
	reghdfe `y' home_shock, a(fund_day pair) vce(cluster month)
}

**# Step 5: fund level, can funds offset the shock in total
* exposure = wallet-weighted home shock across the fund's dealers, wallet
* shares from the lagged quarter, outcome = the fund's total positions
* step 4 coefficient = step 5 coefficient means full pass-through, step 5
* near zero means funds offset the shock elsewhere

preserve
	foreach v in borrowing_volume lending_volume {
		replace `v' = 0 if missing(`v')
	}
	gen volume = borrowing_volume + lending_volume
	gen quarter = qofd(date) + 1 /*weights used one quarter later*/
	collapse (sum) volume, by(fund_id dealer_id quarter)
	bysort fund_id quarter: egen total = total(volume)
	gen wallet_share = volume/total
	keep fund_id dealer_id quarter wallet_share
	tempfile fund_weights
	save `fund_weights'

	use `dealer_shocks', clear
	gen quarter = qofd(date)
	joinby dealer_id quarter using `fund_weights'
	gen product = wallet_share*home_shock
	collapse (sum) fund_exposure = product, by(fund_id date)
	tempfile fund_exposures
	save `fund_exposures'
restore

preserve
	collapse (sum) borrowing_volume lending_volume, by(fund_id date month)
	merge m:1 fund_id date using `fund_exposures', keep(match) nogen
	collapse (mean) borrowing_volume lending_volume fund_exposure, by(fund_id month) /*monthly averages against daily noise*/
	gen log_borrowing = log(borrowing_volume)
	gen log_lending = log(lending_volume)
	egen fund_num = group(fund_id)
	label var fund_exposure "Wallet-weighted home shock of the fund's dealers"
	foreach y in log_borrowing log_lending {
		reghdfe `y' fund_exposure, a(fund_num month) vce(cluster month)
	}
restore

log close
