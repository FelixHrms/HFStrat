clear all
snapshot erase _all

global key "C:\\Users\\hermesf\\Projects\\HF_Strategies\\key dataframe"

cap log close
log using "$key\\dealer_fragility_svb.log", replace text

**# Event study around SVB, 10 March 2023, following Khwaja and Mian
* the time dimension collapses to one pre and one post observation per pair,
* window sums of outstanding positions over H calendar days on each side,
* treated = dealers with a US parent, all other dealers are the controls,
* the log change of each dealer's own CDS between the windows is listed as a
* check on the treatment, entities as in the panel csv

local event = td(10mar2023)
local H = 60 /*window length in calendar days, robustness at 30 90*/

**# Step 1: dealer treatment, nationality from the Bloomberg sheet

import delimited "$key\\dealer_cds.csv", varnames(1) clear
capture drop v1
gen date = date(period, "YMD")
keep if inrange(date, `event' - `H', `event' + `H' - 1)
gen post = date >= `event'
collapse (mean) cds (first) nationality, by(dealer_id post)
reshape wide cds, i(dealer_id nationality) j(post)
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

**# Test 1: bank lending channel, KM equation 5
* within fund, the same fund's US dealers against its non US dealers

foreach y in dlog_borrowing dlog_lending dlog_net {
	reghdfe `y' treated, a(fund_num) vce(cluster dealer_id)
}

**# Test 2: fund borrowing channel, KM equation 6
* fund level change in log totals on the pre window share of the fund's
* positions held with US dealers, KM's average shock of the fund's preshock
* banks, no fixed effects

gen gross0 = borrowing_volume0 + lending_volume0
gen gross1 = borrowing_volume1 + lending_volume1
foreach v in borrowing_volume0 lending_volume0 gross0 {
	gen treated_`v' = treated*`v'
}
collapse (sum) borrowing_volume0 borrowing_volume1 lending_volume0 lending_volume1 gross0 gross1 treated_*, by(fund_id)
gen exposure_borrowing = treated_borrowing_volume0/borrowing_volume0
gen exposure_lending = treated_lending_volume0/lending_volume0
gen exposure_net = treated_gross0/gross0
gen dlog_borrowing = log(borrowing_volume1) - log(borrowing_volume0)
gen dlog_lending = log(lending_volume1) - log(lending_volume0)
gen dlog_net = log(abs(borrowing_volume1 - lending_volume1)) - log(abs(borrowing_volume0 - lending_volume0))
label var exposure_borrowing "Pre window borrowing share with US dealers"
label var exposure_lending "Pre window lending share with US dealers"
label var exposure_net "Pre window gross share with US dealers"

foreach l in borrowing lending net {
	reg dlog_`l' exposure_`l', vce(robust)
}

log close
