### A Pluto.jl notebook ###
# v0.20.21

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ 888be6dc-1953-11f1-3ba5-7936c812823c
begin
	using Pkg
	Pkg.activate(".", io=devnull)
	using Plots
	using PlutoUI
	using GridShielding
end

# ╔═╡ 97003f0b-c2f9-415d-a5fd-e50bca1ff055
TableOfContents()

# ╔═╡ 2ae317f0-619e-4dfc-8711-7c27f32b35cb
md"""
# Grid World
"""

# ╔═╡ 3f9931c6-92f2-4ad6-a2e7-4acc0d682dee
md"""
## Model
A robot 🤖 can move around along the cardinal directions on a $4 times 4$ grid, and must find an efficient path towards a goal 🏁 while avoiding a harmful tile 💀.  Movement is deterministic except for the ice tiles 🧊 where there is a chance of slipping in a different random direction. 
  The system is defined by the MDP $\cal G = ({1, 2, ... 16}, 14, {←, ↑, →, ↓}, P, R)$. 
  The state-space is laid out in a $4 \times 4$ grid as illustrated in the plot below, with $s_0$ marked by 🤖.
  With the exception of states 10, 11, (🧊) 15 (💀) and 16(🏁), transitions deterministically follow the cardinal direction indicated by the action. If the action would cause the agent to leave the grid, it stays in the same state.
  
  For example, $P(1, →, 2)  = 1$ (0 for any other $(1, →, s)$), $P(2, ↓, 6) = 1$ and $P(5, ←, 5) = 1$.


  
  In states 10 and 11, there is a 0.625 probability of moving in the manner described above, while the remaining probability mass is distributed among the other directions, i.e. $P(11, →, 15) = 0.125$. States 15 and 16 are terminal, which is modelled as $P(15, a, 15) = 1$ and $P(16, a, 16) = 1$ for any $a$. 
"""

# ╔═╡ fce05bac-0370-4eea-b98b-296e9a1dd854
begin
	🧊 = Set([(3, 2), (3, 3)])
	🤖 = (4, 2)
	💀 = (4, 3)
	🏁 = (4, 4)
end;

# ╔═╡ 5b116859-085f-4a41-adc4-4e9cc3a4f477
begin
	function is_terminal(s::Tuple)
		s == 🏁 || s == 💀
	end
	
	function is_terminal(s)
		is_terminal(Tuple(s))
	end
end

# ╔═╡ 3fcbfac1-df4a-4abe-9f69-dcde98d6dccd
let
	plot(xticks=nothing,
		 yticks=nothing,
		 xlim=(0, 4),
		 ylim=(0, 4),
		 yflip=true,
		 aspectratio=:equal,
		 axis=([], false))

	hline!(0:4, width=1, color=:gray, label=nothing)
	vline!(0:4, width=1, color=:gray, label=nothing)
	
	for x in 1:4, y in 1:4
		annotate!(y - 0.80, x - 0.90, text("$x, $y", 10))
	end

	for 🧊′ in 🧊
		x, y = 🧊′
		annotate!(y - 0.50, x - 0.50, text("⁣🧊", 30, "Fira sans"))
	end

	x, y = 🤖
	annotate!(y - 0.50, x - 0.50, text("⁣🤖", 30, "Fira sans"))

	x, y = 💀
	annotate!(y - 0.50, x - 0.50, text("⁣💀", 30, "Fira sans"))

	x, y = 🏁
	annotate!(y - 0.50, x - 0.50, text("⁣🏁", 30, "Fira sans"))

	plot!()
end

# ╔═╡ eadeb59c-eb1e-4a80-8de8-0509f424f41b
@enum A up down left right

# ╔═╡ 9d6523ad-b1b5-4a42-a4df-82803aa154cb
n_actions = length(instances(A))

# ╔═╡ 1af8dcef-22c5-4d7d-9409-81facbdbfdbf
instances(A)

