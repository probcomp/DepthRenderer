using ProfileView
using JLD, ProfileView
@load "profdata.jld"
ProfileView.view(li, lidict=lidict)
readline(stdin)
