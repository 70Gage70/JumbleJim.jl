### A Pluto.jl notebook ###
# v0.20.3

using Markdown
using InteractiveUtils

# ╔═╡ 8d67612a-401d-4b94-b41c-4e0e4f7b469c
begin
	using RemoteFiles
	using JSON
	using CSV
	using JLD2
	using Random
	using Permutations
	using DataFrames
	using StatsBase: countmap, sample
	using JuMP, SCIP
	using LinearAlgebra: ⋅
end

# ╔═╡ 7d22e644-7950-4e8d-af52-f35a8595ae2f
md"""
# Front Matter
"""

# ╔═╡ 0f062b77-2c78-4340-b59f-1a1a9f5c6523
LETTERS = join([collect('A':'Z'); collect('a':'z')])

# ╔═╡ 9fcb922f-e19c-479b-af87-d035b732baca
md"""
# Download Data
"""

# ╔═╡ 35a3f80c-03af-422f-ad0a-4c6d2b02132d
md"""
## Jokes
"""

# ╔═╡ 7317f5fa-0e22-4074-a7aa-b356cf69c001
begin
	Random.seed!(1234)
	
	@RemoteFile(
	    JOKES_RAW1, 
	    "https://raw.githubusercontent.com/15Dkatz/official_joke_api/refs/heads/master/jokes/index.json",
	    updates=:never)

	download(JOKES_RAW1)
	jokes_raw1 = path(JOKES_RAW1) |> x -> JSON.parsefile(x, dicttype=Dict, inttype=Int64, use_mmap=true)
	
	@RemoteFile(
	    JOKES_RAW2, 
	    "https://raw.githubusercontent.com/carllapierre/dad-jokes/refs/heads/main/dadjokes.json",
	    updates=:never)
	
	
	download(JOKES_RAW2)
	jokes_raw2 = path(JOKES_RAW2) |> x -> JSON.parsefile(x, dicttype=Dict, inttype=Int64, use_mmap=true)
	jokes_raw2 = [Dict("punchline" => d["punchline"], "setup" => d["hook"], "type" =>"general") for d in jokes_raw2]

	jokes_raw = [jokes_raw1 ; jokes_raw2] |> shuffle |> DataFrame
end

# ╔═╡ 5c574d13-8cd1-4c29-a32c-58fcc529b5f5
md"""
## Words
"""

# ╔═╡ 7e6f442b-a0b6-4950-a51d-5a26c299497d
begin
	@RemoteFile(
	    PROFANITY_RAW, 
	    "https://raw.githubusercontent.com/zacanger/profane-words/refs/heads/master/words.json",
	    updates=:never)

	download(PROFANITY_RAW)
	profanity_raw = path(PROFANITY_RAW) |> x -> JSON.parsefile(x, dicttype=Dict, inttype=Int64, use_mmap=true)

	@RemoteFile(
	    WORDS_RAW, 
	    "https://raw.githubusercontent.com/david47k/top-english-wordlists/master/top_english_words_lower_10000.txt",
	    updates=:never)

	download(WORDS_RAW)
	words_raw = path(WORDS_RAW) |> x -> CSV.read(x, DataFrame, header = 0).Column1 |> collect
	
	nothing
end

# ╔═╡ f9b28849-1262-42b5-8042-c8852d60b04d
md"""
# Filter Dataset
"""

# ╔═╡ 684eb6a8-40ce-41e8-a782-a7f752087718
md"""
## Jokes
"""

# ╔═╡ cb84f4c7-2dc5-4f25-8fd6-052019f82eb2
MIN_LENGTH_JOKE, MAX_LENGTH_JOKE = 8, 15;

# ╔═╡ 10a0bf59-7d5d-49e3-86c7-d9ae086ba460
BADS = [4, 17, 138, 141, 202];

# ╔═╡ a0412db8-9a74-4745-a5d6-498575e7249e
_length(word) = length(findall(x -> occursin(x, LETTERS), word))

# ╔═╡ 2a89cdfb-24ce-4e9e-b3c3-ca094b597e21
_jokes_filtered = jokes_raw[findall(x -> MIN_LENGTH_JOKE < _length(x) < MAX_LENGTH_JOKE, jokes_raw.punchline), [:setup, :punchline]] 

