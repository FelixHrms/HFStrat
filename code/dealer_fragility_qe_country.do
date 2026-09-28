clear all
snapshot erase _all

global key "C:\\Users\\hermesf\\Projects\\HF_Strategies\\key dataframe"

cap log close
log using "$key\\dealer_fragility_qe_country.log", replace text

**# Quarter-end window dressing, can funds diversify the dealer shock away
* the fund level test of dealer_fragility_qe.do on all funds, single and multi
* dealer, pooled over the four collateral countries, exposure is the reference
* gross share weighted contraction of the fund's dealers and it is interacted
* with an indicator for funds with at least two dealers in the reference
* window, a single dealer fund's exposure is its dealer's contraction and it
* has no dealer to substitute with, so the coefficient on exposure is the
* pass-through without substitution, the interaction is what having other
* dealers buys, diversification predicts a positive interaction, the sum is
* the pass-through of multi dealer funds, the estimate of test 2, the
* treatment is the dealer's quarter-end contraction of its non hedge fund
* repo book as in dealer_fragility_qe.do

local K = 3 /*event window, the last K business days of the quarter*/
local R0 = 5 /*reference window, business days R0 to R1 before the quarter's last day*/
local R1 = 19

**# Step 0: the hedge fund panel, fund x dealer x country x day, cleaned as in DT.do

import delimited "$key\\fund_dealer_country_day.csv", varnames(1) clear
capture drop v1
keep if inlist(country, "DE", "FR", "IT", "ES") /*the four sovereigns, the pooled position is their sum*/
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

**# Step 1: windows, from the business days in the panel

use `panel', clear
preserve
	keep dealer_id /*the dealers that finance hedge funds, the population of the treatment*/
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
* book in the event window, positive means the dealer shrinks at quarter-end,
* all collateral, the leverage ratio is collateral blind

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
keep dealer_id quarter dress
tempfile dealers
save `dealers'

**# Step 3: fund level, one reference and one event observation per quarter
* pair level daily averages over each window pooled over the four countries,
* absent days count as zero, then the fund's totals, its exposure and its
* number of dealers in the reference window as in test 2

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
gen gross0 = borrowing_volume0 + lending_volume0
gen active0 = gross0 > 0 /*dealer active in the reference window*/
gen dress_gross0 = dress*gross0
bysort fund_id quarter (gross0 dealer_id): gen main_dealer = dealer_id[_N] /*the fund's largest dealer in the reference window, the unit of clustering*/
collapse (sum) borrowing_volume0 borrowing_volume1 lending_volume0 lending_volume1 gross0 dress_gross0 n_dealers = active0 (first) main_dealer, by(fund_id quarter)
gen exposure = dress_gross0/gross0
gen multi = n_dealers > 1
gen exposure_multi = exposure*multi
gen dlog_net = log(abs(borrowing_volume1 - lending_volume1)) - log(abs(borrowing_volume0 - lending_volume0))
label var exposure "Reference share weighted contraction of the fund's dealers"
label var multi "Fund with at least two dealers in the reference window"
label var dlog_net "Change in log absolute net, quarter-end minus reference"

**# The test: pass-through for single dealer funds and the multi dealer difference
* quarter fixed effects, standard errors clustered by the fund's largest
* dealer as in test 2, wild cluster bootstrap p values since there are only
* about twenty dealers

reghdfe dlog_net exposure exposure_multi multi, a(quarter) vce(cluster main_dealer)
tab multi if e(sample)
lincom exposure + exposure_multi /*the pass-through of multi dealer funds*/
boottest exposure, reps(9999) seed(1) nograph
boottest exposure_multi, reps(9999) seed(1) nograph
boottest exposure + exposure_multi = 0, reps(9999) seed(1) nograph

log close
