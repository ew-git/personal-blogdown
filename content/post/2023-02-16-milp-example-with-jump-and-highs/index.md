---
title: MILP Example with JuMP and HiGHS
author: Evan Wright
date: '2023-02-16'
slug: milp-example-with-jump-and-highs
categories: []
tags:
  - julia
  - jump
  - milp
  - highs
---

In my [previous post](/2023/02/14/z3-jl-optimization-example), I mentioned that the problem ([Advent of Code 2018 day 23](https://adventofcode.com/2018/day/23)) can be reformulated as a mixed-integer linear program (MILP). In this post, we'll walk through a solution using [JuMP.jl](https://github.com/jump-dev/JuMP.jl) and [HiGHS.jl](https://github.com/jump-dev/HiGHS.jl). The formulation is based on [this](https://old.reddit.com/r/adventofcode/comments/a8sqov/help_day_23_part_2_any_provably_correct_fast/ecdnimh/) Reddit comment.

Input parsing is the same as last time. We set up the JuMP problem by defining variables 
x, y, and z as integers and the vector variable `botsinrange` as binary. This time, the value of `botsinrange[i]` is 1 if the point (x, y, z) is in range of bot i, otherwise 0. 

```julia
using JuMP
using HiGHS

struct Nanobot
    x::Int
    y::Int
    z::Int
    radius::Int
end
function processinput(filename)
    puzin = [[parse(Int, m.match) for m in eachmatch(r"(\-?\d+)", line)]
             for line in readlines(filename)]
    bots = [Nanobot(l...) for l in puzin]
    return bots
end
bots = processinput("input201823.txt")

model = Model(HiGHS.Optimizer)
set_silent(model)
@variable(model, x, Int)
@variable(model, y, Int)
@variable(model, z, Int)
@variable(model, botsinrange[1:length(bots)], Bin)
```


Next, define constraints of the form
```julia
abs(b.x - x) + abs(b.y - y) + abs(b.z - z) <= b.radius + (1 - botsinrange[i])*slack
```
where i is the index of bot b. For the moment, assume slack is infinity. Then if we think bot i is out of range (`botsinrange[i] = 0`), the constraint holds (right hand side is Inf). Otherwise, if we think bot i is in range (`botsinrange[i] = 1`), the constraint holds if and only if `abs(b.x - x) + abs(b.y - y) + abs(b.z - z) <= b.radius`, i.e. the bot has to *actually* be in range. We will maximize the sum of `botsinrange`, so the optimizer will try to set `botsinrange[i] = 1` for as many i as possible, and in those cases, it must also ensure the corresponding constraint holds.

So far so good, but there are two minor complications. First, the abs function is non-linear, so we can't have it in the constraint definition. However, note that if -x < c and x < c, then abs(x) < c. If x + y < c and -x + y < c and x - y < c and -x - y < c, then abs(x) + abs(y) < c. A similar argument holds for 3 variables, so we just need to create several linear constraints that imply the constraint defined above.

Second, we can't actually use Inf for the slack for numerical stability reasons; we'll have to use a large finite number. The slack can't be too low because we need the constraint to be relaxed if `botsinrange[i] = 0`. Consider the worst case, where the left hand side of the constraint is as large as possible. This may occur when (x, y, z) is at the "opposite" corner of 3d space from a bot i.  The largest coordinate or radius in our puzzle input is
```julia
maxcoord = maximum(b -> max(abs(b.x), abs(b.y), abs(b.z), b.radius), bots)
```
In the worst case, we are comparing a point like (maxcoord, maxcoord, maxcoord) to (-maxcoord, -maxcoord, -maxcoord), so the distance between those points is 2\*3\*maxcoord. We have additional distance for the bots' sensor radius, so we may use `slack = 2*4*maxcoord`.

Putting it all together, our constraints are
```julia
slack = 2*4*maximum(b -> max(abs(b.x), abs(b.y), abs(b.z), b.radius), bots)
for (i,b) in enumerate(bots)
    for absmult in Iterators.product((-1,1),(-1,1),(-1,1))
        @constraint(model, absmult[1]*(b.x - x) + absmult[2]*(b.y - y) +
                            absmult[3]*(b.z - z) <= b.radius + (1-botsinrange[i])*slack)
    end
end
```

Finally, we can optimize the model.
```julia
@objective(model, Max, sum(botsinrange))
optimize!(model)
println("""x=$(round(Int, value(x))), y=$(round(Int, value(y))), z=$(round(Int, value(z)))
ans=$(round(Int, value(x)) + round(Int, value(y)) + round(Int, value(z)))""")
```

For my input, we find the correct answer, but recall the problem statement asked if there are multiple points with maximum nanobot coverage, then we should choose the point closest to the origin. So, we can add a constraint that the objective function must be at least as high as we just found[^3]
```julia
function coordisinrange(x, y, z, bot::Nanobot)
    return abs(bot.x - x) + abs(bot.y - y) + abs(bot.z - z) <= bot.radius
end
maxbots = count(b -> coordisinrange(round(Int, value(x)),
         round(Int, value(y)), round(Int, value(z)), b), bots)
@constraint(model, maxbots <= sum(botsinrange))
```
and add a penalty term to our objective function to minimize abs(x) + abs(y) + abs(z).[^1] We have the same non-linear problem with abs as before, so we have to use a similar trick. The objective function becomes `sum(botsinrange) - 0.00000001 * (xt + yt + zt)` where the penalty is set by trial and error until the optimizer finds a solution. The coordinates are 8 digit numbers, so the penalty should be similar in scale to 1 unit of the objective---i.e. having one more bot in range.

```julia
@variable(model, xt, Int)
@variable(model, yt, Int)
@variable(model, zt, Int)
@constraint(model, x <= xt); @constraint(model, -x <= xt);
@constraint(model, y <= yt); @constraint(model, -y <= yt);
@constraint(model, z <= zt); @constraint(model, -z <= zt);

@constraint(model, maxbots <= sum(botsinrange))
@objective(model, Max, sum(botsinrange) - 0.00000001 * (xt + yt + zt))
optimize!(model)
println("""x=$(round(Int, value(x))), y=$(round(Int, value(y))), z=$(round(Int, value(z)))
ans=$(round(Int, value(x)) + round(Int, value(y)) + round(Int, value(z)))""")
```

The solution is the same answer as before---which we know is correct thanks to Z3---but I'm curious if any other input needs the tie-breaking rule. 

## Discussion

The MILP solution feels a bit hacky compared to Z3, but it is faster at around 0.3-1.5 seconds without compilation, compared to 50+ seconds for Z3. It took trial and error to get the right slack, and even if the slack is high enough, the solver may provide an incorrect solution.[^2] For my input, slack of 1e11 results in an incorrect solution, while 1e10, 1e12-1e14 are ok. 

Handling the L1 norm (abs) is annoying as well. I tried to use `MathOptInterface.NormOneCone`, 
```julia
for (i,b) in enumerate(bots)
    @constraint(model2,
     [b.radius + (1-botsinrange[i])*Int(1e10); x - [b.x, b.y, b.z]] in MOI.NormOneCone(4))
end
```
but there is a performance issue. With constraints from only 280 bots (the problem has 1000), the solver takes about 4 seconds, but with 290 bots it hangs (or takes longer than I care to wait).

In summary, MILP solvers can solve this problem more quickly than Z3 with a minor reformulation. There may be a better formulation that is less finicky. If you know of one, let me know.


## Full Julia script

```julia
using JuMP
using HiGHS

struct Nanobot
    x::Int
    y::Int
    z::Int
    radius::Int
end

function processinput(filename)
    puzin = [[parse(Int, m.match) for m in eachmatch(r"(\-?\d+)", line)]
             for line in readlines(filename)]
    bots = [Nanobot(l...) for l in puzin]
    return bots
end

function coordisinrange(x, y, z, bot::Nanobot)
    return abs(bot.x - x) + abs(bot.y - y) + abs(bot.z - z) <= bot.radius
end

function main(filename)
    bots = processinput(filename)
    model = Model(HiGHS.Optimizer)
    slack = 2*4*maximum(b -> max(abs(b.x), abs(b.y), abs(b.z), b.radius), bots)
    set_silent(model)
    @variable(model, x, Int)
    @variable(model, y, Int)
    @variable(model, z, Int)
    @variable(model, botsinrange[1:length(bots)], Bin)
    for (i,b) in enumerate(bots)
        for absmult in Iterators.product((-1,1),(-1,1),(-1,1))
            @constraint(model, absmult[1]*(b.x - x) + absmult[2]*(b.y - y) +
                                absmult[3]*(b.z - z) <= b.radius + (1-botsinrange[i])*slack)
        end
    end
    @objective(model, Max, sum(botsinrange))
    optimize!(model)
    println("Step 1 solution:")
    println("""x=$(round(Int, value(x))), y=$(round(Int, value(y))), z=$(round(Int, value(z))),
     ans=$(round(Int, value(x)) + round(Int, value(y)) + round(Int, value(z)))""")

    # Step 2, with lower bound constraint for number of bots in range.
    maxbots = count(b -> coordisinrange(round(Int, value(x)),
         round(Int, value(y)), round(Int, value(z)), b), bots)
    @constraint(model, maxbots <= sum(botsinrange))

    @variable(model, xt, Int)
    @variable(model, yt, Int)
    @variable(model, zt, Int)
    @constraint(model, x <= xt); @constraint(model, -x <= xt);
    @constraint(model, y <= yt); @constraint(model, -y <= yt);
    @constraint(model, z <= zt); @constraint(model, -z <= zt);

    @objective(model, Max, sum(botsinrange) - 0.00000001 * (xt + yt + zt))
    optimize!(model)
    println("Step 2 solution:")
    println("""x=$(round(Int, value(x))), y=$(round(Int, value(y))), z=$(round(Int, value(z)))
     ans=$(round(Int, value(x)) + round(Int, value(y)) + round(Int, value(z)))""")

    return nothing
end

@time main("input201823.txt")
```

Output (second run to avoid compilation time):
```
Step 1 solution:
x=44166763, y=43480550, z=38585775,
ans=126233088
Step 2 solution:
x=44166763, y=43480550, z=38585775
ans=126233088
  1.688667 seconds (590.15 k allocations: 32.233 MiB, 0.86% gc time)
```

[^3]: You may be wondering why I didn't use `round(Int, objective_value(model))`. I found that for some values of `slack`, the `objective_value` is not the value of the objective at the solution (x, y, z). For example, the solution for step one results in an `objective_value` of 969 when the true number of bots in range of (x, y, z) is 972. 969 is still larger than the objective function evaluated at any other point, though. There may be a setting for HiGHS---that I'm unaware of---to resolve this issue.
[^1]: We could do this in the first step as well, but I'm more confident in finding the global `maxbots` without the penalty in the first step, then trying to minimize the L1 norm of the solution.
[^2]: If the slack is too *low*, then the problem is incorrectly specified. In the extreme case where slack is 0, the problem is to find a point within every bot's range, which isn't feasible. However, there shouldn't be an issue---mathematically---with a slack that is too large.