# ╔═╡ aea601a1-f030-407b-84e5-d657618edf47
# jokes whose punchlines have too many of the same letter
jokes_filtered = _jokes_filtered[findall(x -> x < 6, _jokes_filtered[:,:punchline] .|> countmap .|> values .|> maximum), :]

# ╔═╡ 81a8ab29-87c2-496c-acb7-4acac9d5a00d
md"""
## Words
"""

# ╔═╡ ded83cb7-d13d-452b-a2a9-5fb2281805ab
MIN_LENGTH_WORD, MAX_LENGTH_WORD = 5, 7;

# ╔═╡ 5db5225a-7dd4-40d5-8829-fc6e48ec9df6
begin
	words_filtered = filter(
		x -> (MIN_LENGTH_WORD <= length(x) <= MAX_LENGTH_WORD) && 
		issubset(collect(Set(x)), [collect('A':'Z'); collect('a':'z')]) &&
		!(x in profanity_raw), 
		words_raw) .|> String

	cms = countmap.(words_filtered)
	words_filtered = [words_filtered[i] for i = 1:length(words_filtered) if !(cms[i] in cms[union(1:i-1, i+1:end)])] # filter anagram
end

# ╔═╡ 9a6cb399-1233-4cba-a93b-242d40a098bc
length(words_filtered)

# ╔═╡ d6e1bbe3-fc5f-4772-9ae2-71ff6069699e
md"""
# Frequency Map
"""

# ╔═╡ 82c12cd1-1bc2-4268-aca0-f0ec4a05b1ea
"""
	letter_frequencies(s::String)
"""
function letter_frequencies(s::String)
    # Initialize a vector of zeros for each letter of the alphabet
    frequencies = zeros(Int, 26)
    
    # Iterate through the characters of the string
    for c in lowercase(s)
        if 'a' <= c <= 'z'  # Check if the character is a letter
            frequencies[Int(c) - Int('a') + 1] += 1
        end
    end
    
    return frequencies
end

# ╔═╡ 51d73e47-9262-4d44-9edf-a4812e320427
WORDS_FREQS = letter_frequencies.(words_filtered) |> x -> stack(x, dims = 1)

# ╔═╡ 35d07663-7dd1-4f4e-99e0-6d3486b5dccb
JOKES_FREQS = letter_frequencies.(jokes_filtered.punchline) |> x -> stack(x, dims = 1)

# ╔═╡ c217192d-3459-479d-91f5-b6bedd0fc9db
md"""
# Optimization
"""

# ╔═╡ 334bee6e-e5f3-413f-b7c1-4d0b4551a299
md"""
General plan:

- For each row in `jokes_freqs`
- Shuffle `words_freqs`
- Loop through `words_freqs` and randomly select three nonzero columns
- Formulate an optimzation problemw with `size(words_freqs, 1)` binary decision variables `x[i]`.
  - `4 <= sum(x[i]) <= 6`
  - `sum(words_freqs[x, :]) .>= jokes_freqs`
- if impossible, try shuffling again
"""

# ╔═╡ c3cc502b-c263-44b6-9ff6-fa2a04eb3da5
"""
	take_n(row, n) -> row

	take_n(mat, n) -> mat
"""
function take_n(row::Vector{<:Integer}, n::Integer)
	idx = findall(x -> x != 0, row) |> x -> sample(x, n, replace = false)
	res = zeros(Int64, length(row))
	for i in idx
		res[i] = 1
	end

	return res
end

# ╔═╡ d817da69-e1c7-457b-af5a-6c1bf0aadf28
function take_n(mat::Matrix{<:Integer}, n::Integer)
	res = similar(mat)
	for i = 1:size(mat, 1)
		res[i,:] .= take_n(mat[i,:], n)
	end

	return res
end

# ╔═╡ 78105619-6434-42c6-8b3b-c6033be64ff2
"""
	sol2circles(sol1, sol2)
"""
function sol2circles(sol1, sol2)
	
	words = words_filtered[sol1]
	circles = Vector{Int64}[]

	for i = 1:length(words)
		word2num = words[i] |> w -> [Int64(c) - Int64('a') + 1 for c in w]
		letterpos = findall(x -> x == 1, sol2[i,:])
		circle = falses(length(words[i]))
		for i = 1:length(letterpos)
			circle[findfirst(x -> x == letterpos[i], word2num)] = true
		end
		push!(circles, circle)
	end

	return circles
end

