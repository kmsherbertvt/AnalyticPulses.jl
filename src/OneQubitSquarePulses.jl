import LinearAlgebra: norm
import Polynomials: Polynomial, roots
import SpecialMatrices: Vandermonde

"""
    evolve_transmon(ω, δ, Ω, ν, m, T, ψI)

Calculate the state of a single transmon after applying a constant drive.

# Parameters
- ω: resonance frequency (rad/ns)
- δ: anharmonicity (rad/ns)
- Ω: drive amplitude (rad/ns)
- ν: drive frequency (rad/ns)
- T: duration of drive (ns)
- ψI: initial state of transmon

"""
function evolve_transmon(ω, δ, Ω, ν, T, ψI)
    m = length(ψI)

    # DELEGATE TO THE ORIGINAL INTERACTION-FRAME IMPLEMENTATION
    ψ = (
        m == 2 ? _onequbitsquarepulse(ψI, T, ν, Ω, ω)
      : m == 3 ? _onequtritsquarepulse(ψI, T, ν, Ω, ω, δ)
      : error("m=$m not implemented")
    )

    # ROTATE OUT OF INTERACTION FRAME
    a = _a_matrix(m)
    n̂ =     a'* a
    η̂ = a'* a'* a * a
    return exp(-im*T*(ω*n̂ - δ/2*η̂)) * ψ
end




function _a_matrix(m::Integer=2)
    a = zeros((m,m))
    for i ∈ 1:m-1
        a[i,i+1] = √i               # BOSONIC ANNIHILATION OPERATOR
    end
    return a
end



function _onequbitsquarepulse(
    ψI,             # INITIAL WAVE FUNCTION
    T,              # PULSE DURATION (ns)
    ν,              # PULSE FREQUENCY
    Ω₀,             # PULSE AMPLITUDE
    ω₀,             # DEVICE RESONANCE FREQUENCY
)
    # HELPFUL CONSTANTS
    Δ  = ω₀ - ν             # DETUNING
    ξ  = 2Ω₀/Δ              # RELATIVE STRENGTH OF PULSE
    η  = √(1 + abs(ξ)^2)    # SCALING FACTOR

    # IMPOSE BOUNDARY CONSTRAINTS (these are coefficients for solutions to each diff eq)
    A₀ = ψI[1] *(η-1)/2η + ψI[2] * ξ/2η
    B₀ = ψI[1] *(η+1)/2η - ψI[2] * ξ/2η
    A₁ = ψI[2] *(η-1)/2η - ψI[1] * ξ'/2η
    B₁ = ψI[2] *(η+1)/2η + ψI[1] * ξ'/2η

    # WRITE OUT GENERAL SOLUTIONS TO THE DIFFERENTIAL EQUATIONS
    ψT = [
        A₀*exp(-im*Δ * (η+1)/2 * T) + B₀*exp( im*Δ * (η-1)/2 * T),
        A₁*exp( im*Δ * (η+1)/2 * T) + B₁*exp(-im*Δ * (η-1)/2 * T),
    ]

    # ROBUSTLY HANDLE lim Δ→0
    if abs(Δ) < eps(typeof(Δ))
        # Δη        → √(Δ² + |2Ω₀|²)
        # ξ/2η      → Ω₀ / Δη
        # (η±1)/2η  → (1 ± 1/η)/2
        Δη = √(Δ^2 + abs(2Ω₀)^2)
        A₀ = ψI[1] *(1 - 1/η)/2 + ψI[2] * Ω₀/Δη
        B₀ = ψI[1] *(1 + 1/η)/2 - ψI[2] * Ω₀/Δη
        A₁ = ψI[2] *(1 - 1/η)/2 - ψI[1] * Ω₀'/Δη
        B₁ = ψI[2] *(1 + 1/η)/2 + ψI[1] * Ω₀'/Δη

        ψT = [
            A₀*exp(-im* (Δη+Δ)/2 * T) + B₀*exp( im* (Δη-Δ)/2 * T),
            A₁*exp( im* (Δη+Δ)/2 * T) + B₁*exp(-im* (Δη-Δ)/2 * T),
        ]
    end

    # RE-NORMALIZE THIS STATE
    ψT .= ψT / norm(ψT)

    return ψT
end

