clear all
snapshot erase _all

global key "C:\\Users\\hermesf\\Projects\\HF_Strategies\\key dataframe"

cap log close
log using "$key\\dealer_fragility.log", replace text

**# Step 1: dealer-specific CDS shocks from the Bloomberg series
* daily log changes of each 5 year CDS, leave-one-out demeaned across the other
* series on the day, rescaled to bp by the lagged own level, cumulated over a
* 20-day window, built once per series and mapped to the LEIs of the same group

import delimited "$key\\dealer_cds.csv", varnames(1) clear
capture drop v1
gen date = date(period, "YMD")
format date %td
preserve
	keep dealer_id bloomberg
	duplicates drop
	tempfile cds_map
	save `cds_map'
restore
keep bloomberg date cds
duplicates drop
drop if missing(cds)
drop if strpos(bloomberg, "NDAFH") /*Nordea series is a near copy of Credit Agricole, excluded for now*/
sort bloomberg date
by bloomberg: gen log_change = log(cds) - log(cds[_n-1])
by bloomberg: gen cds_lag = cds[_n-1]
drop if missing(log_change)
bysort date: egen sum_log_change = total(log_change)
bysort date: gen n_series = _N
gen shock_rel = log_change - (sum_log_change - log_change)/(n_series - 1) /*own move minus avg move of the other series*/
gen shock_daily = shock_rel*cds_lag /*back to bp using own lagged level*/

local W = 20 /*business-day window, robustness at 5 10 40*/
sort bloomberg date
by bloomberg: gen running_sum = sum(shock_daily)
by bloomberg: gen bank_shock = running_sum - running_sum[_n-`W']
drop if missing(bank_shock)
keep bloomberg date bank_shock
joinby bloomberg using `cds_map'
keep dealer_id date bank_shock
label var bank_shock "Dealer CDS shock (20d cum.)"
tempfile bank_shocks
save `bank_shocks'

**# Step 2: panel, fund x dealer x day
* outstanding positions from the state data, dealers and MFIs, log outcomes,
* KM style unbalanced, entities without a CDS series drop out at the merge

import delimited "$key\\fund_dealer_day.csv", varnames(1) clear
capture drop v1
gen date = date(business_date, "YMD")
format date %td
gen month = mofd(date)

merge m:1 dealer_id date using `bank_shocks', keep(match) nogen

gen log_borrowing = log(borrowing_volume) /*financing of longs*/
gen log_lending = log(lending_volume) /*cash lending, the short side*/
gen net_position = cond(missing(borrowing_volume), 0, borrowing_volume) - cond(missing(lending_volume), 0, lending_volume)
gen log_net = log(abs(net_position)) /*absolute value since net can be negative, noisy when the two legs are close*/

egen fund_day = group(fund_id date)
egen pair = group(fund_id dealer_id)

**# Step 3: the lending channel, within fund x day across dealers
* beta = per bp of cumulated CDS widening of the dealer, the pair's deviation
* from its own level relative to the fund's other pairs on the same day

bysort fund_day (pair): gen multi_dealer = pair[1] != pair[_N]
tab multi_dealer

foreach y in log_borrowing log_lending log_net {
	reghdfe `y' bank_shock, a(fund_day pair) vce(cluster month)
}

**# Step 4: fund level, can funds offset the shock in total
* exposure = wallet-weighted CDS shock across the fund's dealers, wallet shares
* from the lagged quarter, outcome = the fund's total positions, step 3
* coefficient = step 4 coefficient means full pass-through

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

	use `bank_shocks', clear
	gen quarter = qofd(date)
	joinby dealer_id quarter using `fund_weights'
	gen product = wallet_share*bank_shock /*weighted average of the dealers' shocks, shares sum to one*/
	collapse (sum) fund_exposure = product, by(fund_id date)
	tempfile fund_exposures
	save `fund_exposures'
restore

preserve
	bysort fund_id date: gen n_dealers = _N /*active dealers of the fund that day*/
	collapse (sum) borrowing_volume lending_volume (mean) n_dealers, by(fund_id date month)
	merge m:1 fund_id date using `fund_exposures', keep(match) nogen
	gen log_borrowing = log(borrowing_volume)
	gen log_lending = log(lending_volume)
	gen log_net = log(abs(borrowing_volume - lending_volume))
	egen fund_num = group(fund_id)
	label var fund_exposure "Wallet-weighted dealer CDS shock of the fund's dealers"
	foreach y in log_borrowing log_lending log_net {
		reghdfe `y' fund_exposure, a(fund_num date) vce(cluster month)
	}
	foreach y in log_borrowing log_lending log_net {
		reghdfe `y' fund_exposure if n_dealers > 1, a(fund_num date) vce(cluster month) /*same fund days as step 3, funds that could substitute*/
	}
restore

**# Step 5: substitution, do funds increase business at their other dealers
* within dealer x day across funds, other_exposure = wallet-weighted shock of
* the fund's other dealers, fund x month effects absorb slow-moving demand,
* the demand bias is downward so a positive coefficient is robust evidence

gen quarter = qofd(date)
merge m:1 fund_id date using `fund_exposures', keep(master match) nogen
merge m:1 fund_id dealer_id quarter using `fund_weights', keep(master match) nogen
gen other_exposure = fund_exposure
replace other_exposure = fund_exposure - wallet_share*bank_shock if !missing(wallet_share) /*leave out the own dealer*/
label var other_exposure "Wallet-weighted dealer CDS shock of the fund's other dealers"

egen dealer_day = group(dealer_id date)
egen fund_month = group(fund_id month)
foreach y in log_borrowing log_lending log_net {
	reghdfe `y' other_exposure wallet_share, a(dealer_day pair fund_month) vce(cluster month)
}

log close
