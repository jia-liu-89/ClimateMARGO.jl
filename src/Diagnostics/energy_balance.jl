"""
    F(a, c0, Finf, c, G; F0=0.)
"""
function F(a, c0, Finf, c, G; F0=0.)
    F0 .+ a .* log.( c/c0 ) .- G*Finf
end

"""
    F(m::ClimateModel; M=false, R=false, G=false)
"""
function F(m; M=false, R=false, G=false, F0=0.)
    return F(
        m.physics.a, m.physics.c0, m.economics.Finf,
        c(m, M=M, R=R),
        m.controls.geoeng .* (1. .- .~future_mask(m) * ~G),
        F0=F0
    )
end

F2x(a::Float64) = a*log(2)
F2x(m::ClimateModel) = F2x(m.physics.a)

ECS(a, B) = F2x(a)/B
ECS(params::ClimateModelParameters) = ECS(params.physics.a, m.physics.B)
ECS(m::ClimateModel) = ECS(m.physics.a, m.physics.B)

calc_B(a::Float64, ECS::Float64) = F2x(a)/ECS
calc_B(params::ClimateModelParameters; ECS=ECS(params)) = calc_B(params.physics.a, ECS)
calc_B(m::ClimateModel; ECS=ECS(m)) = calc_B(m.physics.a, ECS)

τd(Cd, B, κ) = (Cd/B) * (B+κ)/κ
τd(phys::Physics) = τd(phys.Cd, phys.B, phys.κ)
τd(m::ClimateModel) = τd(m.physics)

"""
    T_fast(F, κ, B; A=0.)
"""
T_fast(F, κ, B; A=0.) = sqrt.(1. .- A) .* F/(κ + B)

"""
    T_fast(m::ClimateModel; M=false, R=false, G=false, A=false)
"""
T_fast(m::ClimateModel; M=false, R=false, G=false, A=false) = T_fast(
    F(m, M=M, R=R, G=G),
    m.physics.κ,
    m.physics.B,
    A=m.controls.adapt .* (1. .- .~future_mask(m) * ~A)
)

"""
    T_slow(F, Cd, κ, B, t, dt; A=0.)
"""
function T_slow(F, Cd, κ, B, t, dt; A=0.)
    τ = τd(Cd, κ, B)
    return sqrt.(1. .- A) .* (
        (κ/B) / (κ + B) *
        exp.( - (t .- (t[1] - dt)) / τ) .*
        cumsum( (exp.( (t .- (t[1] - dt)) / τ) / τ) .* F * dt)
    )
end

"""
    T_slow(m::ClimateModel; M=false, R=false, G=false, A=false)
"""
T_slow(m::ClimateModel; M=false, R=false, G=false, A=false) = T_slow(
    F(m, M=M, R=R, G=G),
    m.physics.Cd,
    m.physics.κ,
    m.physics.B,
    t(m),
    m.domain.dt,
    A=m.controls.adapt .* (1. .- .~future_mask(m) * ~A)
)

"""
    T(T0, F, Cd, κ, B, t, dt; A=0.)

Returns the sum of the initial, fast mode, and slow mode temperature change.

# Arguments
- `T0::Float64`: warming relative to pre-industrial [°C]
- `F::Array{Float64}`: change in radiative forcing since the initial time ``t_{0}`` [W/m``{2}``]
- `Cd::Float64`: deep ocean heat capacity [W yr m``^{2}`` K``^{-1}``]
- `κ::Float64`: ocean heat uptake rate [W m``^{2}`` K``^{-1}``]
- `B::Float64`: feedback parameter [W m``^{2}`` K``^{-1}``]
- `t::Array{Float64}`: year [years]
- `dt::Float64`: timestep [years]
- `A::Float64`: Adaptation control [fraction]

"""
T(T0, F, Cd, κ, B, t, dt; A=0.) = sqrt.(1. .- A) .* (
    T0 .+
    T_fast(F, κ, B) .+
    T_slow(F, Cd, κ, B, t, dt)
)

"""
    T(m::ClimateModel; M=false, R=false, G=false, A=false)

Returns the sum of the initial, fast mode, and slow mode temperature change,
as diagnosed from `m` and modified by the climate controls activated by the
Boolean kwargs.
"""
T(m::ClimateModel; M=false, R=false, G=false, A=false) = T(
    m.physics.T0,
    F(m, M=M, R=R, G=G),
    m.physics.Cd,
    m.physics.κ,
    m.physics.B,
    t(m),
    m.domain.dt,
    A=m.controls.adapt .* (1. .- .~future_mask(m) * ~A)
)
