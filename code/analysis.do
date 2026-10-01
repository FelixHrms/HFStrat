clear all

local who "felix"
if "`who'" == "felix"  global root "C:/Users/hermesf/Projects/HF_Strategies"
if "`who'" == "davide" global root "J:/hf strategies/hedge-fund-strategies"
global data "$root/Data"
global key  "$root/key dataframe"
global int  "$root/data/intermediate"
global fig  "$root/Figures"
capture mkdir "$root/data"
capture mkdir "$int"
capture mkdir "$fig"

use "$int/sftds_agg.dta", clear

sepscatter dyield ttm if abs(dyield)<10 & month(date)==4 & year(date)==2022 & country=="US" ,separate(bondtype )

sepscatter dyield ttm if abs(dyield)<10 & month(date)==4 & year(date)==2022 & country!="US" ,separate(coupontype )

preserve
	keep if country=="US" & abs(dyield)<0.25 & ilb==0 & ttm>0.25 
	reghdfe net  ,a(date)
	reghdfe net isctd isdlv ,a(date) vce(cluster date bond)
	reghdfe net isctd isdlv dyield ,a(date) vce(cluster date bond)
	reghdfe net isctd isdlv dyield isnearotr ,a(date) vce(cluster date bond)
	reghdfe net isctd isdlv dyield isnearotr duration convexity,a(date) vce(cluster date bond)
	binscatter dyield net ,n(100) line(none) xline(0) yline(0) 
restore

preserve
	keep if country!="US" & abs(dyield)<0.25 & ilb==0 & ttm>0.25 
	reghdfe net  ,a(date)
	reghdfe net isctd isdlv ,a(date) vce(cluster date bond)
	reghdfe net isctd isdlv dyield ,a(date) vce(cluster date bond)
	reghdfe net isctd isdlv dyield isnearotr ,a(date) vce(cluster date bond)
	reghdfe net isctd isdlv dyield isnearotr duration convexity,a(date) vce(cluster date bond)
	binscatter dyield net ,n(100) line(none) xline(0) yline(0) 
restore

preserve
	keep if abs(dyield)<0.25 & ilb==0 & ttm>0.25 
	binscatter dyield net ,n(100) line(none) xline(0) yline(0) 
restore

preserve
	collapse (sum) net, by(date newcountry isctd)
	tw (scatter net date if isctd==1)(scatter net date if isctd==0),by(newcountry) legend(order(1 "CTD" 2 "Not CTD") ) yline(0)
restore

preserve
	collapse (sum) net, by(date newotrnumb newcountry)
	sepscatter net date , separate(newotrnumb)
	tw (scatter net date if newotrnumb==1)(scatter net date if newotrnumb==2)(scatter net date if newotrnumb==3),by(newcountry) legend(order(1 "1st OTR" 2 "2nd OTR" 3 "Other") ) yline(0)
restore

preserve
	gen absnet=abs(net)
	gen qtyctd=absnet*isctd
	gen qtydlv=absnet*isdlv	
	gen qtyotr=absnet*isnearotr
	collapse (sum) absnet qtyctd qtydlv qtyotr , by(date newcountry)
	order newcountry date 
	gen fracctd=qtyctd/absnet
	gen fracdlv=qtydlv/absnet
	gen fracotr=qtyotr/absnet
	tw (scatter fracctd date if newcountry=="US") (scatter fracctd date if newcountry=="EU"), legend(order(1 "US" 2 "EU") ) yline(0) ylabel(0(0.1)1)
	tw (scatter fracdlv date if newcountry=="US") (scatter fracdlv date if newcountry=="EU"), legend(order(1 "US" 2 "EU") ) yline(0) ylabel(0(0.1)1)
	tw (scatter fracotr date if newcountry=="US") (scatter fracotr date if newcountry=="EU"), legend(order(1 "US" 2 "EU") ) yline(0) ylabel(0(0.1)1)
restore

