clear all
snapshot erase _all

global key "C:\\Users\\hermesf\\Projects\\HF_Strategies\\key dataframe"

cap log close
log using "$key\\dealer_fragility_qe_country.log", replace text

**# Quarter-end window dressing as the dealer shock, by collateral country
* runs the two tests of dealer_fragility_qe.do separately for each collateral
* country, the outcome is the fund x dealer x quarter panel of the country's
* collateral, the treatment stays at the dealer level, test 1 compares the
* same fund's dealers at the same quarter-end, test 2 asks whether the fund's
* total in the country stays flat when its dealers dress, the slopes are free
* to differ across the four sovereigns, the outcomes are borrowing, lending
* and net as in dealer_fragility_qe.do plus gross, the repo volume between
* fund and dealer, the financing

local K = 3 /*event window, the last K business days of the quarter*/
local R0 = 5 /*reference window, business days R0 to R1 before the quarter's last day*/
local R1 = 19
local countries "DE FR IT ES" /*the four sovereigns, one regression per collateral country*/

**# Step 0: the hedge fund panel, fund x dealer x country x day, cleaned as in DT.do

import delimited "$key\\fund_dealer_country_day.csv", varnames(1) clear
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
tabstat dress, by(dealer_id) stat(mean sd n)
keep dealer_id quarter dress
tempfile dealers
save `dealers'

**# Step 3: pair x country level, one reference and one event observation per quarter
* daily averages over each window, absent days count as zero, log differences
* only for cells active in both windows as in KM's intensive margin

use `panel', clear
merge m:1 date using `windows', keep(match) nogen
collapse (sum) borrowing_volume lending_volume, by(fund_id dealer_id country quarter window)
reshape wide borrowing_volume lending_volume, i(fund_id dealer_id country quarter) j(window)
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
gen dlog_gross = log(borrowing_volume1 + lending_volume1) - log(borrowing_volume0 + lending_volume0)
gen dlog_net = log(abs(borrowing_volume1 - lending_volume1)) - log(abs(borrowing_volume0 - lending_volume0))
egen fund_quarter = group(fund_id quarter)
label var dlog_borrowing "Change in log borrowing, quarter-end minus reference"
label var dlog_lending "Change in log lending, quarter-end minus reference"
label var dlog_gross "Change in log gross, quarter-end minus reference"
label var dlog_net "Change in log absolute net, quarter-end minus reference"

**# Test 1: bank lending channel, KM equation 5 by collateral country
* one regression per collateral country on the pairs in that country's
* collateral, fund x quarter fixed effects compare the same fund's dealers at
* the same quarter-end as in dealer_fragility_qe.do, beta = per log point of
* the dealer's book contraction

foreach c of local countries {
	di _n "Collateral country `c'"
	foreach y in dlog_borrowing dlog_lending dlog_gross dlog_net {
		reghdfe `y' dress if country == "`c'", a(fund_quarter) vce(cluster dealer_id)
	}
	preserve
		keep if e(sample) /*the dealer quarters that identify the net regression*/
		collapse (first) dress, by(dealer_id quarter)
		tabstat dress, stat(mean sd n)
	restore
}

**# Test 2: fund borrowing channel, KM equation 6 by collateral country
* fund level change in log totals in the country's collateral on the reference
* window share weighted contraction of the dealers that finance the fund's
* positions in that country, one regression per collateral country with
* quarter fixed effects as in dealer_fragility_qe.do, funds with at least two
* dealers in the country

gen gross0 = borrowing_volume0 + lending_volume0
gen gross1 = borrowing_volume1 + lending_volume1
gen active0 = gross0 > 0 /*dealer active in the reference window*/
foreach v in borrowing_volume0 lending_volume0 gross0 {
	gen dress_`v' = dress*`v'
}
collapse (sum) borrowing_volume0 borrowing_volume1 lending_volume0 lending_volume1 gross0 gross1 dress_* n_dealers = active0, by(fund_id country quarter)
gen exposure_borrowing = dress_borrowing_volume0/borrowing_volume0
gen exposure_lending = dress_lending_volume0/lending_volume0
gen exposure_gross = dress_gross0/gross0
gen exposure_net = dress_gross0/gross0
gen dlog_borrowing = log(borrowing_volume1) - log(borrowing_volume0)
gen dlog_lending = log(lending_volume1) - log(lending_volume0)
gen dlog_gross = log(gross1) - log(gross0)
gen dlog_net = log(abs(borrowing_volume1 - lending_volume1)) - log(abs(borrowing_volume0 - lending_volume0))
label var exposure_borrowing "Reference share weighted contraction of the fund's dealers in the country"
label var exposure_lending "Reference share weighted contraction of the fund's dealers in the country"
label var exposure_gross "Reference share weighted contraction of the fund's dealers in the country"
label var exposure_net "Reference share weighted contraction of the fund's dealers in the country"

foreach c of local countries {
	di _n "Collateral country `c'"
	foreach l in borrowing lending gross net {
		reghdfe dlog_`l' exposure_`l' if n_dealers > 1 & country == "`c'", a(quarter) vce(cluster fund_id) /*funds with at least two dealers in the country in the reference window, the population that identifies test 1*/
	}
}

log close
