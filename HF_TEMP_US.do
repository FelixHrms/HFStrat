
clear all 
snapshot erase _all

global dir "J:\HF Strategies\hedge-fund-strategies\Data"
global fig "E:\Dropbox\Apps\Overleaf\Hedge Funds Strategies\Figures"
global tab "E:\Dropbox\Apps\Overleaf\Hedge Funds Strategies\Tables"

**# Create datasets in stata, reshape some 

import delimited "$dir/hf_positions_US_svensson.csv", clear
	drop date
	gen date= date(business_date, "YMD")
	format date %td
	drop if itype>4 /*keep bond notes and bills*/


	gen dyield=yield -yield_curve
		bysort date: egen absmse=median(abs(dyield))
	gen dprice=refprice-price_curve
	gen net_long=(borrowing_volume -lending_volume)/10^9 /*net long position in bn*/
	gen net_long_dur=net_long*duration /*dollarduration*/
	gen net_long_conv=net_long*convexity /*dollarconvexity*/
	gen net_long_dp=net_long*dprice 
	gen net_long_dy=net_long*dyield
	gen dyield_dur=dyield*duration  /*pricing difference by duration, proxy for return*/
	drop if ttm<0.25  /*eliminates short term bonds*/
	drop if abs(dyield)>0.5  /*drop if the bond clearly does not fit the cuve*/
	
gen Date=date
merge m:1 Date using  "$dir/usbasis.dta"
drop if _merge==2
drop _merge

foreach x in TY FV TU UXY WN US {
	gen current_`x'= `x'1_FUT_CUR_GEN_TICKER 
	replace current_`x'=`x'2_FUT_CUR_GEN_TICKER if `x'2_OPEN_INT>`x'1_OPEN_INT
} /*identifies current contract based on open interest*/


foreach x in TY FV TU UXY WN US {
	gen Contract=current_`x'
	merge m:1 Contract cusip using  "$dir/deliverables2.dta"
	drop if _merge==2
	gen deliverable_`x'=_merge==3
	drop Contract _merge
}  /*identifies deliverable set*/

egen isanyDELIVERABLE=rowtotal(deliverable_*) 
replace isanyDELIVERABLE=isanyDELIVERABLE>0 /*1 if deliverable under any futures*/

foreach x in TY FV TU UXY WN US  {
	gen contract=current_`x'
	merge m:1 contract using  "$dir/firstsecondCTD.dta"
	drop if _merge==2
	rename ctd1 ctd1_`x'
	rename ctd2 ctd2_`x'
	gen isctd1_`x'=cusip==ctd1_`x'
	gen isctd2_`x'=cusip==ctd2_`x'
	drop contract _merge
}  /*matches first and second CTD bond based on frequency*/
egen isanyCTD1=rowtotal(isctd1_*)
replace isanyCTD1=isanyCTD1>0
egen isanyCTD2=rowtotal(isctd2_*)
replace isanyCTD2=isanyCTD2>0
gen isanyCTD1or2=(isanyCTD1+isanyCTD2)>0
 /*is the bond CTD or second CTD under any contract*/
 
tw (scatter TY1_OPEN_INT date if TY1_FUT_CUR_GEN_TICKER =="TYM21"& cusip=="9128283W") (scatter TY2_OPEN_INT date if TY1_FUT_CUR_GEN_TICKER =="TYM21"& cusip=="9128283W") (scatter isctd1_TY date if TY1_FUT_CUR_GEN_TICKER =="TYM21"& cusip=="9128283W", yaxis(2)) (scatter isctd1_TY date if TY1_FUT_CUR_GEN_TICKER =="TYM21"& cusip=="9128284N", yaxis(2)) , legend(order(1 "TYM21 OpenInterest" 2 "TYU21 OpenInterest" 3 "9128283W" 4 "9128284N")           position(6) cols(4) region(lstyle(none)))
	graph export "$fig/exampleCTD.pdf", replace
 /*plot to explain how we define current contract based on open interest and, consequenty CTD*/
	
	
snapshot save

*if dyield is high the bond is underpriced
	binscatter dyield net_long ,n(100) median line(none)
	binscatter dyield net_long ,n(100)  line(none)
		graph export "$fig/dyieldnet_long1.pdf", replace
	binscatter  net_long dyield ,n(100)  line(none)
		graph export "$fig/dyieldnet_long2.pdf", replace
	binscatter dyield_dur net_long ,n(100) median line(none)
	binscatter dyield net_long if ttm<3 ,n(100) median line(none)
	binscatter dyield net_long if ttm>3 & ttm<15 ,n(100) median line(none)
	binscatter dyield net_long if ttm>15 ,n(100) median line(none)
	
