

# main programme
home = ENV["HOME"]
cd("$home/git/migration/mig")


# include("src/estimation.jl")
cd("$home/git/migration/mig.jl/src/sge")
include("examples/slices.jl")

include("src/mig.jl")

	
# run simulation
# plot 5 guys
# return moments
@time s = mig.runSim();

p = mig.Param(2,1)
@time m = mig.Model(p)	# 1.5 secs
@time mig.solve!(m,p)	
mig.vhplot(m,p,(7,1,2,3,3,1,7,1))
mig.vhplot(m,p,(1,1,1,1,1,1,1,1))
mig.vhplot(m,p,(1,1,1,1,1,1,1,29))
mig.vplot(m,p)
@time s = mig.simulate(m,p);	
mig.simplot(s,5)
# @profile s = mig.simulate(m,p);	

# mms2 = mig.simulate_parts(m,p,5)

# write sim to disk
outdir = joinpath(ENV["HOME"],"Dropbox/mobility/output/model/data_repo/out_data_jl")
mig.simexport(s,6,joinpath(outdir,"simdata.csv"))

maximum(m.EV[:,:,:,:,:,:,:,:,29])
m.sh[1,1,1,1,1,1,:,1,1,1,1]
m.vh[1,1,2,3,3,1,1,:,1,1,1][:]
reshape(m.vh[:,1,1,1,1,m.aone,1,1,:,1],p.nJ,p.nJ)
reshape(m.v[:,1,1,1,1,m.aone,1,1,:,1],p.nJ,p.nJ)
reshape(m.rho[:,1,1,1,1,m.aone,1,1,:,1],p.nJ,p.nJ)


show(mig.DataFrame(moment=["move","own"],value=[mean(s[:move]),mean(s[:h])]))
	
@time mms = mig.computeMoments(s,p,m);

# run objective
p2 = Dict{ASCIIString,Float64}()
p2["gamma"] = 1.4
indir = joinpath(ENV["HOME"],"Dropbox/mobility/output/model/data_repo/in_data_jl")
moms = mig.DataFrame(mig.read_rda(joinpath(indir,"moments.rda"))["m"])

@time x = mig.objfunc(p2,moms,array(moms[:moment]))
mprob = MOpt.MProb(p2,pb	,mig.objfunc,moms,moments_subset=setdiff(moms[:moment],["moved0","moved1","moved2","move_rate","move_rate_h0","move_rate_h1","own_rate","wealth_h_0","wealth_h_1"]))


# testing
include("test/test_param.jl")
include("test/test_model.jl")
include("test/test_solver.jl")
include("test/test_solution.jl")
include("test/test_sim.jl")    