preserve
	gen direction=net>0
	gen qtyctd=net*isctd
	gen qtydlv=net*isdlv	
	gen qtyotr=net*isnearotr
	collapse (sum) net qtyctd qtydlv qtyotr , by(date newcountry direction)
	order newcountry date 
	gen fracctd=qtyctd/net
	gen fracdlv=qtydlv/net
	gen fracotr=qtyotr/net
	gen side=" Long "
	replace side =" Short" if direction==0
	tw (line fracctd date if newcountry=="US"&direction==1, lc(blue))(line fracctd date if newcountry=="US"&direction==0,  lc(blue) lp(dash)) ///
	(line fracctd date if newcountry=="EU" &direction==1 , lc(red)) 	(line fracctd date if newcountry=="EU"&direction==0, lc(red)  lp(dashed)) ///
	, legend(order(1 "US Long" 2 "US Short" 3 "EU Long" 4 "EU Short" )) yline(0) ylabel(0(0.1)1)
	tw (line fracdlv date if newcountry=="US"&direction==1, lc(blue))(line fracdlv date if newcountry=="US"&direction==0,  lc(blue) lp(dash)) ///
	(line fracdlv date if newcountry=="EU" &direction==1 , lc(red)) 	(line fracdlv date if newcountry=="EU"&direction==0, lc(red)  lp(dash)) ///
	, legend(order(1 "US Long" 2 "US Short" 3 "EU Long" 4 "EU Short" )) yline(0) ylabel(0(0.1)1)
	tw (line fracotr date if newcountry=="US"&direction==1, lc(blue))(line fracotr date if newcountry=="US"&direction==0,  lc(blue) lp(dash)) ///
	(line fracotr date if newcountry=="EU" &direction==1 , lc(red)) 	(line fracotr date if newcountry=="EU"&direction==0, lc(red)  lp(dash)) ///
	, legend(order(1 "US Long" 2 "US Short" 3 "EU Long" 4 "EU Short" )) yline(0) ylabel(0(0.1)1)
	gen quad=newcountry+side
	*hist fracctd,by(quad)
	*hist fracdlv,by(quad)
	hist fracotr,by(quad)
restore

preserve
	keep if abs(dyield)<0.25 & ilb==0 & ttm>0.25 
	binscatter net otr_number if otr_number<10 ,discrete line(none) by(country)
restore

preserve
	keep if  country=="US"
	gen bond_dollarduration=net*duration
	gen bond_dollarconvexity=net*convexity	
	collapse (sum) net bond_dollarduration bond_dollarconvexity, by(date )
	gen year=year(date)
	gen quarter=quarter(date)
	collapse (last) net bond_dollarduration bond_dollarconvexity , by(year quarter )
	merge 1:1 year quarter using "$key/BondExposure.dta" , nogen keep(1 3)
	gen netOFR=(BondExposureLong-BondExposureShort)/10^9
	tw (scatter net netOFR)(lfit net netOFR) , ytitle("SFTDS Net Long Positions") xtitle("OFR Net Long Positions") legend(off)
	reg   net netOFR
	reg   net netOFR ,nocon	
	reg   netOFR net
	reg   netOFR net ,nocon	
restore



