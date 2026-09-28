clear all
snapshot erase _all

global key "C:\\Users\\hermesf\\Projects\\HF_Strategies\\key dataframe"
global fig "C:\\Users\\hermesf\\Projects\\HF_Strategies\\Figures" /*figures for the slides, the Figures folder of the repository*/
capture mkdir "$fig"

cap log close
log using "$key\\dealer_fragility_qe_country.log", replace text

**# Quarter-end window dressing by collateral country, two graphs in levels
* the pooled test in dealer_fragility_qe.do finds substitution and the country
* regressions do not, log outcomes do not add up across countries, so this
* file looks at the question in levels, where the four country components add
* up to the pooled position exactly, the position is the net position,
* borrowing minus lending, scaled by the pooled reference window gross of the
* pair or the fund and signed by its pooled reference window net, so positive
* means the position grows in the direction of the reference position, the
* treatment is the dealer's quarter-end contraction of its non hedge fund repo
* book as in dealer_fragility_qe.do
* graph 1, the fund level slope of the change in net on the fund's exposure,
* one bar per country and one pooled, the pooled bar is the sum of the four
* graph 2, the average net position day by day over the last business days of
* the quarter, high versus low dressing dealers at the pair level and high
* versus low exposure funds at the fund level, one panel per country and one
* pooled, the pooled panel is the sum of the four