# ╔═╡ bd936471-e8ed-4e57-b586-f10326019c13
"""
	jumble_solve(target_freqs; excludes = Int64[], hints_bounds = (4, 6), max_letters_per_word = 3)
"""
function jumble_solve(target_freqs; 
	excludes::Vector{<:Integer} = Int64[], 
	hints_bounds::Tuple{Integer, Integer} = (4, 6), 
	max_letters_per_word::Integer = 3)
	
	WORDS = take_n(WORDS_FREQS, max_letters_per_word)
	N_WORDS = size(WORDS, 1) # number of words to choose from
	N_HINTS_MIN, N_HINTS_MAX = hints_bounds

	### find which words to use
	model1 = Model(SCIP.Optimizer)
	set_silent(model1)
	@variable(model1, x[1:N_WORDS], Bin)
	@constraint(model1, N_HINTS_MIN <= sum(x) <= N_HINTS_MAX)
	@constraint(model1, sum(x[i]*WORDS[i, :] for i = 1:N_WORDS) .>= target_freqs)
	@constraint(model1, x[excludes] .<= 0)
	
	optimize!(model1)

	WORD_SOL1 = findall(x -> x == 1, value.(x)) 
	_WORD_SOL1 = WORD_SOL1 |> x -> WORDS[x, :]

	### get the exact letters
	N2 = sum(value.(x)) |> Int64
	model2 = Model(SCIP.Optimizer)
	set_silent(model2)
	@variable(model2, y[1:N2, 1:26], Bin)
	@constraint(model2, [y[:,i] ⋅ _WORD_SOL1[:, i] for i = 1:26] .== target_freqs)
	@constraint(model2, sum(y) == sum(target_freqs))
	@constraint(model2, sum(y, dims = 2) .>= 1)

	optimize!(model2)

	WORD_SOL2 = Int64.(value.(y))
	

	return (WORD_SOL1, words_filtered[WORD_SOL1], sol2circles(WORD_SOL1, WORD_SOL2))
end

# ╔═╡ 61df717b-f7c8-4c24-bb4f-1e0c7f6b9508
md"""
## Main Loop
"""

# ╔═╡ 493388eb-fe8f-49ea-8af0-18ff48bd5202
let
	Random.seed!(1234)
	
	global jumbles = Vector{Dict}()
	excludes = Vector{Int64}()

	for i = 1:size(JOKES_FREQS, 1)
		@info "Joke $(i)"
		@info "Fraction done = $(i/size(JOKES_FREQS, 1))"

		s, ws, cs = (nothing, nothing, nothing)
		try
			s, ws, cs = jumble_solve(JOKES_FREQS[i,:], excludes = excludes)
		catch
			@info "EXCLUDE BRANCH"
			excludes = Vector{Int64}()
			s, ws, cs = jumble_solve(JOKES_FREQS[i,:], excludes = excludes)
		end

		@info length(excludes)
		
		shuff = [DerangeGen(length(ws[i])) |> collect |> p -> filter(x -> length(cycles(x)) >= 2, p) |> rand |> x -> x.data for i = 1:length(ws)]
		
		d = Dict(
			"setup" => jokes_filtered[i,:setup], 
			"punchline" => jokes_filtered[i,:punchline],
			"words" => ws,
			"circles" => cs,
			"words_jumbled" => [join(collect(ws[i])[shuff[i]]) for i = 1:length(ws)],
			# "circles_jumbled" => [cs[i][shuff[i]] for i = 1:length(ws)],
		)
		push!(jumbles, d)
		append!(excludes, s)

		@info ""
	end

	jumbles
end

# ╔═╡ 7d62da61-ab36-4904-9b94-07e32648e597
md"""
# Writing
"""

# ╔═╡ f410ee4a-51ab-4571-b926-62d0ba5cfcec
let
	jb = jumbles |> DataFrame
	jb = jb[:,[:setup, :punchline, :words, :circles, :words_jumbled]]
	CSV.write("jumbles.csv", jb)
	jldsave("jumbles.jld2", jumble = jb)
	jb
end

# ╔═╡ 4eb8557f-abd0-49eb-aac8-f27073479030
[j["words"] for j in jumbles] |> x -> vcat(x...) |> countmap |> x -> [value for (key, value) in x] |> x -> sort(x, rev = true)

