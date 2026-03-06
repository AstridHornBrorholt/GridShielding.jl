# GridShielding.jl

[![Build Status](https://github.com/AsgerHB/GridShielding.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/AsgerHB/GridShielding.jl/actions/workflows/CI.yml?query=branch%3Amain)

Package for approximating *shields* for safe reinforcement learning. The approximation method treats the system as a *black box* and thus allows a rich set of models including hybrid systems.
The shield is maximally permissive under the abstraction, but will restrict all unsafe actions. This allows a reinforcement learning agent to safely explore an environment, thus producing safe and optimal policies. 

If you use this package in your work, please cite the reference [here](Citation.bib) or below: 

```bibtex
@inproceedings{BrorholtJLLS23,
author       = {Asger Horn Brorholt and
                Peter Gj{\o}l Jensen and
                Kim Guldstrand Larsen and
                Florian Lorber and
                Christian Schilling},
editor       = {Bernhard Steffen},
title        = {Shielded Reinforcement Learning for Hybrid Systems},
booktitle    = {{AISoLA}},
series       = {LNCS},
volume       = {14380},
pages        = {33--54},
publisher    = {Springer},
year         = {2023},
url          = {https://doi.org/10.1007/978-3-031-46002-9_3},
doi          = {10.1007/978-3-031-46002-9_3}
}
```

## Instalation


    using Pkg
    Pkg.add(url="https://github.com/AstridHornBrorholt/GridShielding.jl")


Or in the repl: `] add https://github.com/AstridHornBrorholt/GridShielding.jl`

## Notebooks

See the [Pluto Notebook examples](notebooks) for detailed working examples.
Before use, navigate to the folder and install the GridShielding package.

    cd notebooks
    julia
    ] activate .
    ] add https://github.com/AstridHornBrorholt/GridShielding.jl 

## Quickstart

### Model

The model must be encoded as a simulation function that takes  1) An array representing the state 2) An action encoded as an [enum](https://docs.julialang.org/en/v1/base/base/#Base.Enums.@enum),  3) And an array of "random" values. 
```julia
@enum MyAction a b c

function simulate(state::Array{Double}, action::MyAction, random::Array{Double})::Array{Double}
    # code goes here
    # Random variables are sampled from random[1], random[2], ... Do not use rand() directly.
    return new_state
end

# Tip: Make a variant of your function that automatically draws random variables
function simulate(state::Array{Double}, action::MyAction)::Array{Double}
    random = [rand(Float64), rand(Float64)] # Fixed number of random variables, as needed. The function rand(Float64)  gives values between 0.0 and 1.0
    return new_state
end
```

### Grid

The shield is represented as a finite partition of a state-space, associating sets of allowed actions with each partition.
The grid is defined as the outer bounds of your state-space, and a granularity (partition-size) of each axis.
The following describes the state-space $[-10; 10)×[-1; 2)$

```julia
# Array of (inclusive) lower bounds, followed by (strict) upper bounds.
outer_bounds = Bounds([-10, -1], [10, 2])

granularity = [1.0, 0.01]

grid = Grid(granularity, outer_bounds)
```

This results in a grid with $(10-(-10))/1.0 + (2-(-1))/0.01 = 20/1.0 + 3/0.01 = 320$ partitions. 

Initialize the grid with

```julia
function is_safe(bounds::Bounds)::Bool
    # Your code here
end

# Sets of actions are encoded in the grid as integers. This is resp. {a, b, c} and {}
any_action, no_action = actions_to_int(instances(MyAction)), actions_to_int([])

initialize!(grid, state -> is_safe(state) ? any_action : no_action)
```

Find the unique partition containing a state by calling `box(grid, state)`, e.g. `box(grid, [0.0, 0.1])` gives the partition $[0, 1)×[0.99, 0.1)$.

### Reachability Function

Given a partition and action, the package approximates the set of reachable partitions by "barbaric" reachability.
The method samples from states within the partition, and from different values of the "random" variables.
This is done through sampling.

This requires bounds of the "random" variables, and the number of samples in each of the state dimensions and random dimensions.

```julia
random_bounds = Bounds([0.0, 0.0], [1.0, 1.0])
samples = [3, 4] # 3 samples along the first axis, 4 samples among the second.
samples_random = [3, 3]

# Use these definitions, and the simulate function from above
reach = get_barbaric_reachability_function(SimulationModel(simulate, random_bounds, samples, samples_random))
```

Samples favour corner-points, and the total number of simulation-samples per partition is the product of the samples-vectors: $3×4×3×3=108$.
This is the number of times `simulate` will be called per partition.

### Synthesising the Shield

Putting it all together, 

```julia
reach_computed = get_transitions(reach, MyAction, grid)
shield, max_iterations_exceeded = make_shield(reach_computed, MyAction, grid, max_iteration_steps=1e6)
```

The second function returns the shield (of type `Grid`) and a flag indicating if the number of iteration steps was exceeded.
It may be useful for debugging to set the number of iterations to 1, 2 or 10 to see how the dynamics of the system work out.

The total runtime of these functions is dependent on the number of partitions and number of samples per partition. 
Reachability is computed once for each partition and then cached for subsequent iterations.

To plot a 2D slice of the shield, see the [`draw`](src/ShieldSynthesis.jl) function.

Get the set of safe actions for a patition by calling `int_to_actions(MyAction, get_value(partition))`

### Shielding a Policy

Apply the shield to a policy using a function similar to the following:

```julia
function apply_shield(shield::Grid, policy::Function, action_type)
    return (state) -> begin
        partition = box(shield, state)
        allowed = int_to_actions(action_type, get_value(partition))
        proposed = policy(state)
        if proposed in allowed || length(allowed) == 0
            return proposed
        else
            return rand(allowed)
        end
    end
end
```