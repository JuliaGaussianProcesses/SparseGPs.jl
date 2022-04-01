### Process examples
using Pkg
Pkg.add(Pkg.PackageSpec(; url="https://github.com/JuliaGaussianProcesses/JuliaGPsDocs.jl")) # While the package is unregistered, it's a workaround

### Build documentation
using Documenter

using JuliaGPsDocs
using ApproximateGPs

JuliaGPsDocs.generate_examples(ApproximateGPs)

# Doctest setup
DocMeta.setdocmeta!(
    ApproximateGPs,
    :DocTestSetup,
    quote
        using ApproximateGPs
    end;  # we have to load all packages used (implicitly) within jldoctest blocks in the API docstrings
    recursive=true,
)

makedocs(;
    sitename="ApproximateGPs.jl",
    format=Documenter.HTML(),
    modules=[ApproximateGPs],
    pages=[
        "Home" => "index.md",
        "userguide.md",
        "API" => joinpath.(Ref("api"), ["index.md", "sparsevariational.md", "laplace.md"]),
        "Examples" => map(filter!(isdir, readdir("examples"))) do x
            joinpath("examples", x, "example.md")
        end,
    ],
    strict=true,
    checkdocs=:exports,
    doctestfilters=[
        r"{([a-zA-Z0-9]+,\s?)+[a-zA-Z0-9]+}",
        r"(Array{[a-zA-Z0-9]+,\s?1}|Vector{[a-zA-Z0-9]+})",
        r"(Array{[a-zA-Z0-9]+,\s?2}|Matrix{[a-zA-Z0-9]+})",
    ],
)

deploydocs(;
    repo="github.com/JuliaGaussianProcesses/ApproximateGPs.jl.git", push_preview=true
)