function _onequtritsquarepulse(
    ψI,             # INITIAL WAVE FUNCTION
    T,              # PULSE DURATION (ns)
    ν,              # PULSE FREQUENCY
    Ω₀,             # PULSE AMPLITUDE
    ω₀,             # DEVICE RESONANCE FREQUENCY
    δ,              # DEVICE ANHARMONICITY
)
    # HELPFUL CONSTANTS
    Δ   = ω₀ - ν    # DETUNING
    A₁₀ = Ω₀        #           AMPLITUDE OF INTERACTION HAMILTONIAN ELEMENT ⟨1|V|0⟩
    A₂₁ = Ω₀ * √2   # DERIVATIVE MULITPLE OF INTERACTION HAMILTONIAN ELEMENT ⟨2|V|1⟩
    D₁₀ = im * Δ    #           AMPLITUDE OF INTERACTION HAMILTONIAN ELEMENT ⟨1|V|0⟩
    D₂₁ = im *(Δ-δ) # DERIVATIVE MULITPLE OF INTERACTION HAMILTONIAN ELEMENT ⟨2|V|1⟩

    # HELPFUL ALIASES
    A₁₀²= abs(A₁₀)^2
    A₂₁²= abs(A₂₁)^2
    D̄₁₀ = conj(D₁₀)
    D̄₂₁ = conj(D₂₁)

    ψT = [          # FINAL WAVEFUNCTION
        # |0⟩ COEFFICIENT
        _solve_diffeq([                 # CONSTANT COEFFICIENTS IN LINEAR DIFF EQ
            -A₁₀² * (D̄₁₀ + D̄₂₁),                            # c COEFFICIENT
            A₁₀² + A₂₁² + D̄₁₀*(D̄₁₀ + D̄₂₁),                  # ċ COEFFICIENT
            -(2D̄₁₀ + D̄₂₁),                                  # c̈ COEFFICIENT
        ],[                             # BOUNDARY CONDITIONS AT START OF THE PULSE
            ψI[1],                                          # c(t=0)
            ψI[2] * -im*A₁₀',                               # ċ(t=0)
            -A₁₀'*(A₁₀*ψI[1] + im*D̄₁₀*ψI[2] + A₂₁'*ψI[3])   # c̈(t=0)
        ])(T),                          # EVALUATE SOLUTION AT END OF THE PULSE

        # |1⟩ COEFFICIENT
        _solve_diffeq([                 # CONSTANT COEFFICIENTS IN LINEAR DIFF EQ
            -(D̄₂₁*A₁₀² + D₁₀*A₂₁²),                         # c COEFFICIENT
            A₁₀² + A₂₁² + D₁₀*D̄₂₁,                          # ċ COEFFICIENT
            -(D₁₀ + D̄₂₁),                                   # c̈ COEFFICIENT
        ],[                             # BOUNDARY CONDITIONS AT START OF THE PULSE
            ψI[2],                                                      # c(t=0)
            -im*(A₁₀*ψI[1] + A₂₁'*ψI[3]),                               # ċ(t=0)
            -(im*D₁₀*A₁₀*ψI[1] + (A₁₀²+A₂₁²)*ψI[2] + im*D̄₂₁*A₂₁'*ψI[3]) # c̈(t=0)
        ])(T),                          # EVALUATE SOLUTION AT END OF THE PULSE

        # |2⟩ COEFFICIENT
        _solve_diffeq([                 # CONSTANT COEFFICIENTS IN LINEAR DIFF EQ
            -A₂₁² * (D₁₀ + D₂₁),                            # c COEFFICIENT
            A₁₀² + A₂₁² + D₂₁*(D₁₀ + D₂₁),                  # ċ COEFFICIENT
            -(D₁₀ + 2D₂₁),                                  # c̈ COEFFICIENT
        ],[                             # BOUNDARY CONDITIONS AT START OF THE PULSE
            ψI[3],                                          # c(t=0)
            ψI[2] * -im*A₂₁,                                # ċ(t=0)
            -A₂₁*(A₁₀*ψI[1] + im*D₂₁*ψI[2] + A₂₁'*ψI[3])    # c̈(t=0)
        ])(T),                          # EVALUATE SOLUTION AT END OF THE PULSE
    ]

    # RE-NORMALIZE THIS STATE
    ψT .= ψT / norm(ψT)

    return ψT
end


function _solve_diffeq(a, b)
    # SOLVE THE AUXILIARY POLYNOMIAL EQUATION
    r = roots(Polynomial([a..., 1]))        # SOLUTIONS HAVE FORM exp(r⋅t)
    # SOLVE FOR RELATIVE WEIGHT OF EACH SOLUTION VIA BOUNDARY CONDITIONS
    C = transpose(Vandermonde(r)) \ b       # x = A \ b SOLVES MATRIX-VECTOR EQUATION Ax=b
    # RETURN A FUNCTION GIVING THE LINEAR COMBINATION OF ALL SOLUTIONS
    return t -> transpose(C) * exp.(r*t)    # THIS IS AN INNER PRODUCT OF TWO VECTORS!
end