# ╔═╡ 4c53ff9d-7f98-46ed-832f-37f8aa274e37
begin
	# Simulation function
	# State s, action A and random variable r.
	# Call as f(s, a) to sample an appropriate r.
	function step(s, a, r)
		if is_terminal(s)
			return s
		end
	
		# Chance to slip
		if s ∈ 🧊 && r[1] <= 0.5
			# Get random action
			a = A(floor(Int, r[2]*n_actions))
		end
	
		# Apply action
		x, y = s
		if a == up
			x, y = x - 1, y
		elseif a == down
			x, y = x + 1, y
		elseif a == right
			x, y = x, y + 1
		elseif a == left
			x, y = x, y - 1
		else
			error()
		end
	
		# Bump into walls
		x, y = clamp(x, 1, 4), clamp(y, 1, 4)
	
		return (x, y)
	end
	function step(s, a)
		r = [rand(Float64), rand(Float64)]
		step(s, a, r)
	end
end

# ╔═╡ e6899a26-057e-40d3-be70-b6f5acebf2b2
step((4, 2), up)

# ╔═╡ b8cc0908-cba6-4102-a286-f770ce3f9f14
md"""
## Grid
"""

# ╔═╡ 6c38a221-c3b4-4b7b-b34a-1b91304256d4
is_safe(s) = s != 💀

# ╔═╡ a20f4562-cffb-42ef-8589-12661a8cb3e3
is_safe(bounds::Bounds) = is_safe((bounds.lower[1], bounds.lower[2]))

# ╔═╡ c31c953d-0baa-408d-9e00-2470c2ff9941
any_action, no_action = actions_to_int(instances(A)), actions_to_int([])

# ╔═╡ bd0343fc-442d-4e6e-a566-475a63733837
granularity = 1.0

# ╔═╡ 229495b5-e6b4-43ea-a3cb-ab2ce982e088
# Bounds are lower-inclusive, so we do this
outer_bounds = Bounds([1., 1.], [4.001, 4.001])

# ╔═╡ 4b2d8628-ca3f-47b2-80df-8bae7477c70a
begin
	grid = Grid(granularity, outer_bounds)
	initialize!(grid, state -> is_safe(state) ? any_action : no_action)
	grid.array
end

# ╔═╡ 84f641d7-ea0a-4c13-bc4e-9d6f06a3267d
md"""
## Reachability Function
"""

# ╔═╡ 4858adf8-f398-44cf-baba-68a1a5cb6b87
# The state-space is discrete, so only 1 sample per axis. 
# The first sample is always taken at the lower bound
samples_per_axis = [1, 1]

# ╔═╡ d6d38660-4baf-4083-9fb6-fcc6f5a4d46a
# First random variable decides if the player slips on 🧊 (0.0, 1.0)
# Second variable decides the direction of the slip if this happens. (0.0, 0.25, 0.50, 0.75, 1.0)
samples_per_axis_random = [2, 4]

# ╔═╡ 1a97d5dd-7644-4478-9b98-d5c1a1968dc6
randomness_space = Bounds([0., 0.], [1. - eps(), 1. - eps()]) # Don't worry about it.

# ╔═╡ 7f45f6f2-eada-4b90-ae9c-4aa07c0ec4d8
model = SimulationModel(step, randomness_space, samples_per_axis, samples_per_axis_random)

# ╔═╡ 44481fab-8967-443c-892e-c45347d165fa
reachability_function = get_barbaric_reachability_function(model)

# ╔═╡ 24fce82e-db13-4187-8c82-fd7d90129f12
md"""
## Synthesising the Shield
"""

# ╔═╡ f7e512e1-a029-45f1-ae77-bf79c8e1712f
shield, max_steps_reached = make_shield(reachability_function, A, grid)

# ╔═╡ 2e591a23-34a7-414f-b7a6-899427e33a1a
shield.array