use "$int/sftds_agg.dta" , clear
	keep if  country=="US" & ilb==0
	gen weekn=week(date)+year(date)*100
	gen tuesday=date-dow(date)+2
	format tuesday %td
	gen bond_dollarduration=net*duration
	gen bond_dollarconvexity=net*convexity
	collapse (sum) bond_dollarduration bond_dollarconvexity ,by(date tuesday)
	collapse (mean) bond_dollarduration bond_dollarconvexity ,by(tuesday)
	drop if tuesday==mdy(7,4,2023)
	merge 1:1 tuesday using "$int/sumfutexp.dta" , keep(1 3)
	
	sort tuesday 
	replace futures_dolduration=futures_dolduration/10^9
	replace futures_dolconvexity=futures_dolconvexity/10^9
	
	scatter futures_dolduration bond_dollarduration
	scatter futures_dolconvexity bond_dollarconvexity
	tw (line futures_dolduration tuesday, ysc(reverse)) (line bond_dollarduration tuesday, yaxis(2)) , legend(pos(6))
	tw (line futures_dolconvexity tuesday, ysc(reverse)) (line bond_dollarconvexity tuesday, yaxis(2)) , legend(pos(6))
	
	reg  futures_dolduration bond_dollarduration
	reg  futures_dolduration bond_dollarduration  if tuesday>mdy(5,1,2021)
	/* -4.073459 */
	reg  bond_dollarduration futures_dolduration

	gen futures_dolduration_resc1=-(futures_dolduration)/3.760466 
	gen futures_dolduration_resc2=-(futures_dolduration)*.1694139 +308
	gen futures_dolduration_resc3=-(futures_dolduration)*.3224487 
	
	scatter futures_dolduration_resc1 bond_dollarduration
	gen gapdur1= futures_dolduration_resc1-bond_dollarduration
	gen gapdur2= futures_dolduration_resc2-bond_dollarduration
	gen gapdur3= futures_dolduration_resc3-bond_dollarduration
	tw (line futures_dolduration_resc1 tuesday, ysc(reverse)) (line bond_dollarduration tuesday) , legend(pos(6))
	line gapdur3 tuesday 
	line gapdur1 tuesday 
	
	scatter futures_dolconvexity bond_dollarconvexity
	gen futures_dolconvexity_resc1=-futures_dolconvexity/3.755
	gen futures_dolconvexity_resc2=-futures_dolconvexity*0.1667511
	gen futures_dolconvexity_resc3=-futures_dolconvexity*0.3085725
	scatter futures_dolconvexity_resc1 bond_dollarconvexity
	reg futures_dolconvexity bond_dollarconvexity
	tw (line futures_dolconvexity_resc1 tuesday, ysc(reverse)) (line bond_dollarconvexity tuesday) , legend(pos(6))
	gen gapconv1= futures_dolconvexity_resc1-bond_dollarconvexity
	gen gapconv2= futures_dolconvexity_resc2-bond_dollarconvexity
	gen gapconv3= futures_dolconvexity_resc3-bond_dollarconvexity
	gen gapconvraw= futures_dolconvexity -bond_dollarconvexity
	line gapconv1 tuesday 
	line gapconvraw tuesday 

	merge 1:1 tuesday using "$key/ImplVolTreasury_weekly.dta" , keep(1 3) nogen
	tw (line gapconv3 tuesday ) (line MOVE_Index___L1_ tuesday, yaxis(2)) if tuesday>mdy(6,1,2021), legend(pos(6))
	
	tw (line gapconv3 tuesday ,ysc(reverse)) (line  TY_1M_50D_VOL_BVOL_Comdty___R1_ tuesday, yaxis(2)) if tuesday>mdy(6,1,2021), legend(pos(6))
		graph export "$fig/convexity_gap_tyvol.png", replace width(3220)
	tw (line gapconv3 tuesday ,ysc(reverse)) (line  MOVE_Index___L1_ tuesday, yaxis(2)) if tuesday>mdy(6,1,2021), legend(pos(6))
		graph export "$fig/convexity_gap_move.png", replace width(3220)

	merge 1:1 tuesday using "$key/ACMtermpremium_weekly.dta" , keep(1 3) nogen
	gen term= ACMTP10 -    ACMTP02
		
	tw (line gapconv1 tuesday ) (line  ACMTP10 tuesday, yaxis(2)) if tuesday>mdy(6,1,2021), legend(pos(6))	
	tw (line gapconv1 tuesday ) (line  term tuesday, yaxis(2)) if tuesday>mdy(6,1,2021), legend(pos(6))	
		
 reg  futures_dolconvexity bond_dollarconvexity term MOVE_Index___L1_,robust
  reg  futures_dolconvexity bond_dollarconvexity ACMTP10    ACMTP02 MOVE_Index___L1_,robust
 reg  futures_dolduration  bond_dollarduration term  MOVE_Index___L1_,robust

egen tuesday_n= group(tuesday)
tsset tuesday_n

 reg  d.futures_dolconvexity d.bond_dollarconvexity d.term d.MOVE_Index___L1_,robust
  reg  d.futures_dolconvexity d.bond_dollarconvexity d.ACMTP10    d.ACMTP02 d.MOVE_Index___L1_,robust
 reg  d.futures_dolduration  d.bond_dollarduration d.term d.MOVE_Index___L1_,robust


use "$int/sftds_agg.dta" , clear
	keep if  country=="DE" & ilb==0
	gen bond_dollarduration=net*duration
	gen bond_dollarconvexity=net*convexity
	collapse (sum) bond_dollarduration bond_dollarconvexity ,by(date country)
	merge 1:1 date country using "$int/sumfutexpEU.dta" , keep(1 3)
	
	replace futures_dolduration=futures_dolduration/10^9
	replace futures_dolconvexity=futures_dolconvexity/10^9
	scatter futures_dolduration bond_dollarduration
	scatter futures_dolconvexity bond_dollarconvexity
	tw (line futures_dolduration date) (line bond_dollarduration date, yaxis(2)) , legend(pos(6))
	tw (line futures_dolconvexity date ) (line bond_dollarconvexity date, yaxis(2)) , legend(pos(6))

	tsset date
	gen fduration=l90.futures_dolduration
	tw (line fduration date) (line bond_dollarduration date, yaxis(2)) , legend(pos(6))


