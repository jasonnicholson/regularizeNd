# Given:

``` math
{\frac{\partial^{2}f}{\partial x^{2}} = 0
}{\frac{\partial^{2}f}{\partial y^{2}} = 0\ }
```

# Find:

General solution of the partial differential equation system in 2d.

# Solution:

By inspection, the solution is the bilinear function with
$`a,b,c\ and\ d`$ as constants.

``` math
f(x,y) = c + ax + by + dxy
```

We compute the 2<sup>nd</sup> derivatives of $`f(x,y)`$ to check that it
really is a solution to the PDE system.

``` math
\frac{\partial f}{\partial x} = a + dy
```

``` math
\frac{\partial^{2}f}{\partial x^{2}} = 0 + 0 = 0
```

``` math
\frac{\partial f}{\partial y} = b + dx
```

``` math
\frac{\partial^{2}f}{\partial y^{2}} = 0 + 0 = 0
```

# Conclusions:

The solution to the regularizing function is the bilinear function in
2d.

# Future Work:

Prove a form of this for n-D dimensions.
