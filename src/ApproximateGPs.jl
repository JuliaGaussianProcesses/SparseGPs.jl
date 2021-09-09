module ApproximateGPs

using Reexport
@reexport using AbstractGPs
@reexport using GPLikelihoods
using Distributions
using LinearAlgebra
using Statistics
using StatsBase
using FastGaussQuadrature
using SpecialFunctions
using ChainRulesCore
using FillArrays
using PDMats

using AbstractGPs: AbstractGP, FiniteGP, LatentFiniteGP, ApproxPosteriorGP, At_A, diag_At_A

export SVGP, DefaultQuadrature, Analytic, GaussHermite, MonteCarlo

include("utils.jl")
include("kldiv.jl")
include("svgp.jl")
include("elbo.jl")

end
