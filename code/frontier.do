clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Carry against duration for all US treasuries on one day, with the frontier of portfolios and the CTDs marked

local day = td(15jan2025)

* marks the bonds on the upper hull of the point cloud. Duration and carry are linear in weights, so the hull is the portfolio frontier
mata:
void markhull(string scalar xv, string scalar yv, string scalar hv, string scalar sel)
{
	real matrix P, H
	real colvector h
	real scalar i, k, turn
	P = sort((st_data(., xv, sel), st_data(., yv, sel), (1::rows(st_data(., xv, sel)))), (1, -2))
	H = J(rows(P), 3, .)
	k = 0
	for (i = 1; i <= rows(P); i++) {
		while (k >= 2) {
			turn = (H[k,1]-H[k-1,1])*(P[i,2]-H[k-1,2]) - (H[k,2]-H[k-1,2])*(P[i,1]-H[k-1,1])
			if (turn >= 0) {
				k = k - 1
			}
			else {
				break
			}
		}
		k = k + 1
		H[k,.] = P[i,.]
	}
	h = J(rows(P), 1, 0)
	for (i = 1; i <= k; i++) {
		h[H[i,3]] = 1
	}
	st_store(., hv, sel, h)
}
end

* the CTD of every contract on that day
use "$key/basis_stacked.dta", clear
keep if date == `day'
keep cusip contract
duplicates drop
rename cusip cusip8
gen series = regexr(contract, "[FGHJKMNQUVXZ][0-9]+$", "")
keep cusip8 series
duplicates drop
tempfile ctd
save `ctd'

* repo rate per bond, market wide average over all trades on that day
import delimited "$key/bond_day_rate.csv", varnames(1) clear
gen date = date(business_date, "YMD")
keep if date == `day'
rename security_isin isin
keep isin market_rate
count
assert r(N) > 0
sum market_rate, detail
local gc = r(p50)
tempfile repo
save `repo'

* bonds on that day without TIPS, carry is the yield minus the repo rate, general collateral proxy where the bond has no repo trade
use "$key/bond_day.dta", clear
keep if date == `day' & country == "US"
drop if inlist(bondtype, "11", "12")
gen ttm = (maturitydate - date) / 365
drop if ttm < 0.25
merge m:1 cusip8 using `ctd', keep(1 3)
gen ctd = _merge == 3
drop _merge
merge 1:1 isin using `repo', keep(1 3)
tab _merge
drop _merge
replace market_rate = `gc' if missing(market_rate)
gen carry = yield_check - market_rate
sum yield_check market_rate duration carry
drop if missing(duration, carry)
assert _N > 0
keep cusip8 isin series ctd duration convexity carry ttm bondtype
sum duration carry
list series cusip8 duration carry if ctd, noobs

tempfile bonds
save `bonds'

* long US book of each fund on that day, value weighted duration and carry, one dot per fund
use "$int/sftds.dta", clear
keep if date == `day' & country == "US" & net > 0
merge m:1 isin using `bonds', keep(3) nogen keepusing(duration carry convexity)
gen wd = net*duration
gen wc = net*carry
gen wx = net*convexity
collapse (sum) net wd wc wx, by(entity_id)
drop if net < 0.1
gen duration = wd/net
gen carry = wc/net
gen convexity = wx/net
gen fund = 1
keep entity_id net duration carry convexity fund
tempfile funds
save `funds'

* the frontier, and the line a fund holding only CTDs can reach
use `bonds', clear
gen all = 1
gen hull = .
mata: markhull("duration", "carry", "hull", "all")
gen ctdline = .
mata: markhull("duration", "carry", "ctdline", "ctd")

* for each CTD, the frontier portfolio at its duration, a mix of the two hull bonds around it, with its carry and convexity
preserve
	keep if hull == 1
	keep cusip8 duration carry convexity
	rename (cusip8 duration carry convexity) (cusip_h dur_h carry_h conv_h)
	gen one = 1
	tempfile hullpts
	save `hullpts'
restore
preserve
	keep if ctd == 1
	keep series cusip8 duration carry convexity
	gen one = 1
	joinby one using `hullpts'
	gen lo = dur_h <= duration
	gen gap = abs(dur_h - duration)
	bysort series lo (gap): keep if _n == 1
	bysort series (lo): gen w = (dur_h[1] - duration) / (dur_h[1] - dur_h[2])
	by series: gen carry_f = w*carry_h[2] + (1-w)*carry_h[1]
	by series: gen conv_f  = w*conv_h[2]  + (1-w)*conv_h[1]
	by series: keep if _n == 1
	gen dcarry = carry_f - carry
	gen dconv  = conv_f - convexity
	list series duration carry carry_f dcarry convexity conv_f dconv, noobs
restore

* funds between the two lines, share of the carry gap captured, zero on the CTD line and one on the frontier
append using `funds'
gen fc = carry if hull == 1
ipolate fc duration, gen(front)
gen cc = carry if ctdline == 1
ipolate cc duration, gen(ctdc)
gen share = (carry - ctdc) / (front - ctdc) if fund == 1
sum share if fund == 1, detail
sum share [aw=net] if fund == 1

tw (line carry duration if hull == 1, sort lcolor(black)) ///
   (line carry duration if ctdline == 1, sort lcolor(red) lpattern(dash)) ///
   (scatter carry duration if ctd == 0, mcolor(gs10) msize(small)) ///
   (scatter carry duration if ctd == 1, mcolor(red) msymbol(D) mlabel(series) mlabcolor(red)) ///
   (scatter carry duration if fund == 1, mcolor(blue) msymbol(O)) , ///
   legend(order(1 "Portfolio frontier" 2 "CTD line" 3 "Treasuries" 4 "CTD" 5 "Funds") position(6) cols(5) region(lstyle(none))) ///
   ytitle("Yield minus repo rate, pp") xtitle("Duration") yline(0, lcolor(black))
graph export "$fig/frontier_US.png", replace width(3220)
