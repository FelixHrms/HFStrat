import delimited "D:/mts/hf_positions.csv", clear
drop date
gen date= date(business_date, "YMD")
format date %td
replace yield="" if substr(yield,1,3)=="inf"
destring yield, replace

replace amt_out=amt_out/10^9
drop if strip!=""
drop if !inlist(coupontype,0,1)

gen diff_y=yield-refyield
gen diff_y2=yield-yield_curve
bysort date country: egen absmse=median(abs(diff_y2))

drop if absmse>0.2
drop if yield>7 | yield<-2 | refyield>7 |refyield<-2
drop if ttm<0.25
drop if abs(diff_y)>0.25
drop if abs(diff_y2)>1

gen dyield=refyield -yield_curve
gen dprice=refprice-price_curve
gen net_long=(borrowing_volume -lending_volume)/10^9 /*net long position*/
gen net_long_dur=net_long*duration
gen net_long_dp=net_long*dprice
gen net_long_dy=net_long*dyield
gen j=dyield *net_long >0
gen dyield_dur=dyield*duration

preserve
	collapse (sum) net_long  , by(date  country )
	tw (scatter net_long date if country=="DE") (scatter net_long date if country=="IT")  	 (scatter net_long date if country=="FR")  	 (scatter net_long date if country=="ES")   ,  legend(order(1 "DE" 2  "IT" 3 "FR" 4 "ES")    position(6) cols(4) region(lstyle(none))) ytitle("Billions") 
			graph export "$fig/eu_pos.pdf", replace
restore 

preserve
	keep date isin refprice duration amt_out dyield
	duplicates drop

	egen bond_n = group(isin)
	sort date bond_n
	egen date_n = group(date)
	sort bond_n date_n
	xtset bond_n date_n	

	gen ret=log(refprice)-log(l.refprice)
	gen amt_out_mktprice=amt_out*refprice/100
	gen retbyq=ret*amt_out_mktprice
	collapse (sum) retbyq amt_out amt_out_mktprice ,by(date date_n)
	tset date_n
	gen ret=retbyq/amt_out_mktprice
	save "D:/portfolio.dta", replace
restore


	binscatter dyield net_long ,n(100) median line(none)
	binscatter dyield net_long ,n(100)  line(none)
	binscatter  net_long dyield ,n(100)  line(none)
	binscatter dyield_dur net_long ,n(100) median line(none)
	binscatter dyield net_long if ttm<3 ,n(100) median line(none)
	binscatter dyield net_long if ttm>3 & ttm<15 ,n(100) median line(none)
	binscatter dyield net_long if ttm>15 ,n(100) median line(none)



collapse (sum) net_long net_long_dur net_long_dp net_long_dy , by(date isin country coupontype ///
yield dyield dyield_dur dprice ttm refprice)
	egen bond_n = group(isin)
	sort date bond_n
	egen date_n = group(date)
	sort bond_n date_n
	xtset bond_n date_n	
	gen k=dprice/refprice
	encode country, g(country2)
	gen ttm2=floor(ttm/2 )
	reghdfe yield ,a(country2##ttm2) res(ry)
	
	binscatter dyield net_long  ,n(100) median line(none)
	binscatter dyield net_long  ,n(100)  line(none)

	
	drop if ttm<3
	egen countrydate=concat(country date)
	sort countrydate net_long
	bysort countrydate : gen  pctl_net_long = ceil(10 * (_n - 0.5) / _N)

	sort bond_n date_n	
	gen fdyield0=f0.ry
	gen fdyield1=f25.ry
	gen fdyield2=f50.ry
	gen fdyield4=f100.ry
	gen fdyield6=f150.ry
	gen fdyield12=f250.ry
	gen fdyield24=f500.ry
	gen fnetlong12=f250.net_long
	gen fnetlong6=f150.net_long
	
	sort countrydate net_long
	graph bar (median) fdyield0 fdyield6 fdyield12 fdyield24 ,over(pctl_net_long)
	graph bar (median) fdyield0 fdyield6 fdyield12 fdyield24 if ttm>5,over(pctl_net_long)
	graph bar (median) fdyield0 fdyield6 fdyield12 fdyield24 ,over(pctl_dyield)
	graph bar (median) net_long fnetlong6 fnetlong12 ,over(pctl_net_long)
	
	gen u=fdyield24-fdyield0
	by pctl_net_long: ttest u==0
	by pctl_net_long: qreg u==0
	
	
	
merge 1:1 date using "D:/portfolio.dta"
sort date_n
tset date_n	 
gen f_ret=(1+f1.ret)*(1+f2.ret)*(1+f3.ret)*(1+f4.ret)*(1+f5.ret)

gen ret_hf=net_long/l.net_long-1 
gen change_pos=net_long-l.net_long
tw (line net_long_dur date) (line retma date, yaxis(2)) , legend(pos(6))


