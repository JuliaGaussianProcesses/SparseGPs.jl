# A recreation of <https://gpflow.readthedocs.io/en/master/notebooks/advanced/gps_for_big_data.html>

# # Stochastic Variational Regression
#
# In this example, we show how to construct and train the stochastic variational
# Gaussian process (SVGP) model for efficient inference in large scale datasets.
# For a basic introduction to the functionality of this library, please refer to
# the [User Guide](@ref).
#
# ## Setup

using SparseGPs
using Distributions
using LinearAlgebra
using IterTools

using Plots
default(; legend=:outertopright, size=(700, 400))

using Random
Random.seed!(1234)
#md nothing #hide

# ## Generate some training data
#
# The data generating function `g`

function g(x)
    return sin(3π * x) + 0.3 * cos(9π * x) + 0.5 * sin(7π * x)
end

N = 10000 # Number of training points
x = rand(Uniform(-1, 1), N)
y = g.(x) + 0.3 * randn(N)

scatter(x, y; xlabel="x", ylabel="y", markershape=:xcross, markeralpha=0.1, legend=false)

# ## Set up a Flux model
#
# We shall use the excellent framework provided by [Flux.jl](https://fluxml.ai/)
# to perform stochastic optimisation. The SVGP approximation has three sets of
# parameters to optimise - the inducing input locations, the mean and covariance
# of the variational distribution `q` and the parameters of the
# kernel.
#
# First, we define a helper function to construct the kernel from its parameters
# (often called kernel hyperparameters), and pick some initial values `k_init`.

using Flux

function make_kernel(k)
    return softplus(k[1]) * (SqExponentialKernel() ∘ ScaleTransform(softplus(k[2])))
end

k_init = [0.3, 10]
#md nothing #hide

# Then, we select some inducing input locations `z_init`. In this case, we simply choose
# the first `M` data inputs.

M = 50 # number of inducing points
z_init = x[1:M]
#md nothing #hide

# Finally, we initialise the parameters of the variational distribution `q(u)`
# where `u ~ f(z)` are the pseudo-points. We parameterise the covariance matrix
# of `q` as `C = AᵀA` since this guarantees that `C` is positive definite.

m_init = zeros(M)
A_init = Matrix{Float64}(I, M, M)
q_init = MvNormal(m_init, A_init'A_init)
#md nothing #hide

# Given a set of parameters, we now define a Flux 'layer' which forms the basis
# of our model.

struct SVGPModel
    k  # kernel parameters
    z  # inducing points
    m  # variational mean
    A  # variational covariance
end

Flux.@functor SVGPModel (k, z, m, A)
#md nothing #hide

# Create the 'model' from the parameters - i.e. return the FiniteGP at inputs x,
# the FiniteGP at inducing inputs z and the variational posterior over inducing
# points - q(u).

lik_noise = 0.3
jitter = 1e-5

# Next, we define some useful functions on the model - creating the prior GP
# under the model, as well as the `SVGP` struct needed to create the posterior
# approximation and to compute the ELBO.

function prior(m::SVGPModel)
    kernel = make_kernel(m.k)
    return GP(kernel)
end

function make_approx(m::SVGPModel, prior)
    q = MvNormal(m.m, m.A'm.A)
    fz = prior(m.z, jitter)
    return SVGP(fz, q)
end
#md nothing #hide

# Create the approximate posterior GP under the model.

function model_posterior(m::SVGPModel)
    svgp = make_approx(m, prior(m))
    return posterior(svgp)
end
#md nothing #hide

# Define a predictive function for the model - in this case the prediction is
# the joint distribution of the approximate posterior GP at some test inputs `x`
# (defined by an `AbstractGPs.FiniteGP`).

function (m::SVGPModel)(x)
    post = model_posterior(m)
    return post(x)
end
#md nothing #hide

# Return the loss given data - for the SVGP, the loss used is the negative ELBO
# (also known as the Variational Free Energy). `n_data` is required for
# minibatching used below.

function loss(m::SVGPModel, x, y; n_data=length(y))
    f = prior(m)
    fx = f(x, lik_noise)
    svgp = make_approx(m, f)
    return -elbo(svgp, fx, y; n_data)
end
#md nothing #hide

# Finally, create the model with initial parameters

model = SVGPModel(k_init, z_init, m_init, A_init)
#md nothing #hide

# ## Training the model
#
# Training the model now simply proceeds with the usual `Flux.jl` training loop.

opt = ADAM(0.001)  # Define the optimiser
params = Flux.params(model)  # Extract the model parameters
#md nothing #hide

# One of the major advantages of the SVGP model is that it allows stochastic
# estimation of the ELBO by using minibatching of the training data. This is
# very straightforward to achieve with `Flux.jl`'s utilities:

b = 100 # minibatch size
data_loader = Flux.Data.DataLoader((x, y); batchsize=b)

# The loss (negative ELBO) before training

println(loss(model, x, y))

# Train the model

Flux.train!(
    (x, y) -> loss(model, x, y; n_data=N),
    params,
    ncycle(data_loader, 300), # Train for 300 epochs
    opt,
)
#md nothing #hide

# Negative ELBO after training

println(loss(model, x, y))

# Finally, we plot samples from the optimised approximate posterior to see the
# results.

post = model_posterior(model)

scatter(
    x,
    y;
    markershape=:xcross,
    markeralpha=0.1,
    xlim=(-1, 1),
    xlabel="x",
    ylabel="y",
    title="posterior (VI with sparse grid)",
    label="Train Data",
)
plot!(-1:0.001:1, post; label="Posterior")
plot!(-1:0.001:1, g; label="True Function")
vline!(z_init; label="Pseudo-points")