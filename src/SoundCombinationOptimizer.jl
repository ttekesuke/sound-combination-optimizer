module SoundCombinationOptimizer

using Base64
using Dates
using DSP
using FFTW
using JSON3
using LinearAlgebra
using Statistics
using UUIDs
using WAV

include("AudioFeatures.jl")
include("Inventory.jl")
include("Optimizer.jl")
include("Synthesis.jl")
include("MusicXML.jl")
include("API.jl")

export inventory_status, orchestrate_request

end
