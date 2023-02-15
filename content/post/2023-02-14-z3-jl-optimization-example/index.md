---
title: Z3.jl Optimization Example
author: Evan Wright
date: '2023-02-14'
slug: z3-jl-optimization-example
categories: []
tags:
  - julia
---

[Z3](https://en.wikipedia.org/wiki/Z3_Theorem_Prover) is a satisfiability modulo
theories (SMT) solver callable from Julia with [Z3.jl](https://github.com/ahumenberger/Z3.jl). 
Documentation is somewhat lacking, so I'd like to share a worked example
of optimizing an integer programming problem with Z3.jl. 

We will solve [Advent of Code 2018 day 23](https://adventofcode.com/2018/day/23), so if you'd like to avoid spoilers, 
stop reading. 
The problem provides a list of nanobots defined by a center point in 3d space and
radius, measured by Manhattan distance. 
For part 2 of the problem, we must find the (integer) point that lies within range of the largest number of nanobots. 
If there are multiple such points, we must find the one closest to the origin (0, 0, 0).


First, we'll define a struct to hold the nanobot data and process the input 
file.[^1]

```julia
using Z3

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
```

Let's think about how we may define the problem as an integer optimization 
that Z3 can understand. 
Consider a potential solution point `(x, y, z)`. 
The point is outside the radius of nanobot `bot` if and only if
`abs(bot.x - x) + abs(bot.y - y) + abs(bot.z - z) > bot.radius`. 
We want to *minimize* the number bots for which that statement is true. 
We can collect the statements in an array, and sum the boolean values (1 = true). 
The resulting sum (call it `noutofrange`) will be our objective to minimize. 

Finally, conditional on minimizing `noutofrange`, we want to choose the 
point closest to the origin, or minimize `abs(x) + abs(y) + abs(z)` (call this value `cost`). 
Z3 uses by default a lexicographic priority of objectives. 
It solves first for the objective that is declared first, so this should be easy. 

Define the Z3 context and necessary variables. 
We'll see why we need `z3zero` and `z3one` in a moment. 

```julia
ctx = Context()
x = int_const(ctx, "x")
y = int_const(ctx, "y")
z = int_const(ctx, "z")
z3zero = int_val(ctx, 0)
z3one = int_val(ctx, 1)
noutofrange = int_const(ctx, "noutofrange")
cost = int_const(ctx, "cost")
```

The array of boolean values (converted to integer 1 or 0) measuring whether the point is within range of each bot
may now be defined as

```julia
botsoutofrange = [ite(abs(b.x - x) + abs(b.y - y) + abs(b.z - z) > b.radius,
                      z3one, z3zero) for b in bots]
```

`ite(a, b, c)` (if then else) is a Z3 method that means

```
if a
    return b
else
    return c
end
```

We need `b` and `c` to be Z3 expressions, hence the use of our previously defined 
`z3one` and `z3zero`. 

Now, we initialize the optimization problem with the "constraints" that
define our objective variables, 

```julia
opt = Optimize(ctx)
add(opt, noutofrange == sum(botsoutofrange))
add(opt, cost == abs(x) + abs(y) + abs(z))
```

and finally optimize each of the objectives in order. 

```julia
minimize(opt, noutofrange)
minimize(opt, cost)
res = check(opt)
```

Confirm that the problem is satisfiable and print the optimal point.
```julia
@assert res == Z3.sat
m = get_model(opt)
for (k, v) in consts(m)
    println("$k = $v")
end
```

For my input, this prints
```
noutofrange = 28
cost = 126233088
z = 38585775
y = 43480550
x = 44166763
```

It takes about a minute to solve on my PC. That may seem slow, but the human
time required to code a faster algorithm is a lot longer than a minute![^2] 
Z3 is one of those tools that isn't often applicable, but when it is, it feels like magic. 

## Full Julia script

```julia
using Z3

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

function main(filename)
    bots = processinput(filename)
    ctx = Context()
    x = int_const(ctx, "x")
    y = int_const(ctx, "y")
    z = int_const(ctx, "z")
    z3zero = int_val(ctx, 0)
    z3one = int_val(ctx, 1)
    noutofrange = int_const(ctx, "noutofrange")
    cost = int_const(ctx, "cost")
    botsoutofrange = [ite(abs(b.x - x) + abs(b.y - y) + abs(b.z - z) > b.radius, z3one, z3zero)
                      for b in bots]
    opt = Optimize(ctx)
    add(opt, noutofrange == sum(botsoutofrange))
    add(opt, cost == abs(x) + abs(y) + abs(z))
    minimize(opt, noutofrange)
    minimize(opt, cost)
    res = check(opt)
    @assert res == Z3.sat
    m = get_model(opt)
    for (k, v) in consts(m)
        println("$k = $v")
    end
    return nothing
end

@time main("input201823.txt")
```

Output:
```
noutofrange = 28
cost = 126233088
z = 38585775
y = 43480550
x = 44166763
 52.030344 seconds (71.38 k allocations: 3.053 MiB, 0.07% compilation time)
```

## Comparison with Python

The script below is the same problem solved with the Python package `z3-solver`. 
I had to manually define `abs` to work with Z3 in Python, but Python didn't require `ite` or
definition of the 0 and 1 Z3 expressions like Julia. 
I also had occasional segfaults in the Julia version, although 
it wasn't reproducible when executing the file in a fresh REPL. 
It may be related to this issue: [https://github.com/ahumenberger/Z3.jl/issues/12](https://github.com/ahumenberger/Z3.jl/issues/12).


```python
import z3
import re
import time

with open('input/input201823.txt', 'r') as f:
    actualinput = f.read()

bots = [list(map(int, re.findall('(\-?\d+)', row))) for row in actualinput.splitlines()]

# https://stackoverflow.com/questions/22547988/how-to-calculate-absolute-value-in-z3-or-z3py
def z3abs(x):
    return z3.If(x >= 0,x,-x)

x = z3.Int('x')
y = z3.Int('y')
z = z3.Int('z')
noutofrange = z3.Int('noutofrange')
cost = z3.Int('cost')

botsoutofrange = [z3abs(b[0]-x) + z3abs(b[1]-y) + z3abs(b[2]-z) > b[3] for b in bots]

opt = z3.Optimize()
opt.add(noutofrange == z3.Sum(botsoutofrange))
opt.add(cost == z3abs(x) + z3abs(y) + z3abs(z))
# Z3 uses by default a lexicographic priority of objectives. It solves first for the objective that is declared first.
lowestoutofrange = opt.minimize(noutofrange)
closesttoorigin = opt.minimize(cost)
print("Checking optimization...")
start_time = time.time()
opt.check()
print(f"Found solution in {time.time() - start_time:.2f}s")
print(opt.model())
```



[^1]: You can use the following example input if you don't want to log in to Advent of Code.  
`pos=<10,12,12>, r=2`  
`pos=<12,14,12>, r=2`  
`pos=<16,12,12>, r=4`  
`pos=<14,14,14>, r=6`  
`pos=<50,50,50>, r=200`  
`pos=<10,10,10>, r=5`  

[^2]: The problem can be reformulated as a mixed-integer linear program, which is
solvable nearly instantly by an optimizer like [HiGHS](https://highs.dev/), but that still 
requires some human effort to think through and implement the reformulation. 