# ╔═╡ 785912c7-dd0e-4a1b-a2cb-9ee670ca5758
let
	plot(xticks=nothing,
		 yticks=nothing,
		 xlim=(0.5, 4.5),
		 ylim=(0.5, 4.5),
		 yflip=true,
		 aspectratio=:equal,
		 axis=([], false))

	hline!(0.5:4.5, width=1, color=:gray, label=nothing)
	vline!(0.5:4.5, width=1, color=:gray, label=nothing)
	
	for 🧊′ in 🧊
		x, y = 🧊′
		annotate!(y + 0.05, x - 0.30, text("⁣🧊", 15, "Fira sans"))
	end

	x, y = 🤖
	annotate!(y + 0.05, x - 0.30, text("⁣🤖", 15, "Fira sans"))

	x, y = 💀
	annotate!(y + 0.05, x - 0.30, text("⁣💀", 15, "Fira sans"))

	x, y = 🏁
	annotate!(y + 0.05, x - 0.30, text("⁣🏁", 15, "Fira sans"))
	
	for x in 1:4, y in 1:4
		annotate!(y - 0.30, x - 0.30, text("$x, $y", 10))
	end
	
	for x in 1:4, y in 1:4
		allowed = get_value(box(shield, (x, y)))
		allowed = [a for a in int_to_actions(A, allowed)]
		
		annotate!(y - 0.00, x - 0.0, 
				  up in allowed ? text("↑", :green, 12) : text("⁣🛡️", :red, 12, "sans"))
		
		annotate!(y + 0.00, x + 0.3, 
				  down in allowed ? text("↓", :green, 12) : text("⁣🛡️", :red, 12, "sans"))
		
		annotate!(y - 0.15, x + 0.15, 
				  left in allowed ? text("←", :green, 12) : text("⁣🛡️", :red, 12, "sans"))
		
		annotate!(y + 0.15, x + 0.15, 
				  right in allowed ? text("→", :green, 12) : text("⁣🛡️", :red, 12, "sans"))
	end
	plot!()
end

# ╔═╡ e0dad794-b3ee-4002-97c6-b92174766a3a
md"""
## Shielded Behaviuor

The following function takes a proposed action $a$ and a state $s$, and returns a safe action.
If  the proposed action $a$ is safe for this state $s$ according to the shield, that action $a$ is returned.
Otherwise, a random safe action $a'$ is returned.
"""

# ╔═╡ 79eb6de5-9005-4375-ac51-4eb56597e0cc
function shield_action(shield::Grid, state, action::A)
	partition = box(shield, state)
	allowed = int_to_actions(A, get_value(partition))
	if action in allowed || length(allowed) == 0
		return action
	else
		return rand(allowed)
	end
end

# ╔═╡ 8c0d8a0b-2939-4504-bc58-ac5a62c911d9
shield_action(shield, (4, 2), up)

# ╔═╡ 174bc9be-3722-452b-afbb-d99de7bd0812
md"""
## Try it out! -- Test the shield
Using the power of Pluto Notebooks reactivity, you can play the Grid World example yourself.

Optionally (checkbox below) you can explore the grid-world safely by having the shield override unsafe actions.
"""

# ╔═╡ 374836c2-f08f-4dd9-a1dc-37006f1e27bb
@bind enable_shield CheckBox(default=true)

# ╔═╡ 0a567b81-7414-40c1-aef5-2bc33b133f4c
@bind reset_button CounterButton("Reset")

# ╔═╡ 5d5b188b-b826-477a-b3bd-3d3ac87d0d01
begin
	# This cell is run every time the reset_button is pressed.
	reset_button 
	
	# Reactive variable! Values in this array change as the notebook is updated.
	state = [🤖...]
end;

# ╔═╡ 9015faff-4a09-4e16-8541-e222d2b67464
@bind a Select([instances(A)...])

# ╔═╡ b7ef9f3f-ccb3-40b2-9fe6-92f435a41bd3
a

# ╔═╡ 12b7ed8e-90ae-4884-8469-264a9c53e1a6
begin
	a, enable_shield, reset_button # reactivity
	
	@bind step_button CounterButton("Step")
end

# ╔═╡ 493d6d7a-be9e-4f02-9a88-1af28eb4ea7a
stepped = if step_button > 0 let
	if enable_shield
		a = shield_action(shield, state, a)
	end
	new_state = step(state, a)
	old_state = state
	state[1] = new_state[1]
	state[2] = new_state[2]
	"Taking a step... ($old_state, $a, $state)"
end  end

# ╔═╡ e21e0bf0-8661-45d0-b83b-c20d55096948
reset_button, stepped; state

