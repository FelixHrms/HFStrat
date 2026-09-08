clear all
snapshot erase _all

global key "C:\\Users\\hermesf\\Projects\\HF_Strategies\\key dataframe"
global fig "C:\\Users\\hermesf\\Projects\\HF_Strategies\\Figures" /*figures for the slides, the Figures folder of the repository*/
capture mkdir "$fig"

cap log close
log using "$key\\dealer_fragility_qe.log", replace text

**# Quarter-end window dressing as the dealer shock, following Khwaja and Mian
* every quarter-end is an event, one reference and one event observation per
* pair and quarter, treatment = how much the dealer shrinks its repo book with
* non hedge fund counterparties at that quarter-end, measured on a different
* population than the outcome, outcomes from the hedge fund panel

local K = 3 /*event window, the last K business days of the quarter*/
local R0 = 5 /*reference window, business days R0 to R1 before the quarter's last day*/
local R1 = 19

**# Step 0: the hedge fund panel, fund x dealer x day, cleaned as in DT.do

import delimited "$key\\fund_dealer_day.csv", varnames(1) clear
capture drop v1
gen date = date(business_date, "YMD")
format date %td
foreach v in borrowing_volume lending_volume {
	replace `v' = 0 if missing(`v')
}
* two funds report borrowing and lending the wrong way round at the beginning
* of the sample, flip the two sides for them before 24 April 2021 as in DT.do
gen flip = inlist(fund_id, "P5XEQYFJP74DYQX88M80", "O1XNTICYRCAHEAMEQI31") & date < td(24apr2021)
gen tmp = borrowing_volume
replace borrowing_volume = lending_volume if flip
replace lending_volume = tmp if flip
drop tmp flip
tempfile panel
save `panel'

**# Dealer concentration, the share of the three largest dealers, figure for the slides
* same construction as the fund concentration figure in Graph.do, each day the
* dealers are ranked by the absolute value of their net position with all hedge
* funds, the figure shows the share of the three largest in the total across
* all dealers, the top five share is summarised alongside for comparison with
* the fund figure

preserve
	collapse (sum) borrowing_volume lending_volume, by(date dealer_id)
	gen net = borrowing_volume - lending_volume
	gen absnet = abs(net)
	gsort date -absnet
	by date: gen n = _n
	by date: egen sumtop3 = sum(absnet*(n<=3))
	by date: egen sumtop5 = sum(absnet*(n<=5))
	by date: egen sumall = sum(absnet)
	gen frac = sumtop3/sumall
	gen frac5 = sumtop5/sumall
	keep date frac frac5
	duplicates drop
	scatter frac date
	graph export "$fig\\frac_top3_dealers.png", replace width(3220)
	sum frac frac5
restore

**# Step 1: windows, from the business days in the panel

use `panel', clear
preserve
	keep dealer_id /*the dealers that finance hedge funds, the population of test 1*/
	duplicates drop
	tempfile hf_dealers
	save `hf_dealers'
restore
keep date
duplicates drop
gen quarter = qofd(date)
format quarter %tq
sort quarter date
by quarter: gen n_from_end = _N - _n
by quarter: gen n_days = _N
keep if n_days >= 40 /*complete quarters only*/
gen window = .
replace window = 1 if n_from_end < `K'
replace window = 0 if inrange(n_from_end, `R0', `R1')
drop if missing(window)
keep date quarter window
tempfile windows
save `windows'

**# Step 2: dealer treatment, contraction of the non hedge fund repo book
* dress = log of the daily book in the reference window minus log of the daily
* book in the event window, positive means the dealer shrinks at quarter-end

import delimited "$key\\dealer_book_day.csv", varnames(1) clear
capture drop v1
gen date = date(business_date, "YMD")
merge m:1 dealer_id using `hf_dealers', keep(match) nogen /*only dealers that face hedge funds*/
merge m:1 date using `windows', keep(match) nogen
foreach v in borrowing_volume lending_volume {
	replace `v' = 0 if missing(`v')
}
gen book = borrowing_volume + lending_volume
collapse (sum) book, by(dealer_id quarter window)
reshape wide book, i(dealer_id quarter) j(window)
replace book0 = book0/(`R1' - `R0' + 1) /*daily averages*/
replace book1 = book1/`K'
gen dress = log(book0) - log(book1)
label var dress "Quarter-end contraction of the dealer's non HF repo book"
drop if missing(dress) /*no book in one of the two windows, the dealer is not active that quarter*/
tabstat dress, by(dealer_id) stat(mean sd n)
keep dealer_id quarter dress
tempfile dealers
save `dealers'

**# Step 3: pair level, one reference and one event observation per quarter
* daily averages over each window, absent days count as zero, log differences
* only for pairs active in both windows as in KM's intensive margin

use `panel', clear
merge m:1 date using `windows', keep(match) nogen
collapse (sum) borrowing_volume lending_volume, by(fund_id dealer_id quarter window)
reshape wide borrowing_volume lending_volume, i(fund_id dealer_id quarter) j(window)
foreach v in borrowing_volume0 borrowing_volume1 lending_volume0 lending_volume1 {
	replace `v' = 0 if missing(`v')
}
foreach v in borrowing_volume0 lending_volume0 {
	replace `v' = `v'/(`R1' - `R0' + 1)
}
foreach v in borrowing_volume1 lending_volume1 {
	replace `v' = `v'/`K'
}
merge m:1 dealer_id quarter using `dealers', keep(match) nogen

gen dlog_borrowing = log(borrowing_volume1) - log(borrowing_volume0)
gen dlog_lending = log(lending_volume1) - log(lending_volume0)
gen dlog_net = log(abs(borrowing_volume1 - lending_volume1)) - log(abs(borrowing_volume0 - lending_volume0))
egen fund_quarter = group(fund_id quarter)
label var dlog_borrowing "Change in log borrowing, quarter-end minus reference"
label var dlog_lending "Change in log lending, quarter-end minus reference"
label var dlog_net "Change in log absolute net, quarter-end minus reference"

**# Test 1: bank lending channel, KM equation 5 stacked over quarter-ends
* fund x quarter fixed effects compare the same fund's dealers at the same
* quarter-end, beta = per log point of the dealer's book contraction

foreach y in dlog_borrowing dlog_lending dlog_net {
	reghdfe `y' dress, a(fund_quarter) vce(cluster dealer_id)
}
preserve
	keep if e(sample) /*the dealer quarters that identify the net regression*/
	collapse (first) dress, by(dealer_id quarter)
	tabstat dress, stat(mean sd n)
restore

**# Test 2: fund borrowing channel, KM equation 6 stacked over quarter-ends
* fund level change in log totals on the reference window share weighted
* contraction of the fund's dealers, KM's average shock of the fund's
* preshock banks, quarter fixed effects, funds with at least two dealers

gen gross0 = borrowing_volume0 + lending_volume0
gen gross1 = borrowing_volume1 + lending_volume1
gen active0 = gross0 > 0 /*dealer active in the reference window*/
foreach v in borrowing_volume0 lending_volume0 gross0 {
	gen dress_`v' = dress*`v'
}
collapse (sum) borrowing_volume0 borrowing_volume1 lending_volume0 lending_volume1 gross0 gross1 dress_* n_dealers = active0, by(fund_id quarter)
gen exposure_borrowing = dress_borrowing_volume0/borrowing_volume0
gen exposure_lending = dress_lending_volume0/lending_volume0
gen exposure_net = dress_gross0/gross0
gen dlog_borrowing = log(borrowing_volume1) - log(borrowing_volume0)
gen dlog_lending = log(lending_volume1) - log(lending_volume0)
gen dlog_net = log(abs(borrowing_volume1 - lending_volume1)) - log(abs(borrowing_volume0 - lending_volume0))
label var exposure_borrowing "Reference share weighted contraction of the fund's dealers"
label var exposure_lending "Reference share weighted contraction of the fund's dealers"
label var exposure_net "Reference share weighted contraction of the fund's dealers"

foreach l in borrowing lending net {
	reghdfe dlog_`l' exposure_`l' if n_dealers > 1, a(quarter) vce(cluster fund_id) /*funds with at least two dealers in the reference window, the population that identifies test 1*/
}

log close
