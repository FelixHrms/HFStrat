clear all
snapshot erase _all

global key "C:\\Users\\hermesf\\Projects\\HF_Strategies\\key dataframe"

cap log close
log using "$key\\dealer_fragility_qe_country.log", replace text

**# Quarter-end window dressing as the dealer shock, by collateral country
* mirrors dealer_fragility_qe.do with the outcome at fund x dealer x collateral
* country, the treatment stays at the dealer level, test 1 compares the same
* fund's dealers within the same collateral country, test 2 asks whether the
* fund's net position in that country stays flat when its dealers there dress

local K = 3 /*event window, the last K business days of the quarter*/
local R0 = 5 /*reference window, business days R0 to R1 before the quarter's last day*/
local R1 = 19

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
gen dlog_net = log(abs(borrowing_volume1 - lending_volume1)) - log(abs(borrowing_volume0 - lending_volume0))
egen fund_country_quarter = group(fund_id country quarter)
label var dlog_borrowing "Change in log borrowing, quarter-end minus reference"
label var dlog_lending "Change in log lending, quarter-end minus reference"
label var dlog_net "Change in log absolute net, quarter-end minus reference"
tempfile pairs
save `pairs'

**# Test 1: bank lending channel, KM equation 5 by collateral country
* fund x country x quarter fixed effects compare the same fund's dealers within
* the same collateral country at the same quarter-end, beta = per log point of
* the dealer's book contraction

foreach y in dlog_borrowing dlog_lending dlog_net {
	reghdfe `y' dress, a(fund_country_quarter) vce(cluster dealer_id)
}
preserve
	keep if e(sample) /*the dealer quarters that identify the net regression*/
	collapse (first) dress, by(dealer_id quarter)
	tabstat dress, stat(mean sd n)
restore

**# Test 2: fund borrowing channel, KM equation 6 by collateral country
* fund x country level change in log totals on the reference window share
* weighted contraction of the dealers that finance the fund's positions in that
* country, country x quarter fixed effects compare funds within the same
* collateral country, cells with at least two dealers

gen gross0 = borrowing_volume0 + lending_volume0
gen gross1 = borrowing_volume1 + lending_volume1
gen active0 = gross0 > 0 /*dealer active in the reference window*/
foreach v in borrowing_volume0 lending_volume0 gross0 {
	gen dress_`v' = dress*`v'
}
collapse (sum) borrowing_volume0 borrowing_volume1 lending_volume0 lending_volume1 gross0 gross1 dress_* n_dealers = active0, by(fund_id country quarter)
gen exposure_borrowing = dress_borrowing_volume0/borrowing_volume0
gen exposure_lending = dress_lending_volume0/lending_volume0
gen exposure_net = dress_gross0/gross0
gen dlog_borrowing = log(borrowing_volume1) - log(borrowing_volume0)
gen dlog_lending = log(lending_volume1) - log(lending_volume0)
gen dlog_net = log(abs(borrowing_volume1 - lending_volume1)) - log(abs(borrowing_volume0 - lending_volume0))
egen country_quarter = group(country quarter)
label var exposure_borrowing "Reference share weighted contraction of the fund's dealers in the country"
label var exposure_lending "Reference share weighted contraction of the fund's dealers in the country"
label var exposure_net "Reference share weighted contraction of the fund's dealers in the country"

foreach l in borrowing lending net {
	reghdfe dlog_`l' exposure_`l' if n_dealers > 1, a(country_quarter) vce(cluster fund_id) /*fund country cells with at least two dealers in the reference window, the population that identifies test 1*/
}

**# Pooled over countries, net as the sum of absolute country nets
* the pooled net |sum over countries of B - L| lets a long in one sovereign and
* a short in another cancel, so it can stay flat while both positions are cut,
* here the net is taken per country first and the absolute values are summed,
* at the pair level per dealer, at the fund level after netting across the
* fund's dealers within the country, same two tests as in dealer_fragility_qe.do

use `pairs', clear
gen gross0 = borrowing_volume0 + lending_volume0
bysort fund_id quarter dealer_id: egen dealer_gross0 = total(gross0)
bysort fund_id quarter dealer_id: gen active0 = _n == 1 & dealer_gross0 > 0 /*dealer active in the reference window, counted once per fund and quarter*/
gen dress_gross0 = dress*gross0
gen absnet0 = abs(borrowing_volume0 - lending_volume0)
gen absnet1 = abs(borrowing_volume1 - lending_volume1)

preserve
	collapse (sum) absnet0 absnet1 (first) dress, by(fund_id dealer_id quarter)
	gen dlog_net = log(absnet1) - log(absnet0)
	egen fund_quarter = group(fund_id quarter)
	label var dlog_net "Change in log net, sum of absolute country nets, quarter-end minus reference"
	reghdfe dlog_net dress, a(fund_quarter) vce(cluster dealer_id)
restore

collapse (sum) borrowing_volume0 borrowing_volume1 lending_volume0 lending_volume1 gross0 dress_gross0 n_dealers = active0, by(fund_id country quarter)
gen absnet0 = abs(borrowing_volume0 - lending_volume0) /*the fund's position in the country, netted across its dealers*/
gen absnet1 = abs(borrowing_volume1 - lending_volume1)
collapse (sum) absnet0 absnet1 gross0 dress_gross0 n_dealers, by(fund_id quarter)
gen exposure_net = dress_gross0/gross0
gen dlog_net = log(absnet1) - log(absnet0)
label var exposure_net "Reference share weighted contraction of the fund's dealers"
reghdfe dlog_net exposure_net if n_dealers > 1, a(quarter) vce(cluster fund_id)

log close
