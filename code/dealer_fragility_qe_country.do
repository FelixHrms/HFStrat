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
* less noisy than net, the last block decomposes the dose model by collateral
* country in growth rates with a common denominator, where the country slopes
* add up to the pooled ones, and then reruns it with the country's own dose,
* the share of that collateral's market held by the fund's dealers other than
* its largest, to test whether substitution works wherever the fund has the
* capacity to move to, and finally runs the pair level test of
* dealer_fragility_qe.do by collateral, to ask whether the dealer that dresses
* more cuts the same fund's Bonos more than its Bunds, and separates the cut
* from the move with the dressing of the fund's other dealers,
* the treatment is the dealer's quarter-end contraction of its non hedge fund
* repo book as in dealer_fragility_qe.do

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

**# Step 2b: which dealers intermediate which collateral, the premise
* a dealer is capable in a country in a quarter if it has repo volume with any
* hedge fund in that collateral in the reference window, the table shows per
* country the number of capable dealers and the share of the three largest,
* averaged over quarters, with the pooled book for comparison, then each
* dealer's share of every country's hedge fund financing is saved for step 3

use `panel', clear
merge m:1 date using `windows', keep(match) nogen
keep if window == 0
expand 2, gen(pooled)
replace country = "Pooled" if pooled
collapse (sum) borrowing_volume lending_volume, by(dealer_id country quarter)
gen gross = borrowing_volume + lending_volume
bysort country quarter (gross): gen rank = _N - _n + 1
by country quarter: egen total = sum(gross)
by country quarter: egen top3 = sum(gross*(rank <= 3))
gen top3_share = top3/total
preserve
	collapse (count) n_dealers = gross (first) top3_share, by(country quarter)
	collapse (mean) n_dealers top3_share, by(country)
	list, clean noobs
restore
keep if country != "Pooled"
gen share = gross/total /*the dealer's share of the country's hedge fund financing in the quarter*/
keep dealer_id country quarter share
reshape wide share, i(dealer_id quarter) j(country) string
tempfile shares
save `shares'

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
merge m:1 dealer_id quarter using `shares', keep(match master) nogen
foreach c of local countries {
	replace share`c' = 0 if missing(share`c')
	gen alt`c' = share`c'*active0*(dealer_id != main_dealer) /*the country's market share of the fund's dealers other than its largest, its alternative capacity*/
	local altlist `altlist' alt`c'
}
collapse (sum) borrowing_volume0 borrowing_volume1 lending_volume0 lending_volume1 gross0 dress_gross0 n_dealers = active0 `altlist' (first) main_dealer, by(fund_id quarter)
gen exposure = dress_gross0/gross0
gen dose = n_dealers - 1
gen exposure_dose = exposure*dose
foreach c of local countries {
	gen exposure_alt`c' = exposure*alt`c'
}
gen gross1 = borrowing_volume1 + lending_volume1
gen dlog_net = log(abs(borrowing_volume1 - lending_volume1)) - log(abs(borrowing_volume0 - lending_volume0))
gen dlog_gross = log(gross1) - log(gross0)
label var exposure "Reference share weighted contraction of the fund's dealers"
label var dose "Number of dealers in the reference window minus one"
foreach c of local countries {
	label var alt`c' "Share of the `c' market held by the fund's dealers other than its largest"
}
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

**# Country decomposition of the dose model, growth rates that add up
* the change in the fund's gross financing in each collateral country from the
* reference to the event window, divided by the average of the fund's pooled
* gross over the two windows, the mid-point growth rate, which is bounded
* between minus two and two, close to the log change for moderate changes and
* immune to funds with a tiny reference gross, the four country changes add
* up to the pooled change exactly because the denominator is common, the dose
* model on the same sample and regressors for all five outcomes, so each
* country's single dealer pass-through and per dealer offset add up to the
* pooled ones, the pooled bars should sit near the log estimates above, the
* graph shows both slopes with 95 percent intervals

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
	gen y`c' = (gross1`c' - gross0`c')/((gross0 + gross1)/2)
}
egen yPooled = rowtotal(yDE yFR yIT yES)