**# Sign of the unhedged exposure: convexity of the bonds funds hold against the cheapest to deliver of their contract, US

use "$key/bond_day.dta", clear
keep if country=="US"
keep date cusip8 duration convexity
reg convexity c.duration##c.duration
predict xconv, residuals
tempfile held
save `held'
rename (duration convexity xconv) (duration_ctd convexity_ctd xconv_ctd)
tempfile bd
save `bd'

use "$key/firstsecondctd.dta", clear
keep contract ctd1
rename ctd1 cusip8
duplicates drop
joinby cusip8 using `bd'
tempfile ctd
save `ctd'
keep date cusip8 duration_ctd convexity_ctd xconv_ctd
duplicates drop
gen is_ctd = 1
tempfile ctdset
save `ctdset'

use "$int/sftds_agg.dta", clear
keep if country=="US" & ilb==0 & ttm>0.25 & net>0
keep date cusip net duration convexity deliverable_contract1 isdlv
rename deliverable_contract1 contract
rename cusip cusip8
merge m:1 date cusip8 using `held', keepusing(xconv) keep(1 3) nogen
rename cusip8 cusip

* deliverable bonds take the CTD of their own contract
preserve
	keep if isdlv==1
	merge m:1 date contract using `ctd', keep(3) nogen
	drop cusip8
	tempfile dlv
	save `dlv'
restore

* the others take the CTD closest in duration on the day, nearest neighbour below and above in a sorted stack
keep if isdlv==0
drop contract
gen is_ctd = 0
append using `ctdset'
gen dkey = cond(is_ctd==1, duration_ctd, duration)
foreach side in below above {
	if "`side'" == "below" sort date dkey
	if "`side'" == "above" gsort date -dkey
	by date: gen d_`side' = duration_ctd if is_ctd==1
	by date: gen c_`side' = convexity_ctd if is_ctd==1
	by date: gen x_`side' = xconv_ctd if is_ctd==1
	by date: replace d_`side' = d_`side'[_n-1] if missing(d_`side') & _n>1
	by date: replace c_`side' = c_`side'[_n-1] if missing(c_`side') & _n>1
	by date: replace x_`side' = x_`side'[_n-1] if missing(x_`side') & _n>1
}
drop if is_ctd==1
gen use_above = missing(d_below) | (!missing(d_above) & abs(duration-d_above) < abs(duration-d_below))
replace duration_ctd  = cond(use_above, d_above, d_below)
replace convexity_ctd = cond(use_above, c_above, c_below)
replace xconv_ctd     = cond(use_above, x_above, x_below)
drop is_ctd dkey d_below d_above c_below c_above x_below x_above use_above cusip8
append using `dlv'

gen gap_conv  = convexity - convexity_ctd
gen gap_dur   = duration - duration_ctd
gen gap_xconv = xconv - xconv_ctd
gen pos_gap   = gap_xconv > 0

sum gap_conv gap_dur gap_xconv [aw=net]
tab isdlv pos_gap [aw=net]

* convexity gap at zero duration gap, and the gap in convexity beyond what duration implies
reg gap_conv gap_dur [aw=net], vce(cluster date)
reg gap_xconv [aw=net], vce(cluster date)
reg gap_xconv gap_dur [aw=net], vce(cluster date)

collapse (sum) net wconv=gap_conv wdur=gap_dur wxconv=gap_xconv (mean) share_pos=pos_gap [aw=net], by(date)
foreach v in wconv wdur wxconv {
	replace `v' = `v'/net
}
sum wconv wdur wxconv share_pos
count if wxconv > 0
tw (line wxconv date), yline(0, lcolor(black)) ytitle("Excess convexity of held bonds minus CTD") xtitle("")
graph export "$fig/excess_convexity_gap_sign.png", replace width(3220)
tw (line wconv date), yline(0, lcolor(black)) ytitle("Convexity of held bonds minus CTD convexity") xtitle("")
graph export "$fig/convexity_gap_sign.png", replace width(3220)
tw (line wdur date), yline(0, lcolor(black)) ytitle("Duration of held bonds minus CTD duration") xtitle("")
graph export "$fig/duration_gap_sign.png", replace width(3220)
