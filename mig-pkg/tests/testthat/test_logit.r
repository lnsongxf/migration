

# test packge functions
library(migration)


# get auxiliary test data

n  <- 100	# number of people
A  <- 10	# max number of ages
nm <- 5		# number of movers
tt <- makeTestData(n,A,nm)

# make income equation coefs
RE.coefs <- makeTestREcoefs(te=tt$dat)

data(State_distMat_agg,package="EconData")



# test getREintercept
# ===================

test_that("getREintercept adds the correct intercept",{

	s       <- sample(names(RE.coefs),size=1)
	tmps    <- tt$dat[state==s]
	
	tmps <- getREintercept(tmps,RE.coefs[[s]])
	expect_that( all.equal( tmps[,unique(intercept)] , RE.coefs[[s]]$RE[,intercept] - RE.coefs[[s]]$fixed[[1]] ), is_true() )

})



# test prediction2 
# ================

test_that("makePrediction2 has correct attributes", {

	stn     <- names(RE.coefs)
	s       <- sample(stn,size=1)
	tmps    <- tt$dat[state==s]
	tmps <- getREintercept(tmps,RE.coefs[[s]])

	with.FE <- TRUE		
	m <- getIncomeM(with.FE,tmps)

	t1 <- makePrediction2(s,RE.coefs,m,with.FE,tmps,State_distMat_agg)

	expect_that( t1, is_a("data.table") )
	expect_equal( attr(t1,"origin"), s )
	expect_equal( attr(t1,"with.FE"), with.FE )
	expect_equal( attr(t1,"pred.for"),  stn[-which(stn==s)])
	
	with.FE <- FALSE
	m <- getIncomeM(with.FE,tmps)

	t1 <- makePrediction2(s,RE.coefs,m,with.FE,tmps,State_distMat_agg)

	expect_that( t1, is_a("data.table") )
	expect_equal( attr(t1,"origin"), s )
	expect_equal( attr(t1,"with.FE"), with.FE )
	expect_equal( attr(t1,"pred.for"),  stn[-which(stn==s)])
	})


test_that("makePrediction2 output is correct", {

	s       <- sample(names(RE.coefs),size=1)
	tmps    <- tt$dat[state==s]
	tmps <- getREintercept(tmps,RE.coefs[[s]])
	with.FE <- TRUE		
	m <- getIncomeM(with.FE,tmps)

	t1 <- makePrediction2(s,RE.coefs,m,with.FE,tmps,State_distMat_agg)
	setkey(t1,state,move.to)

	# if move to
	for (st in t1[,unique(state)]) {

		expect_equal( nrow(t1[.(st)]) / (length(attr(t1,"pred.for")) + 1), nrow(tmps) )
		expect_that( all.equal(t1[.(s,st)][,wealth], tmps[,wealth] ), is_true())
		expect_that( all.equal(t1[.(s,st)][,age], tmps[,age] ), is_true())

		if (st==s){
			expect_that( all(t1[.(s,st)][,logHHincome] == tmps[,logHHincome] ), is_true(), label="st==s")
			expect_that( all(t1[.(s,st)][,move.to] == tmps[,state] ), is_true(), label="st==s")
			expect_that( all(t1[.(s,st)][,distance] == 0 ), is_true(), label="st==s")
		} else {
			expect_that( all(t1[.(s,st)][,logHHincome] != tmps[,logHHincome] ), is_true(), label="st!=s")
			expect_that( all(t1[.(s,st)][,move.to] != tmps[,state] ), is_true(), label="st!=s")
			expect_that( all(t1[.(s,st)][,move.to] == st ), is_true(), label="st!=s")
			expect_that( all(t1[.(s,st)][,distance] == State_distMat_agg[s,st] ), is_true(), label="st!=s")
		}
	}
})




# test prediction1 
# ================

test_that("makePrediction1 has correct size", {


	with.FE <- TRUE		
	t1 <- makePrediction1(tt$dat,RE.coefs,with.FE,State_distMat_agg)

	expect_equal( nrow(t1), nrow(tt$dat)*tt$dat[,length(unique(state))])
})
     


