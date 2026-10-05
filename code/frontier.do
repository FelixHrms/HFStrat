clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"

**# Frontier of duration matched bond portfolios against the CTD. US, one day, one contract

local day = td(15jan2025)
local contract "TYH5"

* upper hull of a point cloud, used for the frontier
mata:
real matrix upperhull(real colvector x, real colvector y)
{
	real matrix P, H
	real scalar i, k, turn
	P = sort((x, y), (1, -2))
	H = J(rows(P), 2, .)
	k = 0
	for (i = 1; i <= rows(P); i++) {
		while (k >= 2) {
			turn = (H[k,1]-H[k-1,1])*(P[i,2]-H[k-1,2]) - (H[k,2]-H[k-1,2])*(P[i,1]-H[k-1,1])
			if (turn >= 0) k = k - 1
			else break
		}
		k = k + 1
		H[k,.] = P[i,.]
	}
	return(H[|1,1 \ k,2|])
}
end

* the CTD of the contract on that day, the contract code may carry one or two year digits
use "$key/basis_stacked.dta", clear
keep if date == `day' & substr(contract,1,3) == substr("`contract'",1,3) & substr(contract,-1,1) == substr("`contract'",-1,1)
assert _N >= 1
local ctd = cusip[1]

* the bond universe on that day, same filters as the pricing error charts, the CTD is always kept
use "$key/bond_day.dta", clear
keep if date == `day' & country == "US"
gen ctd = cusip8 == "`ctd'"
gen dyield = yield_check - yield_curve_sv
gen ttm = (maturitydate - date) / 365
drop if inlist(bondtype, "4", "11", "12") | coupontype == 3
drop if (ttm < 0.25 | abs(dyield) > 0.25) & ctd == 0
drop if missing(duration, convexity, dyield)
keep cusip8 ctd duration convexity dyield
sum duration if ctd
assert r(N) == 1
local D = r(mean)
sum convexity if ctd
local C = r(mean)
tempfile bonds
save `bonds'

* every pair of bonds on either side of the target duration, and the one mix that hits it
keep if duration <= `D'
rename (cusip8 duration convexity dyield) (cusip_b dur_b conv_b dy_b)
drop ctd
tempfile below
save `below'
use `bonds', clear
keep if duration >= `D'
rename (cusip8 duration convexity dyield) (cusip_a dur_a conv_a dy_a)
drop ctd
cross using `below'
drop if dur_a == dur_b
gen w = (`D' - dur_a) / (dur_b - dur_a)
gen conv  = w*conv_b + (1-w)*conv_a
gen cheap = w*dy_b   + (1-w)*dy_a
count

* cheapest duration matched portfolios with roughly the convexity of the CTD, against the CTD itself
gen near = abs(conv - `C') / `C' < 0.02
gsort -near -cheap
list cusip_b cusip_a w conv cheap in 1/5, noobs
preserve
	use `bonds', clear
	list cusip8 duration convexity dyield if ctd, noobs
restore

* the frontier is the upper hull of the pair points
mata: st_matrix("hull", upperhull(st_data(., "conv"), st_data(., "cheap")))
clear
svmat double hull
rename (hull1 hull2) (conv cheap)
gen frontier = 1

* bonds as dots, the frontier as a line, the CTD marked
append using `bonds'
replace conv  = convexity if frontier != 1
replace cheap = dyield    if frontier != 1
tw (line cheap conv if frontier == 1, sort lcolor(black)) ///
   (scatter cheap conv if frontier != 1 & ctd == 0, mcolor(gs10) msize(small)) ///
   (scatter cheap conv if frontier != 1 & ctd == 1, mcolor(red) msymbol(D)) , ///
   legend(order(1 "Duration matched portfolios" 2 "Bonds" 3 "CTD") position(6) cols(3) region(lstyle(none))) ///
   ytitle("Yield above the fitted curve, pp") xtitle("Convexity") yline(0, lcolor(black))
graph export "$fig/frontier_US.png", replace width(3220)
