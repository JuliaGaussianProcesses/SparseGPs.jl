const default_jitter = 1e-6

struct SVGPModel{Tlik}
    kernel_func # function to construct the kernel from `k`
    lik::Tlik   # the likelihood function
    jitter      # the jitter added to covariance matrices
    
    ## Trainable parameters
    k::AbstractVector           # kernel parameters
    m::AbstractVector           # variational mean
    A::AbstractMatrix           # variational covariance (sqrt)
    z::AbstractVector           # inducing points
end

@functor SVGPModel (k, m, A, z,)

function SVGPModel(
    kernel_func,
    kernel_params,
    inducing_inputs;
    q_μ::Union{AbstractVector, Nothing}=nothing,
    q_Σ_sqrt::Union{AbstractMatrix, Nothing}=nothing,
    jitter=default_jitter,
    likelihood=GaussianLikelihood(jitter)
)
    m, A = _init_variational_params(q_μ, q_Σ_sqrt, inducing_inputs)
    return SVGPModel(
        kernel_func,
        likelihood,
        jitter,
        kernel_params,
        m,
        A,
        inducing_inputs
    )
end

function (m::SVGPModel{<:GaussianLikelihood})(x)
    f = prior(m)
    fx = f(x, m.lik.σ²)
    fu = f(m.z, m.jitter)
    q = _construct_q(m)
    return fx, fu, q
end

function (m::SVGPModel)(x)
    f = prior(m)
    fx = f(x)
    fu = f(m.z).fx
    q = _construct_q(m)
    return fx, fu, q
end

function posterior(m::SVGPModel{<:GaussianLikelihood})
    f = prior(m)
    fu = f(m.z, m.jitter)
    q = _construct_q(m)
    return SparseGPs.approx_posterior(SVGP(), fu, q)
end

function posterior(m::SVGPModel)
    f = prior(m)
    fu = f(m.z).fx
    q = _construct_q(m)
    post = SparseGPs.approx_posterior(SVGP(), fu, q)
    return LatentGP(post, m.lik, m.jitter) # TODO: should this return `post` instead?
end

function prior(m::SVGPModel{<:GaussianLikelihood})
    kernel = m.kernel_func(m.k)
    return GP(kernel)
end

function prior(m::SVGPModel)
    kernel = m.kernel_func(m.k)
    return LatentGP(GP(kernel), m.lik, m.jitter)
end

function loss(m::SVGPModel, x, y; n_data=length(y))
    return -elbo(m, x, y; n_data)
end

function elbo(m::SVGPModel, x, y; n_data=length(y))
    fx, fu, q = m(x)
    return SparseGPs.elbo(fx, y, fu, q; n_data)
end

function _init_variational_params(n)
    m = zeros(n)
    A = Matrix{Float64}(I, n, n)
    return m, A
end

function _init_variational_params(
    q_μ::Union{AbstractVector, Nothing},
    q_Σ_sqrt::Union{AbstractMatrix, Nothing},
    z::AbstractVector
)
    n = length(z)
    if q_μ === nothing
        q_μ = zeros(n)
    end
    if q_Σ_sqrt === nothing
        q_Σ_sqrt = Matrix{Float64}(I, n, n)
    end
    return q_μ, q_Σ_sqrt
end

function _construct_q(m::SVGPModel)
    S = PDMat(Cholesky(LowerTriangular(m.A)))
    return MvNormal(m.m, S)
end