# ╔═╡ 8ced66b2-a5e8-419a-9a5d-65cf1a16f042
let
	stepped
	plot(xticks=nothing,
		 yticks=nothing,
		 xlim=(0, 4),
		 ylim=(0, 4),
		 yflip=true,
		 aspectratio=:equal,
		 axis=([], false))

	hline!(0:4, width=1, color=:gray, label=nothing)
	vline!(0:4, width=1, color=:gray, label=nothing)
	
	for x in 1:4, y in 1:4
		annotate!(y - 0.80, x - 0.90, text("$x, $y", 10))
	end

	for 🧊′ in 🧊
		x, y = 🧊′
		annotate!(y - 0.50, x - 0.50, text("⁣🧊", 30, "Fira sans"))
	end

	x, y = 💀
	annotate!(y - 0.50, x - 0.50, text("⁣💀", 30, "Fira sans"))

	x, y = 🏁
	annotate!(y - 0.50, x - 0.50, text("⁣🏁", 30, "Fira sans"))

	x, y = state
	annotate!(y - 0.50, x - 0.50, text("⁣🤖", 30, "Fira sans"))

	plot!()
end

# ╔═╡ Cell order:
# ╠═888be6dc-1953-11f1-3ba5-7936c812823c
# ╠═97003f0b-c2f9-415d-a5fd-e50bca1ff055
# ╟─2ae317f0-619e-4dfc-8711-7c27f32b35cb
# ╟─3f9931c6-92f2-4ad6-a2e7-4acc0d682dee
# ╠═5b116859-085f-4a41-adc4-4e9cc3a4f477
# ╠═fce05bac-0370-4eea-b98b-296e9a1dd854
# ╠═3fcbfac1-df4a-4abe-9f69-dcde98d6dccd
# ╠═eadeb59c-eb1e-4a80-8de8-0509f424f41b
# ╠═9d6523ad-b1b5-4a42-a4df-82803aa154cb
# ╠═1af8dcef-22c5-4d7d-9409-81facbdbfdbf
# ╠═4c53ff9d-7f98-46ed-832f-37f8aa274e37
# ╠═e6899a26-057e-40d3-be70-b6f5acebf2b2
# ╟─b8cc0908-cba6-4102-a286-f770ce3f9f14
# ╠═6c38a221-c3b4-4b7b-b34a-1b91304256d4
# ╠═a20f4562-cffb-42ef-8589-12661a8cb3e3
# ╠═c31c953d-0baa-408d-9e00-2470c2ff9941
# ╠═bd0343fc-442d-4e6e-a566-475a63733837
# ╠═229495b5-e6b4-43ea-a3cb-ab2ce982e088
# ╠═4b2d8628-ca3f-47b2-80df-8bae7477c70a
# ╟─84f641d7-ea0a-4c13-bc4e-9d6f06a3267d
# ╠═4858adf8-f398-44cf-baba-68a1a5cb6b87
# ╠═d6d38660-4baf-4083-9fb6-fcc6f5a4d46a
# ╠═1a97d5dd-7644-4478-9b98-d5c1a1968dc6
# ╠═7f45f6f2-eada-4b90-ae9c-4aa07c0ec4d8
# ╠═44481fab-8967-443c-892e-c45347d165fa
# ╟─24fce82e-db13-4187-8c82-fd7d90129f12
# ╠═f7e512e1-a029-45f1-ae77-bf79c8e1712f
# ╠═2e591a23-34a7-414f-b7a6-899427e33a1a
# ╠═785912c7-dd0e-4a1b-a2cb-9ee670ca5758
# ╟─e0dad794-b3ee-4002-97c6-b92174766a3a
# ╠═79eb6de5-9005-4375-ac51-4eb56597e0cc
# ╠═8c0d8a0b-2939-4504-bc58-ac5a62c911d9
# ╟─174bc9be-3722-452b-afbb-d99de7bd0812
# ╠═374836c2-f08f-4dd9-a1dc-37006f1e27bb
# ╠═0a567b81-7414-40c1-aef5-2bc33b133f4c
# ╟─e21e0bf0-8661-45d0-b83b-c20d55096948
# ╠═5d5b188b-b826-477a-b3bd-3d3ac87d0d01
# ╠═9015faff-4a09-4e16-8541-e222d2b67464
# ╠═b7ef9f3f-ccb3-40b2-9fe6-92f435a41bd3
# ╠═12b7ed8e-90ae-4884-8469-264a9c53e1a6
# ╠═493d6d7a-be9e-4f02-9a88-1af28eb4ea7a
# ╟─8ced66b2-a5e8-419a-9a5d-65cf1a16f042