# ╔═╡ 863b2898-d4ce-4892-9eb0-44f53ebff8b2
let
	outfile_qs = "jumbles_qs.txt"
	outfile_sols = "jumbles_sols.txt"
	
	rm(outfile_qs, force = true)
	rm(outfile_sols, force = true)
	io_qs = open(outfile_qs, "w")
	io_sols = open(outfile_sols, "w")

	for i = 1:length(jumbles)
		### QUESTIONS
		write(io_qs, "---------------\n")
		write(io_qs, "- JUMBLE $(i) -\n")
		write(io_qs, "---------------\n\n")

		jum = jumbles[i]
		n_words = length(jum["words"])
		write(io_qs, "$(jum["setup"])\n\n")

		punchline = map(x -> x in LETTERS ? " _ " : x == ' ' ? "   " : x, collect(jum["punchline"]))
		punchline = join(punchline)[2:end]
		write(io_qs, "$(punchline)\n\n")

		### SOLUTIONS
		write(io_sols, "---------------\n")
		write(io_sols, "- JUMBLE $(i) -\n")
		write(io_sols, "---------------\n\n")

		write(io_sols, "$(jum["setup"])\n\n")
		write(io_sols, "$(jum["punchline"])\n\n")
		
		for w = 1:length(jum["words"])
			### QUESTIONS
			word = uppercase(jum["words_jumbled"][w])
			word = [jum["circles"][w][j] == 1 ? " [$(word[j])] " : " $(word[j]) " for j in 1:length(word)] |> join |> x -> x[2:end]
			write(io_qs, "$(word)\n")

			### SOLUTIONS
			word = uppercase(jum["words"][w])
			word = [jum["circles"][w][j] == 1 ? " [$(word[j])] " : " $(word[j]) " for j in 1:length(word)] |> join |> x -> x[2:end]
			write(io_sols, "$(word)\n")
		end

		write(io_qs, "\n")
		write(io_sols, "\n")
	end
	
	close(io_qs)
	close(io_sols)

	nothing
end

# ╔═╡ 66b0c2a8-af87-11ef-0595-170fc4944fcb
md"""
# Utilities
"""

# ╔═╡ a190f1bf-7b00-48fc-8836-4295e3655447
begin
	@info "Setting notebook width."
	html"""
	<style>
		main {
			margin: 0 auto;
			max-width: 2000px;
	    	padding-left: 5%;
	    	padding-right: 5%;
		}
	</style>
	"""
end

# ╔═╡ 05046a3a-eae6-419d-8b85-f33d0aa9b484
HTML("""
<!-- the wrapper span -->
<div>
	<button id="myrestart" href="#">Restart</button>
	
	<script>
		const div = currentScript.parentElement
		const button = div.querySelector("button#myrestart")
		const cell= div.closest('pluto-cell')
		console.log(button);
		button.onclick = function() { restart_nb() };
		function restart_nb() {
			console.log("Restarting Notebook");
		        cell._internal_pluto_actions.send(                    
		            "restart_process",
                            {},
                            {
                                notebook_id: editor_state.notebook.notebook_id,
                            }
                        )
		};
	</script>
</div>
""")

# ╔═╡ 6b01dd29-c868-4d7c-b3af-0f4c914151ef
# let
# 	N_WORDS = size(WORDS_TEST, 1) # number of words to choose from
# 	WORDS_EXCLUDE = [2, 4] # exlude words in these rows
# 	N_HINTS_MIN, N_HINTS_MAX = 4, 6

# 	### find which words to use
# 	model1 = Model(SCIP.Optimizer)
# 	set_silent(model1)
# 	@variable(model1, x[1:N_WORDS], Bin)
# 	@constraint(model1, N_HINTS_MIN <= sum(x) <= N_HINTS_MAX)
# 	@constraint(model1, sum(x[i]*WORDS_TEST[i, :] for i = 1:N_WORDS) .>= TARGET_TEST)
# 	@constraint(model1, x[WORDS_EXCLUDE] .<= 0)
	
# 	optimize!(model1)

# 	global WORD_SOL1 = findall(x -> x == 1, value.(x))
# 	_WORD_SOL1 = WORD_SOL1 |> x -> WORDS_TEST[x, :]

# 	global WORD_SOL = findall(x -> x == 1, value.(x))

# 	### get the exact letters
# 	N2 = sum(value.(x)) |> Int64
# 	model2 = Model(SCIP.Optimizer)
# 	set_silent(model2)
# 	@variable(model2, y[1:N2, 1:26], Bin)
# 	@constraint(model2, [y[:,i] ⋅ _WORD_SOL1[:, i] for i = 1:26] .== TARGET_TEST)
# 	@constraint(model2, sum(y) == sum(TARGET_TEST))
# 	@constraint(model2, sum(y, dims = 2) .>= 1)