test_that("test that homevalues merge is correct",{

	tdat <- makePrediction1(tt$dat,RE.coefs,with.FE=TRUE,State_distMat_agg)
	l    <- mergeHomeValues(tdat)

	yr   <- l[,list(year=unique(year)),by=move.to]
	HV   <- getHomeValues()

	setkey(HV,State,year)
	setkey(l,move.to,year)

	expect_that( l[,list(sd=sd(HValue96,na.rm=T)),by=list(upid,age)][,min(sd) > 0], is_true() , label="Hvalue varies by person and age")
	expect_that( all.equal( l[,list(hv=unique(HValue96)),by=list(move.to,year)][,hv], HV[yr[,list(move.to,year)]][,HValue96] ), is_true() )

})


# test DTSetChoice
# ================

test_that("DTSetChoice has correct output",{


	tdat <- makePrediction1(tt$dat,RE.coefs,with.FE=TRUE,State_distMat_agg)
	tdat[,choice := FALSE]
	tdat[,stay   := FALSE]

	setkey(tdat,upid,age)
	setkey(tt$mvtab,upid,age)

	# get the movers in the age where they move
	tdat <- 	tdat[tt$mvtab]

	# set their discrete choice to TRUE in the age they moved
	t2 <- DTSetChoice(tdat)

	expect_true( all(t2[move.to == to][, choice]) )
	expect_true( !any(t2[move.to == to][, stay]) )

})


# test mergePredIncomeMovingHist 
# ================v============

test_that("mergePredIncomeMovingHist correct output", {

	tdat <- makePrediction1(tt$dat,RE.coefs,with.FE=TRUE,State_distMat_agg)
	tdat[,choice := FALSE]
	tdat[,stay   := FALSE]

	# values to test:
	l <- mergePredIncomeMovingHist(tdat,tt$mvtab)


	# control values:
	setkey(tdat,upid,age)
	setkey(tt$mvtab,upid,age)

	# get the movers in the age where they move
	mdat <- 	tdat[tt$mvtab]
	mdat[,c("from","to") := NULL]


	# test: in l, all non-movers can have only one "stay" per age
	# 1) get movers from l

	setkey(l,upid,age)
	setkey(mdat,upid,age)

	# separate movers and non movers
	nonmv.from.l <- l[!J(mdat[,list(upid,age)])]	# NEVER move
	   mv.from.l <- l[   mdat[,list(upid,age)] ]	# move in one of many cases

	# in an age where you are a mover, you cannot be a nonmover
	mv.from.l1 <- mv.from.l[,list(id=unique(upid)),by=age]
	for (i in 1:nrow(mv.from.l1)){

		expect_that( nrow(nonmv.from.l[upid==mv.from.l1[i][["id"]] & age==mv.from.l1[i][["age"]]]), equals( 0 ) )
	}

	# in mover section, there is nobody apart from upid who is moving at age
	setkey(mv.from.l,age,upid)
	expect_that( nrow( mv.from.l[!J(mv.from.l1)] ), equals( 0 ) )

	# in non-mover section, people who move in mv.from.l are stayers
	setkey(nonmv.from.l,age,upid)

	for (i in 1:nrow(mv.from.l1)){

		expect_that( l[upid==mv.from.l1[i][["id"]] & age!=mv.from.l1[i][["age"]] ][choice==TRUE,all(stay)], is_true() )
		expect_that( l[upid==mv.from.l1[i][["id"]] & age!=mv.from.l1[i][["age"]] ][choice==TRUE,all(distance==0)],  is_true(  ) )
		expect_that( l[upid==mv.from.l1[i][["id"]] & age!=mv.from.l1[i][["age"]] ][choice==TRUE,all.equal(state,move.to)], is_true() )

	}


	# in non-mover section, all who never where movers, are always stayers
	setkey(nonmv.from.l,upid)
	expect_that( nonmv.from.l[!J(mv.from.l1[,unique(id)])][choice==TRUE,all(stay)], is_true() )
	expect_that( nonmv.from.l[!J(mv.from.l1[,unique(id)])][choice==TRUE,all.equal(state,move.to)], is_true() )

	# in entire dataset, wherever move.to==
	expect_that( l[move.to==state, all(stay)], is_true() )

})





