clear all
snapshot erase _all

global key "C:\\Users\\hermesf\\Projects\\HF_Strategies\\key dataframe"

cap log close
log using "$key\\dealer_fragility_svb.log", replace text

**# Event study around SVB, 10 March 2023, following Khwaja and Mian
* the time dimension collapses to one pre and one post observation per pair,
* window sums of outstanding positions over H calendar days on each side,
* treated = dealers with a US parent, all other dealers are the controls,
* the continuous version uses the log change of the dealer's own CDS between
* the two windows, KM's bank liquidity change, dealers only, no MFIs

local event = td(10mar2023)
local H = 60 /*window length in calendar days, robustness at 30 90*/

**# Step 1: dealer treatment

import delimited "$key\\dealer_nationality.csv", varnames(1) clear
keep dealer_id /*the dealer list, nationality now comes from the Bloomberg sheet*/
tempfile dealer_list
save `dealer_list'

import delimited "$key\\dealer_cds.csv", varnames(1) clear
capture drop v1
gen date = date(period, "YMD")
keep if inrange(date, `event' - `H', `event' + `H' - 1)
gen post = date >= `event'
collapse (mean) cds (first) nationality, by(dealer_id post)
reshape wide cds, i(dealer_id nationality) j(post)
merge 1:1 dealer_id using `dealer_list', keep(match) nogen
gen treated = nationality == "US"
gen dcds = log(cds1) - log(cds0) /*log change of the dealer's CDS, post over pre window*/
label var treated "US parent"
label var dcds "Log change in dealer CDS around the event"
list dealer_id nationality treated dcds, clean
tempfile dealers
save `dealers'

**# Step 2: pair level, one pre and one post observation
* window sums of daily positions, absent days count as zero, log differences
* only for pairs active in both windows as in KM's intensive margin

import delimited "$key\\fund_dealer_day.csv", varnames(1) clear
capture drop v1
gen date = date(business_date, "YMD")
keep if inrange(date, `event' - `H', `event' + `H' - 1)
gen post = date >= `event'
foreach v in borrowing_volume lending_volume {
	replace `v' = 0 if missing(`v')
}
collapse (sum) borrowing_volume lending_volume, by(fund_id dealer_id post)
reshape wide borrowing_volume lending_volume, i(fund_id dealer_id) j(post)
foreach v in borrowing_volume0 borrowing_volume1 lending_volume0 lending_volume1 {
	replace `v' = 0 if missing(`v')
}
merge m:1 dealer_id using `dealers', keep(match) nogen

gen dlog_borrowing = log(borrowing_volume1) - log(borrowing_volume0)
gen dlog_lending = log(lending_volume1) - log(lending_volume0)
gen dlog_net = log(abs(borrowing_volume1 - lending_volume1)) - log(abs(borrowing_volume0 - lending_volume0))
egen fund_num = group(fund_id)
label var dlog_borrowing "Change in log borrowing, post minus pre"
label var dlog_lending "Change in log lending, post minus pre"
label var dlog_net "Change in log absolute net, post minus pre"

**# Test 1: bank lending channel, KM equation 5 and Table 3
* fund fixed effects compare the same fund's US and non US dealers, the OLS
* column without fixed effects is KM's benchmark for the demand bias

foreach y in dlog_borrowing dlog_lending dlog_net {
	reghdfe `y' treated, a(fund_num) vce(cluster dealer_id)
	reg `y' treated, vce(cluster dealer_id)
}
foreach y in dlog_borrowing dlog_lending dlog_net {
	reghdfe `y' dcds, a(fund_num) vce(cluster dealer_id)
}

**# Extensive margin, KM Table 4
* exit among pairs active before the event, entry among pairs active after

gen exit_borrowing = borrowing_volume0 > 0 & borrowing_volume1 == 0
gen entry_borrowing = borrowing_volume0 == 0 & borrowing_volume1 > 0
gen exit_lending = lending_volume0 > 0 & lending_volume1 == 0
gen entry_lending = lending_volume0 == 0 & lending_volume1 > 0

foreach l in borrowing lending {
	reghdfe exit_`l' treated if `l'_volume0 > 0, a(fund_num) vce(cluster dealer_id)
	reghdfe entry_`l' treated if `l'_volume1 > 0, a(fund_num) vce(cluster dealer_id)
}

**# Test 2: fund borrowing channel, KM equation 6 and Table 6
* fund level change in log totals on the pre window share of the fund's
* positions held with treated dealers, and on the pre share weighted CDS
* change, KM's average shock of the fund's preshock banks, no fixed effects

gen gross0 = borrowing_volume0 + lending_volume0
gen gross1 = borrowing_volume1 + lending_volume1
gen active0 = gross0 > 0
foreach v in borrowing_volume0 lending_volume0 gross0 {
	gen treated_`v' = treated*`v'
	gen dcds_`v' = dcds*`v'
}
collapse (sum) borrowing_volume0 borrowing_volume1 lending_volume0 lending_volume1 gross0 gross1 treated_* dcds_* active0, by(fund_id)
gen exposure_borrowing = treated_borrowing_volume0/borrowing_volume0
gen exposure_lending = treated_lending_volume0/lending_volume0
gen exposure_net = treated_gross0/gross0
gen dcds_borrowing = dcds_borrowing_volume0/borrowing_volume0
gen dcds_lending = dcds_lending_volume0/lending_volume0
gen dcds_net = dcds_gross0/gross0
gen dlog_borrowing = log(borrowing_volume1) - log(borrowing_volume0)
gen dlog_lending = log(lending_volume1) - log(lending_volume0)
gen dlog_net = log(abs(borrowing_volume1 - lending_volume1)) - log(abs(borrowing_volume0 - lending_volume0))
label var exposure_borrowing "Pre window borrowing share with US dealers"
label var exposure_lending "Pre window lending share with US dealers"
label var exposure_net "Pre window gross share with US dealers"

foreach l in borrowing lending net {
	reg dlog_`l' exposure_`l', vce(robust)
	reg dlog_`l' dcds_`l', vce(robust)
}
foreach l in borrowing lending net {
	reg dlog_`l' exposure_`l' if active0 > 1, vce(robust) /*funds with more than one dealer before the event*/
}

log close
