# Module for simulating the kite control unit (KCU).

module KitePodSimulator # better: KitePodModels

using KiteUtils, KitePodSimulator, Parameters

export calc_alpha_depower, init_kcu, set_depower_steering, get_depower, get_steering, on_timer
export KCU

if ! isfile("./data/settings.yaml")
    copy_settings()
end   

"""
    mutable struct KCU

Stuct that is storing the settings and the state of the kite control unit. 
"""
@with_kw mutable struct KCU
    set::Settings = se()
    set_depower::Float64 =         0.0
    set_steering::Float64 =        0.0
    depower::Float64 =             0.0                         #    0 .. 1.0
    steering::Float64 =            0.0                         # -1.0 .. 1.0
end

"""
    init_kcu(kcu::KCU, set::Settings)

Inititalze the simulator. Must be called at the beginning of the simulation. The 
actual and the set values of depower are initialized to set.depower_offset * 0.01,
the actual and the set values of steering to zero. 
"""
function init_kcu(kcu::KCU, set::Settings)
    kcu.set = set
    kcu.set_depower =         set.depower_offset * 0.01
    kcu.set_steering =        0.0
    kcu.depower =             set.depower_offset * 0.01   #    0 .. 1.0
    kcu.steering =            0.0                         # -1.0 .. 1.0
    nothing
end

# Calculate the length increase of the depower line [m] as function of the relative depower
# setting [0..1].
function calc_delta_l(kcu::KCU, rel_depower)
    u = kcu.set.depower_drum_diameter
    l_ro = 0.0
    rotations = (rel_depower - 0.01 * kcu.set.depower_offset) * 10.0 * 11.0 / 3.0 * (3918.8 - 230.8) / 4096.
    while rotations > 0.0
         l_ro += u * π    
         rotations -= 1.0
         u -= kcu.set.tape_thickness
    end
    if rotations < 0.0
         l_ro += (-(u + kcu.set.tape_thickness) * rotations + u * (rotations + 1.0)) * π * rotations
    end
    return l_ro
end


"""
    calc_alpha_depower(kcu::KCU, rel_depower)

Calculate the change of the angle between the kite and the last tether segment [rad] as function of the
actual rel_depower value. 

Returns `nothing` in case of error.
"""
function calc_alpha_depower(kcu::KCU, rel_depower)
    a   =  kcu.set.power2steer_dist
    b_0 = kcu.set.height_b + 0.5 * kcu.set.height_k
    b = b_0 + 0.5 * calc_delta_l(kcu, rel_depower) # factor 0.5 due to the pulleys

    c = sqrt(a * a + b_0 * b_0)
    # print 'a, b, c:', a, b, c, rel_depower
    if c >= a + b
         println("ERROR in calc_alpha_depower!")
         return nothing
    else
        tmp = 1/(2*a*b)*(a*a+b*b-c*c)
        if tmp > 1.0
            println("-->>> WARNING: tmp > 1.0: $tmp")
            tmp = 1.0
        elseif tmp < -1.0
            println("-->>> WARNING: tmp < 1.0: $tmp")
            tmp = -1.0
        end            
        return pi/2.0 - acos(tmp)
    end
end

"""
    set_depower_steering(kcu::KCU, depower, steering)

Set the values of depower and steering. The value for depower must be between 0.0 and 1.0,
the value for steering between -1.0 and +1.0 .
"""
function set_depower_steering(kcu::KCU, depower, steering)
    kcu.set_depower  = depower
    kcu.set_steering = steering
    nothing
end

"""
    get_depower(kcu::KCU)

Read the current depower value. Result will be between 0.0 and 1.0.
"""
function get_depower(kcu::KCU);  return kcu.depower;  end

"""
    get_steering(kcu::KCU)

Read the current depower value. Result will be between -1.0 and 1.0.
"""
function get_steering(kcu::KCU); return kcu.steering; end

"""
    on_timer(kcu::KCU, dt = 0.0)

Must be called at each clock tick. Parameter: Δt in seconds    
Updates the current values of steering and depower depending
on the set values and the last value.
If dt == 0.0, then it will be set to 1.0 / kcu.set.sample_freq .
"""
function on_timer(kcu::KCU, dt = 0.0)
    if dt == 0.0
        dt = 1.0 / kcu.set.sample_freq
    end
    # calculate the depower motor velocity
    vel_depower = (kcu.set_depower - kcu.depower) * kcu.set.depower_gain
    # println("vel_depower: $(vel_depower)")
    if vel_depower > kcu.set.v_depower
        vel_depower = kcu.set.v_depower
    elseif vel_depower < -kcu.set.v_depower
        vel_depower = -kcu.set.v_depower
    end
    # update the position
    kcu.depower += vel_depower * dt
    # calculate the steering motor velocity
    vel_steering = (kcu.set_steering - kcu.steering) * kcu.set.steering_gain
    if vel_steering > kcu.set.v_steering
        vel_steering = kcu.set.v_steering
    elseif vel_steering < -kcu.set.v_steering
        vel_steering = -kcu.set.v_steering
    end
    kcu.steering += vel_steering * dt
    nothing
end

end