preserve 
collapse (sum) net_long net_long_dur net_long_conv  , by(date isin isctd1_* isctd2_* deliverable_* dyield dprice duration yield convexity ttm refprice price_curve dprice itype isanyCTD1 isanyCTD2 isanyCTD1or2)
		la var net_long "\(LongPosition_{it}\)"
foreach x in TY FV TU UXY WN US {
		gen antictd1_`x'=1-isctd1_`x'
		estpost ttest  net_long , by(antictd1_`x')
		esttab using "$tab/d`x'.tex", replace wide nonumber nomti  nogaps booktabs  b(3) label substitute($  \\$ ) ///
		cells("mu_2(label(\multicolumn{1}{c}{\(`x' CTD=0\)})) mu_1(label(\multicolumn{1}{c}{\(`x' CTD=1\)})) b(star label(\multicolumn{1}{c}{Difference}))") alignment(S[table-format=4.3]S[table-format=4.3]S[table-format=4.3,  table-space-text-post = {***}])	 starlevels(* 0.1 ** 0.05 *** 0.01)  noobs
}
collapse (sum) net_long , by(date  isanyCTD1or2)
tw (scatter net_long date if isanyCTD1or2==0) (scatter net_long date if isanyCTD1or2==1),  legend(order(1 "Is not CTD" 2  "Is 1st or 2nd CTD in any contract")           position(6) cols(2) region(lstyle(none)))
		graph export "$fig/net_longbyctd.pdf", replace
collapse (sum) net_long , by(date  )
tw (scatter net_long date )
		graph export "$fig/net_long.pdf", replace
restore
	
	

preserve
	collapse (sum) net_long net_long_dur net_long_conv  , by(date isin isctd1_* isctd2_* deliverable_* dyield dprice duration yield convexity ttm refprice price_curve dprice itype isanyCTD1 isanyCTD2 isanyCTD1or2)
		la var net_long "\(LongPosition_{it}\)"
		la var isctd1_TY "\(1stCTD^{TY}_{it}\)"
		la var isctd1_FV "\(1stCTD^{FV}_{it}\)"
		la var isctd1_TU "\(1stCTD^{TU}_{it}\)"
		la var isctd1_UXY "\(1stCTD^{UXY}_{it}\)"
		la var isctd1_WN "\(1stCTD^{WN}_{it}\)"
		la var isctd1_US "\(1stCTD^{US}_{it}\)"
		la var isctd2_TY "\(2ndCTD^{TY}_{it}\)"
		la var isctd2_FV "\(2ndCTD^{FV}_{it}\)"
		la var isctd2_TU "\(2ndCTD^{TU}_{it}\)"
		la var isctd2_UXY "\(2ndCTD^{UXY}_{it}\)"
		la var isctd2_WN "\(2ndCTD^{WN}_{it}\)"
		la var isctd2_US "\(2ndCTD^{US}_{it}\)"	
		la var deliverable_TY "\(Deliverable^{TY}_{it}\)"
		la var deliverable_FV "\(Deliverable^{FV}_{it}\)"
		la var deliverable_TU "\(Deliverable^{TU}_{it}\)"
		la var deliverable_UXY "\(Deliverable^{UXY}_{it}\)"
		la var deliverable_WN "\(Deliverable^{WN}_{it}\)"
		la var deliverable_US "\(Deliverable^{US}_{it}\)"	
		la var dyield "\(Yield - CurveYield_{it}\)"	
	
	egen bond_n = group(isin)
	sort date bond_n
	egen date_n = group(date)
	sort bond_n date_n
	xtset bond_n date_n	
	gen ttm2=floor(ttm/2 )
	reghdfe yield ,a(ttm2) res(ry)
	
	sort date net_long
	by date : gen  pctl_net_long = ceil(10 * (_n - 0.5) / _N)
	sort date dyield
	by date : gen  pctl_dyield = ceil(10 * (_n - 0.5) / _N)
	binscatter dyield net_long  ,n(100) median line(none) 
	
	sort  bond_n date_n	
	
	reghdfe net_long isctd1_* , a(date)
			est sto a1
			estadd local s "Yes", replace
	reghdfe net_long isctd1_* isctd2_* , a(date)
			est sto a2
			estadd local s "Yes", replace
	reghdfe net_long isctd1_* isctd2_* deliverable_* , a(date)
			est sto a3
			estadd local s "Yes", replace
	reghdfe net_long dyield , a(date) vce(cluster date )
			est sto a4
			estadd local s "Yes", replace
	reghdfe d.net_long dyield , a(date) vce(cluster date )
			est sto a5
			estadd local s "Yes", replace
	reghdfe net_long dyield isctd1_* isctd2_* , a(date) vce(cluster date )
			est sto a6
			estadd local s "Yes", replace
*	reghdfe net_long dyield , a(date isin) vce(cluster date )
*	reghdfe net_long dyield , a(date ) vce(cluster date isin )
	esttab a1 a2 a3 a4 a5 a6 using "$tab/t1.tex", replace star(* 0.10 ** 0.05 *** 0.01) ///
		substitute(  "0.000" "" "(.)" "" ) ar2 label b(3) nogaps booktabs   t(3)  order(  dyield ) drop( _cons     ) alignment(S[table-format=4.3]) ///
		stats(s r2_a N  , label("Date FE"  "Adj.\ R$^2$" "Obs"  ) fmt(0 3 %9.0gc ) layout("\multicolumn{1}{c}{@}" "@" "\multicolumn{1}{c}{@}" )) eqlabels(none) nonotes

		
		
	graph bar dyield , over(pctl_net_long)
		graph export "$fig/distdyield.pdf", replace
	graph bar net_long , over(pctl_net_long)
		graph export "$fig/distlong.pdf", replace
	hist net_long,by(isanyCTD1or2)
		graph export "$fig/longbyctd.pdf", replace

		

		
	sort bond_n date_n	
	gen dnet_long=d.net_long
	gen fdyield0=f0.dyield
	gen fdyield1=f25.dyield
	gen fdyield2=f50.dyield
	gen fdyield4=f100.dyield
	gen fdyield6=f150.dyield
	gen fdyield12=f250.dyield
	gen fdyield24=f500.dyield
	gen fnetlong12=f250.net_long
	gen fnetlong6=f150.net_long
	gen fprice0=f0.refprice
	gen fprice1=f25.refprice
	gen fprice2=f50.refprice
	gen fdprice0=f0.dprice
	gen fdprice1=f25.dprice
	gen fdprice2=f50.dprice
	
	graph bar (median) net_long fnetlong6 fnetlong12 ,over(pctl_net_long)
	graph bar (median) fdyield0 fdyield6 fdyield12  ,over(pctl_net_long)
	graph bar (median) fdyield0 fdyield1 fdyield2 fdyield6 ,over(pctl_net_long)
	graph bar (median) fdyield0 fdyield1 fdyield2 fdyield6 if ttm>5,over(pctl_net_long)
	graph bar (median) fprice0 fprice1 fprice2  ,over(pctl_net_long)
	graph bar (median) fdprice0 fdprice1 fdprice2  ,over(pctl_net_long)
	
	sort pctl_net_long
	gen u=fdyield12-fdyield0
	by pctl_net_long: ttest u==0
	by pctl_net_long: qreg u==0
	
restore

preserve
	collapse (sum) net_long net_long_dur net_long_conv  , by(date )
	keep if dow(date)==2
	rename date tuesday
	
	merge 1:m tuesday using  "$dir/futuresexposure.dta"
	replace futures_dolduration=futures_dolduration/10^9
	replace futures_dolconvexity=futures_dolconvexity/10^9
	replace fut_positions=fut_positions/10^9
	tw (scatter fut_positions tuesday if contract_series=="TY") (scatter fut_positions tuesday if contract_series=="FV") (scatter fut_positions tuesday if contract_series=="TU")  (scatter fut_positions tuesday if contract_series=="UXY")  (scatter fut_positions tuesday if contract_series=="WN")  (scatter fut_positions tuesday if contract_series=="US")  ,  legend(order(1 "TY" 2  "FV" 3 "TU" 4 "UXY" 5 "WN"6 "US")    position(6) cols(6) region(lstyle(none))) ytitle("Billions") 
	graph export "$fig/futures_ts.pdf", replace
	drop if _merge==2
		
	collapse (sum) futures_dolduration futures_dolconvexity fut_positions (mean) futures_duration futures_convexity , by(tuesday net_long net_long_dur net_long_conv )
	tw (scatter futures_dolduration tuesday, ysc(reverse)) (scatter net_long_dur tuesday, yaxis(2) ) ,  legend(order(1 "DollarDuration: Futures" 2  "DollarDuration: Bond")           position(6) cols(2) region(lstyle(none))) ytitle("") ytitle("", axis(2))
		graph export "$fig/dur1.pdf", replace
		
	tw (scatter futures_dolconvexity tuesday, ysc(reverse)) (scatter net_long_conv tuesday, yaxis(2) ) ,  legend(order(1 "DollarConvexity: Futures" 2  "DollarConvexity: Bond")           position(6) cols(2) region(lstyle(none))) ytitle("") ytitle("", axis(2))
		graph export "$fig/con1.pdf", replace
		
	tw (scatter futures_dolduration tuesday) (scatter futures_dolconvexity tuesday, yaxis(2) ) ,  legend(order(1 "DollarDuration: Futures" 2  "DollarConvexity: Futures")           position(6) cols(2) region(lstyle(none))) ytitle("") ytitle("", axis(2))
		graph export "$fig/fut1.pdf", replace
	tw (scatter net_long_dur tuesday) (scatter net_long_conv tuesday, yaxis(2) ) ,  legend(order(1 "DollarDuration: Bonds" 2  "DollarConvexity: Bonds")           position(6) cols(2) region(lstyle(none))) ytitle("") ytitle("", axis(2))
		graph export "$fig/bon1.pdf", replace
	tw (scatter net_long tuesday) 
		
	gen d=futures_dolduration /fut_positions
	gen c=futures_dolconvexity /fut_positions
	gen c2=net_long_conv /net_long
	gen d2=net_long_dur /net_long
		
	
	tw (scatter d tuesday) (scatter c tuesday, yaxis(2) ) , legend(pos(6))
	tw (scatter d2 tuesday) (scatter c2 tuesday, yaxis(2) ) , legend(pos(6))
	tw (scatter d2 tuesday) (scatter c2 tuesday, yaxis(2) ) if tuesday>mdy(7,1,2022), legend(pos(6))
	
	scatter futures_dolduration net_long_dur , legend(off) ytitle("Futures Dollar Duration") xtitle("Bond Dollar Duration")
		graph export "$fig/dur2.pdf", replace
	scatter futures_dolconvexity net_long_conv, legend(off) ytitle("Futures Dollar Convexity") xtitle("Bond Dollar Convexity")
		graph export "$fig/con2.pdf", replace

restore

preserve
	collapse (sum) net_long net_long_dur net_long_conv , by(isin date ttm duration convexity)
	gen morethan5=ttm>5
	collapse (sum) net_long net_long_dur net_long_conv (mean) duration convexity ttm , by(date morethan5 )
	tw (scatter net_long date if morethan5==1) (scatter net_long date if morethan5==0) ,  legend(order(1 "TTM > 5" 2 "TTM ≤ 5") ///
          position(6) cols(2) region(lstyle(none)))
	tw (scatter duration date if morethan5==1) (scatter duration date if morethan5==0) ,  legend(order(1 "TTM > 5" 2 "TTM ≤ 5") ///
          position(6) cols(2) region(lstyle(none)))
	tw (scatter convexity date if morethan5==1) (scatter convexity date if morethan5==0) ,  legend(order(1 "TTM > 5" 2 "TTM ≤ 5") ///
          position(6) cols(2) region(lstyle(none)))
	tw (scatter ttm date if morethan5==1) (scatter ttm date if morethan5==0) ,  legend(order(1 "TTM > 5" 2 "TTM ≤ 5") ///
          position(6) cols(2) region(lstyle(none)))
restore

preserve
	collapse (sum) net_long net_long_dur net_long_conv  , by(date )
	gen year=year(date)
	gen quarter=quarter(date)
	sort year quarter date
	collapse (last) net_long , by(year quarter )
	merge 1:1 year quarter using "$dir/BondExposure.dta"
	drop if _merge==2
	gen net=(BondExposureLong-BondExposureShort)/10^9
	tw (scatter net_long net)(lfit net_long net) , ytitle("SFTDS Net Long Positions") xtitle("OFR Net Long Positions") legend(off)
		graph export "$fig/ofrcomp.pdf", replace
	reg  net_long net
	reg  net_long net ,nocon
restore



	


	
	
	