# 	optimize!(model2)

# 	global WORD_SOL2 = Int64.(value.(y))
# 	nothing
# end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
JLD2 = "033835bb-8acc-5ee8-8aae-3f567f8a3819"
JSON = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
JuMP = "4076af6c-e467-56ae-b986-b466b2749572"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
Permutations = "2ae35dd2-176d-5d53-8349-f30d82d94d4f"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
RemoteFiles = "cbe49d4c-5af1-5b60-bb70-0a60aa018e1b"
SCIP = "82193955-e24f-5292-bf16-6f2c5261a85f"
StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"

[compat]
CSV = "~0.10.15"
DataFrames = "~1.7.0"
JLD2 = "~0.5.10"
JSON = "~0.21.4"
JuMP = "~1.23.5"
Permutations = "~0.4.22"
RemoteFiles = "~0.5.0"
SCIP = "~0.12.0"
StatsBase = "~0.34.3"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.11.2"
manifest_format = "2.0"
project_hash = "42c5eac80866f7dc26136580cd6f3850cffe7786"

[[deps.ASL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6252039f98492252f9e47c312c8ffda0e3b9e78d"
uuid = "ae81ac8f-d209-56e5-92de-9978fef736f9"
version = "0.1.3+0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "f1dff6729bc61f4d49e140da1af55dcd1ac97b2f"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.5.0"

[[deps.BitFlags]]
git-tree-sha1 = "0691e34b3bb8be9307330f88d1a3c3f25466c24d"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.9"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "8873e196c2eb87962a2048b3b8e08946535864a1"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+2"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "deddd8725e5e1cc49ee205a1964256043720a6c3"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.15"

[[deps.CodecBzip2]]
deps = ["Bzip2_jll", "TranscodingStreams"]
git-tree-sha1 = "e7c529cc31bb85b97631b922fa2e6baf246f5905"
uuid = "523fee87-0ab8-5b00-afb7-3ecf72e48cfd"
version = "0.8.4"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "bce6804e5e6044c6daab27bb533d1295e4a2e759"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.6"

[[deps.Combinatorics]]
git-tree-sha1 = "08c8b6831dc00bfea825826be0bc8336fc369860"
uuid = "861a8166-3701-5b0c-9a16-15d98fcdc6aa"
version = "1.0.2"

[[deps.CommonSubexpressions]]
deps = ["MacroTools"]
git-tree-sha1 = "cda2cfaebb4be89c9084adaca7dd7333369715c5"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.1"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "8ae8d32e09f0dcf42a36b90d4e17f5dd2e4c4215"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.16.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "ea32b83ca4fefa1768dc84e504cc0a94fb1ab8d1"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.4.2"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "DataStructures", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrecompileTools", "PrettyTables", "Printf", "Random", "Reexport", "SentinelArrays", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "fb61b4812c49343d7ef0b533ba982c46021938a6"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.7.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "1d0a14036acb104d9e89698bd408f63ab58cdc82"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.20"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "23163d55f885173722d1e4cf0f6110cdbaf7e272"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.15.1"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.ExceptionUnwrapping]]
deps = ["Test"]
git-tree-sha1 = "d36f682e590a83d63d1c7dbd287573764682d12a"
uuid = "460bff9d-24e4-43bc-9d9f-a8973cb893f4"
version = "0.1.11"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "2dd20384bf8c6d411b5c7370865b1e9b26cb2ea3"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.16.6"
weakdeps = ["HTTP"]

    [deps.FileIO.extensions]
    HTTPExt = "HTTP"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates"]
git-tree-sha1 = "7878ff7172a8e6beedd1dea14bd27c3c6340d361"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.22"
weakdeps = ["Mmap", "Test"]

    [deps.FilePathsBase.extensions]
    FilePathsBaseMmapExt = "Mmap"
    FilePathsBaseTestExt = "Test"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "a2df1b776752e3f344e5116c06d75a10436ab853"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.38"

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

    [deps.ForwardDiff.weakdeps]
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"
version = "1.11.0"

[[deps.GMP_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "781609d7-10c4-51f6-84f2-b8444358ff6d"
version = "6.3.0+0"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "ConcurrentUtilities", "Dates", "ExceptionUnwrapping", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "PrecompileTools", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "627fcacdb7cb51dc67f557e1598cdffe4dda386d"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.10.14"

[[deps.Hwloc_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "50aedf345a709ab75872f80a2779568dc0bb461b"
uuid = "e33a78d0-f292-5ffc-b300-72abe9b543c8"
version = "2.11.2+1"

[[deps.InlineStrings]]
git-tree-sha1 = "45521d31238e87ee9f9732561bfee12d4eebd52d"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.2"

    [deps.InlineStrings.extensions]
    ArrowTypesExt = "ArrowTypes"
    ParsersExt = "Parsers"

    [deps.InlineStrings.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
    Parsers = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.InvertedIndices]]
git-tree-sha1 = "6da3c4316095de0f5ee2ebd875df8721e7e0bdbe"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.1"

[[deps.Ipopt_jll]]
deps = ["ASL_jll", "Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "MUMPS_seq_jll", "SPRAL_jll", "libblastrampoline_jll"]
git-tree-sha1 = "546c40fd3718c65d48296dd6cec98af9904e3ca4"
uuid = "9cc047cb-c261-5740-88fc-0cf96f7bdcc7"
version = "300.1400.1400+0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "630b497eafcc20001bba38a4651b327dcfc491d2"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.2"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLD2]]
deps = ["FileIO", "MacroTools", "Mmap", "OrderedCollections", "PrecompileTools", "Requires", "TranscodingStreams"]
git-tree-sha1 = "f1a1c1037af2a4541ea186b26b0c0e7eeaad232b"
uuid = "033835bb-8acc-5ee8-8aae-3f567f8a3819"
version = "0.5.10"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "be3dc50a92e5a386872a493a10050136d4703f9b"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.6.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JuMP]]
deps = ["LinearAlgebra", "MacroTools", "MathOptInterface", "MutableArithmetics", "OrderedCollections", "PrecompileTools", "Printf", "SparseArrays"]
git-tree-sha1 = "866dd0bf0474f0d5527c2765c71889762ba90a27"
uuid = "4076af6c-e467-56ae-b986-b466b2749572"
version = "1.23.5"

    [deps.JuMP.extensions]
    JuMPDimensionalDataExt = "DimensionalData"

    [deps.JuMP.weakdeps]
    DimensionalData = "0703355e-b756-11e9-17c0-8b28908087d0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "dda21b8cbd6a6c40d9d02a73230f9d70fed6918c"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.6.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"
version = "1.11.0"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.7.2+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.11.0"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "13ca9e2586b89836fd20cccf56e57e2b9ae7f38f"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.29"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "f02b56007b064fbfddb4c9cd60161b6dd0f40df3"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.1.0"

[[deps.METIS_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "1c20a46719c0dc4ec4e7021ca38f53e1ec9268d9"
uuid = "d00139f3-1899-568f-a2f0-47f597d42d70"
version = "5.1.2+1"

[[deps.MUMPS_seq_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "METIS_jll", "libblastrampoline_jll"]
git-tree-sha1 = "840b83c65b27e308095c139a457373850b2f5977"
uuid = "d7ed1dd3-d0ae-5e8e-bfb4-87a502085b8d"
version = "500.600.201+0"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "2fa9ee3e63fd3a4f7a9a4f4744a52f4856de82df"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.13"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MathOptInterface]]
deps = ["BenchmarkTools", "CodecBzip2", "CodecZlib", "DataStructures", "ForwardDiff", "JSON", "LinearAlgebra", "MutableArithmetics", "NaNMath", "OrderedCollections", "PrecompileTools", "Printf", "SparseArrays", "SpecialFunctions", "Test", "Unicode"]
git-tree-sha1 = "e065ca5234f53fd6f920efaee4940627ad991fb4"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "1.34.0"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "NetworkOptions", "Random", "Sockets"]
git-tree-sha1 = "c067a280ddc25f196b5e7df3877c6b226d390aaf"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.9"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.6+0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "ec4f7fbeab05d7747bdf98eb74d130a2a2ed298d"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.12.12"

[[deps.MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "a2710df6b0931f987530f59427441b21245d8f5e"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "1.6.0"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "0877504529a3e5c3343c6f8b4c0381e57e4387e4"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.2"

[[deps.Ncurses_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "3690e6c58c16ba676bcc9b5654762fe8a05db1c7"
uuid = "68e3532b-a499-55ff-9963-d1c0c0748b3a"
version = "6.5.0+1"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS32_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "dd806c813429ff09878ea3eeb317818f3ca02871"
uuid = "656ef2d0-ae68-5445-9ca0-591084a874a2"
version = "0.3.28+3"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.27+1"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+2"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "38cb508d080d21dc1128f7fb04f20387ed4c0af4"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.4.3"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7493f61f55a6cce7325f197443aa80d32554ba10"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.0.15+1"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "12f1439c4f986bb868acda6ea33ebc78e19b95ad"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.7.0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "8489905bcdbcfac64d1daa51ca07c0d8f0283821"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.1"

[[deps.Permutations]]
deps = ["Combinatorics", "LinearAlgebra", "Random"]
git-tree-sha1 = "f92b0a7b722b1ecfd5c0d77a7eda24b4eea5c56a"
uuid = "2ae35dd2-176d-5d53-8349-f30d82d94d4f"
version = "0.4.22"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.11.0"

    [deps.Pkg.extensions]
    REPLExt = "REPL"

    [deps.Pkg.weakdeps]
    REPL = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "9306f6085165d270f7e3db02af26a400d580f5c6"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.3"

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "PrecompileTools", "Printf", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "1101cd475833706e4d0e7b122218257178f48f34"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.4.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.Profile]]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.Readline_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ncurses_jll"]
git-tree-sha1 = "69684dc9c2c69f7c515097841991362cca0739ea"
uuid = "05236dd9-4125-5232-aa7c-9ec0c9b2c25a"
version = "8.2.1+1"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RemoteFiles]]
deps = ["Dates", "FileIO", "HTTP"]
git-tree-sha1 = "9a0241c411af313068188e89ebf322cb49eedf52"
uuid = "cbe49d4c-5af1-5b60-bb70-0a60aa018e1b"
version = "0.5.0"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.SCIP]]
deps = ["Libdl", "LinearAlgebra", "MathOptInterface", "OpenBLAS32_jll", "SCIP_PaPILO_jll", "SCIP_jll"]
git-tree-sha1 = "11f634d8a4ccec9e77dc7bef702608e18eaacd34"
uuid = "82193955-e24f-5292-bf16-6f2c5261a85f"
version = "0.12.0"

[[deps.SCIP_PaPILO_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "GMP_jll", "Ipopt_jll", "JLLWrappers", "Libdl", "OpenBLAS32_jll", "Readline_jll", "Zlib_jll", "bliss_jll", "boost_jll", "oneTBB_jll"]
git-tree-sha1 = "ec8a8b625a481f3b54dc47a15a3e2ec36d14a533"
uuid = "fc9abe76-a5e6-5fed-b0b7-a12f309cf031"
version = "900.0.0+0"

[[deps.SCIP_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "GMP_jll", "Ipopt_jll", "JLLWrappers", "Libdl", "Readline_jll", "Zlib_jll", "boost_jll"]
git-tree-sha1 = "2d9c6386b885d181208a0b3863087361c1bfa136"
uuid = "e5ac4fe4-a920-5659-9bf8-f9f73e9e79ce"
version = "900.200.0+0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SPRAL_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Hwloc_jll", "JLLWrappers", "Libdl", "METIS_jll", "libblastrampoline_jll"]
git-tree-sha1 = "34b9dacd687cace8aa4d550e3e9bb8615f1a61e9"
uuid = "319450e9-13b8-58e8-aa9f-8fd1420848ab"
version = "2024.1.18+0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "712fb0231ee6f9120e005ccd56297abbc053e7e0"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.8"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "f305871d2f381d21527c770d4788c06c097c9bc1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.2.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "66e0a8e672a0bdfca2c3f5937efb8538b9ddc085"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.11.0"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "64cca0c26b4f31ba18f13f6c12af7c85f478cfde"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.5.0"

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

    [deps.SpecialFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"

[[deps.StaticArraysCore]]
git-tree-sha1 = "192954ef1208c7019899fbf8049e717f92959682"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.3"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"
weakdeps = ["SparseArrays"]

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1ff449ad350c9c4cbc756624d6f8a8c3ef56d3ed"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.7.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "5cf7606d6cef84b543b483848d4ae08ad9832b21"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.3"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "a6b1675a536c5ad1a60e5a5153e1fee12eb146e3"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.4.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.7.0+0"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "598cd7c1f68d1e205689b1c2fe65a9f85846f297"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.12.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

[[deps.URIs]]
git-tree-sha1 = "67db6cc7b3821e19ebe75791a9dd19c9b1188f2b"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.WorkerUtilities]]
git-tree-sha1 = "cd1659ba0d57b71a464a29e64dbc67cfe83d54e7"
uuid = "76eceee3-57b5-4d4a-8e66-0e911cebbf60"
version = "1.6.1"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.bliss_jll]]
deps = ["Artifacts", "GMP_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f8b75e896a326a162a4f6e998990521d8302c810"
uuid = "508c9074-7a14-5c94-9582-3d4bc1871065"
version = "0.77.0+1"

[[deps.boost_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "d9484c66c733c1c84f1d4cfef538d3c7b9d32199"
uuid = "28df3c45-c428-5900-9ff8-a3135698ca75"
version = "1.79.0+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.11.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.59.0+0"

[[deps.oneTBB_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7d0ea0f4895ef2f5cb83645fa689e52cb55cf493"
uuid = "1317d2d5-d96f-522e-a858-c73665f53c3e"
version = "2021.12.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"
"""

# ╔═╡ Cell order:
# ╟─7d22e644-7950-4e8d-af52-f35a8595ae2f
# ╠═8d67612a-401d-4b94-b41c-4e0e4f7b469c
# ╠═0f062b77-2c78-4340-b59f-1a1a9f5c6523
# ╟─9fcb922f-e19c-479b-af87-d035b732baca
# ╟─35a3f80c-03af-422f-ad0a-4c6d2b02132d
# ╠═7317f5fa-0e22-4074-a7aa-b356cf69c001
# ╟─5c574d13-8cd1-4c29-a32c-58fcc529b5f5
# ╠═7e6f442b-a0b6-4950-a51d-5a26c299497d
# ╟─f9b28849-1262-42b5-8042-c8852d60b04d
# ╟─684eb6a8-40ce-41e8-a782-a7f752087718
# ╠═cb84f4c7-2dc5-4f25-8fd6-052019f82eb2
# ╠═10a0bf59-7d5d-49e3-86c7-d9ae086ba460
# ╠═a0412db8-9a74-4745-a5d6-498575e7249e
# ╠═2a89cdfb-24ce-4e9e-b3c3-ca094b597e21
# ╠═aea601a1-f030-407b-84e5-d657618edf47
# ╟─81a8ab29-87c2-496c-acb7-4acac9d5a00d
# ╠═ded83cb7-d13d-452b-a2a9-5fb2281805ab
# ╠═5db5225a-7dd4-40d5-8829-fc6e48ec9df6
# ╠═9a6cb399-1233-4cba-a93b-242d40a098bc
# ╟─d6e1bbe3-fc5f-4772-9ae2-71ff6069699e
# ╟─82c12cd1-1bc2-4268-aca0-f0ec4a05b1ea
# ╠═51d73e47-9262-4d44-9edf-a4812e320427
# ╠═35d07663-7dd1-4f4e-99e0-6d3486b5dccb
# ╟─c217192d-3459-479d-91f5-b6bedd0fc9db
# ╟─334bee6e-e5f3-413f-b7c1-4d0b4551a299
# ╟─c3cc502b-c263-44b6-9ff6-fa2a04eb3da5
# ╟─d817da69-e1c7-457b-af5a-6c1bf0aadf28
# ╟─78105619-6434-42c6-8b3b-c6033be64ff2
# ╟─bd936471-e8ed-4e57-b586-f10326019c13
# ╟─61df717b-f7c8-4c24-bb4f-1e0c7f6b9508
# ╠═493388eb-fe8f-49ea-8af0-18ff48bd5202
# ╟─7d62da61-ab36-4904-9b94-07e32648e597
# ╠═f410ee4a-51ab-4571-b926-62d0ba5cfcec
# ╠═4eb8557f-abd0-49eb-aac8-f27073479030
# ╠═863b2898-d4ce-4892-9eb0-44f53ebff8b2
# ╟─66b0c2a8-af87-11ef-0595-170fc4944fcb
# ╟─a190f1bf-7b00-48fc-8836-4295e3655447
# ╟─05046a3a-eae6-419d-8b85-f33d0aa9b484
# ╠═6b01dd29-c868-4d7c-b3af-0f4c914151ef
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
