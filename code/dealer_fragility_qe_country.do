clear all
snapshot erase _all

global key "C:\\Users\\hermesf\\Projects\\HF_Strategies\\key dataframe"
global fig "C:\\Users\\hermesf\\Projects\\HF_Strategies\\Figures" /*figures for the slides, the Figures folder of the repository*/
capture mkdir "$fig"

cap log close
log using "$key\\dealer_fragility_qe_country.log", replace text

**# Quarter-end window dressing, can funds diversify the dealer shock away
* the fund level test of dealer_fragility_qe.do on all funds pooled over the
* four collateral countries, exposure is the reference gross share weighted
* contraction of the fund's dealers and it is interacted with the fund's
* number of dealers in the reference window minus one, so the coefficient on
* exposure is the pass-through of a single dealer fund, which has no dealer to
* substitute with, and the interaction is the change per additional dealer,
* diversification predicts a positive interaction, two outcomes, net is the
* absolute net position the fund finances, gross is the repo volume between
* fund and dealers, the financing, which is the mirror of the treatment and
* less noisy than net, a second regression puts the smallest contraction
* among the fund's dealers next to its average exposure to ask which of the
* two the fund's total follows, the last block decomposes the dose model by
* collateral country in levels, where the country slopes add up to the pooled
* ones, the treatment is the dealer's quarter-end contraction of its non
* hedge fund repo book as in dealer_fragility_qe.do

local K = 3 /*event window, the last K business days of the quarter*/
local R0 = 5 /*reference window, business days R0 to R1 before the quarter's last day*/
local R1 = 19
local countries "DE FR IT ES" /*the four sovereigns, the pooled position is their sum*/
local panels 1 "DE" 2 "FR" 3 "IT" 4 "ES" 5 "Pooled"

**# Step 0: the hedge fund panel, fund x dealer x country x day, cleaned as in DT.do

import delimited "$key\\fund_dealer_country_day.csv", varnames(1) clear
capture drop v1
keep if inlist(country, "DE", "FR", "IT", "ES")
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
gen dress_active0 = dress if active0 /*for the minimum over the dealers active in the reference window*/
bysort fund_id quarter (gross0 dealer_id): gen main_dealer = dealer_id[_N] /*the fund's largest dealer in the reference window, the unit of clustering*/
collapse (sum) borrowing_volume0 borrowing_volume1 lending_volume0 lending_volume1 gross0 dress_gross0 n_dealers = active0 (min) min_dress = dress_active0 (first) main_dealer, by(fund_id quarter)
gen exposure = dress_gross0/gross0
gen dose = n_dealers - 1
gen exposure_dose = exposure*dose
gen gross1 = borrowing_volume1 + lending_volume1
gen dlog_net = log(abs(borrowing_volume1 - lending_volume1)) - log(abs(borrowing_volume0 - lending_volume0))
gen dlog_gross = log(gross1) - log(gross0)
label var exposure "Reference share weighted contraction of the fund's dealers"
label var dose "Number of dealers in the reference window minus one"
label var min_dress "Smallest contraction among the fund's dealers in the reference window"
label var dlog_net "Change in log absolute net, quarter-end minus reference"
label var dlog_gross "Change in log gross, quarter-end minus reference"
tempfile fund
save `fund'

**# The test: pass-through of a single dealer fund and the change per additional dealer
* quarter fixed effects, standard errors clustered by the fund's largest
* dealer as in test 2, wild cluster bootstrap p values since there are only
* about twenty dealers, the pass-through of a fund with three dealers, about
* the average multi dealer fund, is reported alongside

foreach y in dlog_net dlog_gross {
	reghdfe `y' exposure exposure_dose dose, a(quarter) vce(cluster main_dealer)
	tab n_dealers if e(sample)
	lincom exposure + 2*exposure_dose /*the pass-through of a fund with three dealers*/
	boottest exposure, reps(9999) seed(1) nograph
	boottest exposure_dose, reps(9999) seed(1) nograph
	boottest exposure + 2*exposure_dose = 0, reps(9999) seed(1) nograph
}

**# Which dealer does the fund follow, the average or its least constrained one
* multi dealer funds, the fund's exposure next to the smallest contraction
* among its dealers active in the reference window, under full substitution
* within the dealer set the fund's total follows the minimum and the average
* adds nothing, under no substitution the average carries it, the sum is the
* pass-through when all of the fund's dealers shrink alike

foreach y in dlog_net dlog_gross {
	reghdfe `y' exposure min_dress if n_dealers > 1, a(quarter) vce(cluster main_dealer)
	lincom exposure + min_dress /*the pass-through when all of the fund's dealers shrink alike*/
	boottest exposure, reps(9999) seed(1) nograph
	boottest min_dress, reps(9999) seed(1) nograph
	boottest exposure + min_dress = 0, reps(9999) seed(1) nograph
}

**# Country decomposition of the dose model, in levels so the slopes add up
* the change in the fund's gross financing in each collateral country from the
* reference to the event window, scaled by the fund's pooled reference gross,
* the four country changes add up to the pooled change exactly, the dose
* model on the same sample and regressors for all five outcomes, so each
* country's single dealer pass-through and per dealer offset add up to the
* pooled ones, the pooled bars should sit near the log estimates above, if
* they do not, funds with a tiny reference gross drive the levels, the graph
* shows both slopes with 95 percent intervals

use `panel', clear
merge m:1 date using `windows', keep(match) nogen
collapse (sum) borrowing_volume lending_volume, by(fund_id country quarter window)
gen gross = borrowing_volume + lending_volume
replace gross = gross/(`R1' - `R0' + 1) if window == 0 /*daily averages*/
replace gross = gross/`K' if window == 1
keep fund_id country quarter window gross
reshape wide gross, i(fund_id country quarter) j(window)
reshape wide gross0 gross1, i(fund_id quarter) j(country) string
merge 1:1 fund_id quarter using `fund', keep(match) nogen
foreach c of local countries {
	foreach w in 0 1 {
		replace gross`w'`c' = 0 if missing(gross`w'`c') /*no financing in the country in that window*/
	}
	gen y`c' = (gross1`c' - gross0`c')/gross0
}
egen yPooled = rowtotal(yDE yFR yIT yES)

matrix slopes = J(5, 4, .)
local i = 1
foreach c in `countries' Pooled {
	reghdfe y`c' exposure exposure_dose dose, a(quarter) vce(cluster main_dealer)
	matrix slopes[`i', 1] = _b[exposure]
	matrix slopes[`i', 2] = _se[exposure]
	matrix slopes[`i', 3] = _b[exposure_dose]
	matrix slopes[`i', 4] = _se[exposure_dose]
	local ++i
}
clear
svmat slopes
rename (slopes1 slopes2 slopes3 slopes4) (b1 se1 b2 se2)
gen n = _n
reshape long b se, i(n) j(coef)
label define coef 1 "Single dealer pass-through" 2 "Change per additional dealer"
label values coef coef
gen lo = b - 1.96*se
gen hi = b + 1.96*se
twoway (bar b n, barwidth(0.6)) (rcap lo hi n), by(coef, note("") yrescale) yline(0) legend(off) ///
	xlabel(`panels') xtitle("") ///
	ytitle("Slope, change in gross over the fund's reference gross")
graph export "$fig\\qe_country_dose.png", replace width(3220)

log close
