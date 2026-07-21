use "J:/hf strategies/hedge-fund-strategies/key dataframe/sftds_dataframe.dta" , clear

encode isin, g(bond)
encode entity_id, g(fund)


drop if borrowing_volume >3*10^9
drop if lending_volume >3*10^9	

gen net=borrowing_volume-lending_volume
gen country=substr(isin,1,2)
gen Date=date
format Date %td
sort date entity_id isin

replace borrowing_volume=borrowing_volume/10^9
replace lending_volume=lending_volume/10^9
replace net=net/10^9

by date: egen nbonds = nvals(isin)
by date: egen nfunds = nvals(entity_id)

preserve
	keep date nbonds nfunds 
	duplicates drop
	scatter nbonds date 
	scatter nfunds date 
	scatter nbonds nfunds
restore

drop if nbonds < 600 



/* THE MAJORITY OF TRADING IN SFTDS IS BY FUNDS DIRECTLY, NOT VIA BANKS, ESPECIALLY TRUE FOR US*/
preserve
	drop if substr(isin,1,2) == "US"
	collapse (sum) net, by(date  bank_indicator)
	tw (scatter net date if bank_indicator==1) (scatter net date if bank_indicator==0) , legend(order(1 "Via Banks" 2 "Direct"))
restore
preserve
	drop if substr(isin,1,2) != "US"
	collapse (sum) net, by(date  bank_indicator)
	tw (scatter net date if bank_indicator==1) (scatter net date if bank_indicator==0) , legend(order(1 "Via Banks" 2 "Direct"))
restore

/*35% of positions are made up by 5 funds, 50% by the top 10 */
preserve
	drop if bank_indicator==1
	collapse (sum) net, by(date entity_id)
	gen absnet=abs(net)
	gsort date -absnet
	by date: gen n=_n
	by date: egen sumtop=sum(absnet*(n<=5))
	by date :  egen sumall=sum(absnet)
	gen frac=sumtop/sumall
	scatter frac date	
	sum frac
restore

/*Positions in bonds are somewhat concentrated. Top 10 bonds for each country make up 22% of total positions in US 41 DE 28 IT, a single bond was at most 10% of total borrowing/lending in US (9 DE, 7 IT) */
preserve
	collapse (sum) net, by(date isin)
	gen country=substr(isin,1,2)
	gen absnet=abs(net)
	gsort date country -absnet
	by date country: gen n=_n
	by date country: egen sumtop=sum(absnet*(n<=10))
	by date country: egen sumall=sum(absnet)
	gen frac_top=sumtop/sumall
	gen frac = absnet/sumall
	sepscatter frac_top date	 , separate(country)
	bysort country:	sum frac_top frac
restore





preserve
*TO REDO
	merge m:1 Date using  "J:/hf strategies/hedge-fund-strategies/key dataframe/basis.dta" , keep(1 3) nogen
	merge m:1 date isin using  "J:/hf strategies/hedge-fund-strategies/key dataframe/bond_day_DT.dta" 
	
	collapse (sum) net, by(date country isctd)
	tw (scatter net date if isctd==1)(scatter net date if isctd==0),by(country)
restore

preserve
	merge m:1 date isin using  "J:/hf strategies/hedge-fund-strategies/key dataframe/bond_day_DT.dta" , keep (1 3) nogen
	gen newotrnumb=otr_number
	replace newotrnumb=3 if otr_number>=3
	label define ctdnmbr 1 "1st" 2 "2nd" 3 "Other"
	label values newotrnumb ctdnmbr
	gen newcountry="US"
	replace newcountry="EU" if country!="US"
	collapse (sum) net, by(date newotrnumb newcountry)
	sepscatter net date , separate(newotrnumb)
	tw (scatter net date if newotrnumb==1)(scatter net date if newotrnumb==2)(scatter net date if newotrnumb==3),by(newcountry)
restore