local K = 3 /*event window, the last K business days of the quarter*/
local R0 = 5 /*reference window, business days R0 to R1 before the quarter's last day*/
local R1 = 19
local D = 24 /*graph 2 shows business days D to 0 before the quarter's last day*/
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
gen net = borrowing_volume - lending_volume
tempfile panel
save `panel'

**# Step 1: business days counted from the quarter's last day, the windows

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
keep if n_from_end <= `D'
gen window = .
replace window = 1 if n_from_end < `K'
replace window = 0 if inrange(n_from_end, `R0', `R1')
keep date quarter n_from_end window
tempfile days
save `days'

**# Step 2: dealer treatment, contraction of the non hedge fund repo book
* dress = log of the daily book in the reference window minus log of the daily
* book in the event window, positive means the dealer shrinks at quarter-end,
* all collateral, the leverage ratio is collateral blind

import delimited "$key\\dealer_book_day.csv", varnames(1) clear
capture drop v1
gen date = date(business_date, "YMD")
merge m:1 dealer_id using `hf_dealers', keep(match) nogen /*only dealers that face hedge funds*/
merge m:1 date using `days', keep(match) nogen
drop if missing(window)
foreach v in borrowing_volume lending_volume {
	replace `v' = 0 if missing(`v')
}
gen book = borrowing_volume + lending_volume
collapse (sum) book, by(dealer_id quarter window)
reshape wide book, i(dealer_id quarter) j(window)
replace book0 = book0/(`R1' - `R0' + 1) /*daily averages*/
replace book1 = book1/`K'
gen dress = log(book0) - log(book1)
drop if missing(dress) /*no book in one of the two windows, the dealer is not active that quarter*/
egen median_dress = median(dress)
gen high = dress > median_dress /*dealer quarters above the median contraction*/
keep dealer_id quarter dress high
tempfile dealers
save `dealers'

**# Step 3: the reference window position of every pair and fund, the scale
* daily averages over the reference window pooled over the four countries,
* absent days count as zero, gross0 scales the positions and the sign of net0
* orients them, the same scale and sign for all four countries of a pair or a
* fund, which is what makes the country components add up

use `panel', clear
merge m:1 date using `days', keep(match) nogen
keep if window == 0
collapse (sum) borrowing_volume lending_volume, by(fund_id dealer_id quarter)
gen gross0 = (borrowing_volume + lending_volume)/(`R1' - `R0' + 1)
gen net0 = (borrowing_volume - lending_volume)/(`R1' - `R0' + 1)
merge m:1 dealer_id quarter using `dealers', keep(match) nogen
bysort high: gen n_units = _N /*pair quarters in the group, the denominator of the daily means in graph 2*/
keep fund_id dealer_id quarter gross0 net0 dress high n_units
tempfile pair
save `pair'

* fund level, the exposure is the gross share weighted contraction of the
* fund's dealers as in test 2, funds with at least two dealers
gen dress_gross0 = dress*gross0
bysort fund_id quarter (gross0 dealer_id): gen main_dealer = dealer_id[_N] /*the fund's largest dealer, the unit of clustering*/
collapse (sum) gross0 net0 dress_gross0 (count) n_dealers = gross0 (first) main_dealer, by(fund_id quarter)
keep if n_dealers > 1
gen exposure = dress_gross0/gross0
egen median_exposure = median(exposure)
gen high = exposure > median_exposure /*fund quarters above the median exposure*/
bysort high: gen n_units = _N /*fund quarters in the group*/
keep fund_id quarter gross0 net0 exposure main_dealer high n_units
tempfile fund
save `fund'

**# Graph 1: the fund level slope by country, in levels so the slopes add up
* the change in the fund's net position in the country from the reference to
* the event window, scaled and signed by the fund's pooled reference position,
* on the fund's exposure with quarter fixed effects as in test 2, the same
* sample and regressor for all five outcomes, so the pooled slope is the sum
* of the four country slopes

use `panel', clear
merge m:1 date using `days', keep(match) nogen
drop if missing(window)
collapse (sum) net, by(fund_id country quarter window)
replace net = net/(`R1' - `R0' + 1) if window == 0 /*daily averages*/
replace net = net/`K' if window == 1
reshape wide net, i(fund_id country quarter) j(window)
reshape wide net0 net1, i(fund_id quarter) j(country) string
merge m:1 fund_id quarter using `fund', keep(match) nogen
foreach c of local countries {
	foreach w in 0 1 {
		replace net`w'`c' = 0 if missing(net`w'`c') /*no position in the country in that window*/
	}
	gen y`c' = sign(net0)*(net1`c' - net0`c')/gross0
}
egen yPooled = rowtotal(yDE yFR yIT yES)

matrix slopes = J(5, 2, .)
local i = 1
foreach c in `countries' Pooled {
	reghdfe y`c' exposure, a(quarter) vce(cluster main_dealer)
	matrix slopes[`i', 1] = _b[exposure]
	matrix slopes[`i', 2] = _se[exposure]
	local ++i
}
clear
svmat slopes
rename (slopes1 slopes2) (b se)
gen n = _n
gen lo = b - 1.96*se
gen hi = b + 1.96*se
twoway (bar b n, barwidth(0.6)) (rcap lo hi n), yline(0) legend(off) ///
	xlabel(`panels') xtitle("") ///
	ytitle("Slope of the change in net on the fund's exposure")
graph export "$fig\\qe_country_slopes.png", replace width(3220)

**# Graph 2: the net position day by day into the quarter-end
* the average net position over the last business days of the quarter, scaled
* and signed by the pooled reference position of the pair or the fund, absent
* days count as zero, dashed lines mark the reference and the event window,
* high versus low dressing dealers at the pair level and high versus low
* exposure funds at the fund level, one panel per country and one pooled, the
* pooled panel is the sum of the four

foreach u in pair fund {
	if "`u'" == "pair" {
		local id "fund_id dealer_id"
		local group "dressing dealers"
	}
	else {
		local id "fund_id"
		local group "exposure funds"
	}
	use `panel', clear
	merge m:1 date using `days', keep(match) nogen
	collapse (sum) net, by(`id' country quarter n_from_end)
	merge m:1 `id' quarter using ``u'', keep(match) nogen
	gen y = sign(net0)*net/gross0
	collapse (sum) y (first) n_units, by(high country n_from_end)
	replace y = y/n_units /*mean over the unit quarters in the group, absent days count as zero*/
	drop n_units
	preserve
		collapse (sum) y, by(high n_from_end)
		gen country = "Pooled"
		tempfile pooled
		save `pooled'
	restore
	append using `pooled'
	label define panel `panels', replace
	encode country, gen(panel) label(panel)
	gen day = -n_from_end
	keep panel day high y
	reshape wide y, i(panel day) j(high)
	twoway (line y1 day) (line y0 day), by(panel, note("")) yline(0) ///
		xline(`=-`R1'-0.5' `=-`R0'+0.5' `=-`K'+0.5', lpattern(dash)) ///
		legend(order(1 "High `group'" 2 "Low `group'")) ///
		xtitle("Business days to the quarter's last day") ///
		ytitle("Net position, share of the reference window gross")
	graph export "$fig\\qe_country_path_`u'.png", replace width(3220)
}

log close
