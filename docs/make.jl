using AnalyticPulses
using Documenter

DocMeta.setdocmeta!(AnalyticPulses, :DocTestSetup, :(using AnalyticPulses); recursive=true)

makedocs(;
    modules=[AnalyticPulses],
    authors="Kyle Sherbert <kyle.sherbert@vt.edu> and contributors",
    repo="https://github.com/kmsherbertvt/AnalyticPulses.jl/blob/{commit}{path}#{line}",
    sitename="AnalyticPulses.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://kmsherbertvt.github.io/AnalyticPulses.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/kmsherbertvt/AnalyticPulses.jl",
    devbranch="main",
)