matrix slopes = J(5, 12, .)
local i = 1
foreach c in `countries' Pooled {
	reghdfe y`c' exposure exposure_dose dose, a(quarter) vce(cluster main_dealer)
	boottest exposure_dose, reps(9999) seed(1) nograph
	matrix slopes[`i', 1] = _b[exposure]
	matrix slopes[`i', 2] = _se[exposure]
	matrix slopes[`i', 3] = _b[exposure_dose]
	matrix slopes[`i', 4] = _se[exposure_dose]
	local ++i
}

**# The test: the offset per unit of alternative capacity
* the same decomposition with the country's own dose, the combined share of
* the country's hedge fund financing held by the fund's dealers other than its
* largest in the reference window, a fund whose other dealers do a large part
* of the Bono market has somewhere to move its Bonos, if the offset per unit
* of capacity is as large for Bonos as for Bunds, substitution works wherever
* capacity exists and the countries differ in how much capacity funds have,
* which the summary shows, if it stays at zero for Bonos, capacity is not the
* constraint, no pooled row since the dose is country specific

local i = 1
foreach c of local countries {
	reghdfe y`c' exposure exposure_alt`c' alt`c', a(quarter) vce(cluster main_dealer)
	sum alt`c' if e(sample)
	boottest exposure_alt`c', reps(9999) seed(1) nograph
	matrix slopes[`i', 5] = _b[exposure_alt`c']
	matrix slopes[`i', 6] = _se[exposure_alt`c']
	local ++i
}
**# The pair level cut by collateral, which collateral the dressing dealer sheds
* test 1 of dealer_fragility_qe.do in the same growth rates, the change in the
* pair's gross financing in each country divided by the average of the pair's
* pooled gross over the two windows, pairs active in the reference window,
* exits stay in, fund by quarter fixed effects compare the same fund's dealers
* at the same quarter-end, standard errors clustered by dealer, the four
* country slopes add up to the pooled one, a country's slope is the cut at the
* dealer that dresses more relative to the fund's other dealers, so it also
* contains what the fund moves to those dealers, for a collateral the fund
* does not move it is the pure cut

use `panel', clear
merge m:1 date using `windows', keep(match) nogen
collapse (sum) borrowing_volume lending_volume, by(fund_id dealer_id country quarter window)
gen gross = borrowing_volume + lending_volume
replace gross = gross/(`R1' - `R0' + 1) if window == 0 /*daily averages*/
replace gross = gross/`K' if window == 1
keep fund_id dealer_id country quarter window gross
reshape wide gross, i(fund_id dealer_id country quarter) j(window)
reshape wide gross0 gross1, i(fund_id dealer_id quarter) j(country) string
foreach c of local countries {
	foreach w in 0 1 {
		replace gross`w'`c' = 0 if missing(gross`w'`c') /*no financing in the country in that window*/
	}
}
egen gross0 = rowtotal(gross0DE gross0FR gross0IT gross0ES)
egen gross1 = rowtotal(gross1DE gross1FR gross1IT gross1ES)
keep if gross0 > 0 /*pairs active in the reference window*/
merge m:1 dealer_id quarter using `dealers', keep(match) nogen
foreach c of local countries {
	gen y`c' = (gross1`c' - gross0`c')/((gross0 + gross1)/2)
}
egen yPooled = rowtotal(yDE yFR yIT yES)
egen fund_quarter = group(fund_id quarter)
local i = 1
foreach c in `countries' Pooled {
	reghdfe y`c' dress, a(fund_quarter) vce(cluster dealer_id)
	boottest dress, reps(9999) seed(1) nograph
	matrix slopes[`i', 7] = _b[dress]
	matrix slopes[`i', 8] = _se[dress]
	local ++i
}

**# The cut and the move, own dressing against the dressing of the fund's other dealers
* the pair level regression with fund and quarter effects instead of fund by
* quarter effects, own dressing next to the reference gross weighted average
* dressing of the fund's other dealers, the coefficient on own dressing is the
* cut of the collateral at the dealer that dresses, the coefficient on the
* others' dressing is what arrives at this dealer when the fund's other
* dealers dress, the move, positive for a collateral the fund relocates and
* zero for one it does not, single dealer funds have no other dealers and
* drop out

egen sum_dress_gross0 = total(dress*gross0), by(fund_id quarter)
egen sum_gross0 = total(gross0), by(fund_id quarter)
gen others_dress = (sum_dress_gross0 - dress*gross0)/(sum_gross0 - gross0)
label var others_dress "Reference gross weighted contraction of the fund's other dealers"
local i = 1
foreach c in `countries' Pooled {
	reghdfe y`c' dress others_dress, a(fund_id quarter) vce(cluster dealer_id)
	boottest dress, reps(9999) seed(1) nograph
	boottest others_dress, reps(9999) seed(1) nograph
	matrix slopes[`i', 9] = _b[dress]
	matrix slopes[`i', 10] = _se[dress]
	matrix slopes[`i', 11] = _b[others_dress]
	matrix slopes[`i', 12] = _se[others_dress]
	local ++i
}

**# The graph, the six slopes by country with 95 percent intervals

clear
svmat slopes
rename (slopes1 slopes2 slopes3 slopes4 slopes5 slopes6 slopes7 slopes8 slopes9 slopes10 slopes11 slopes12) (b1 se1 b2 se2 b3 se3 b4 se4 b5 se5 b6 se6)
gen n = _n
reshape long b se, i(n) j(coef)
label define coef 1 "Single dealer pass-through" 2 "Change per additional dealer" 3 "Change per unit of alternative capacity" 4 "Pair level cut at the dressing dealer" 5 "Cut, own dressing, fund and quarter effects" 6 "Move, the fund's other dealers' dressing"
label values coef coef
gen lo = b - 1.96*se
gen hi = b + 1.96*se
twoway (bar b n, barwidth(0.6)) (rcap lo hi n), by(coef, note("") yrescale) yline(0) legend(off) ///
	xlabel(`panels') xtitle("") ///
	ytitle("Slope, mid-point growth rate of gross financing")
graph export "$fig\\qe_country_dose.png", replace width(3220)

log close
