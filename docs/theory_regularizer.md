# Given:

$$
\frac{\partial^{2}f}{\partial x^{2}} = 0
\\
\frac{\partial^{2}f}{\partial y^{2}} = 0
$$

# Solution:

By inspection, the solution is the bilinear function with
$a,b,c\ \text{and}\ d$ as constants.

$$
f(x,y) = c + ax + by + dxy
$$

We compute the 2nd derivatives of $f(x,y)$ to check that it
really is a solution to the PDE system.

$$
\frac{\partial f}{\partial x} = a + dy
$$

$$
\frac{\partial^{2}f}{\partial x^{2}} = 0 + 0 = 0
$$

$$
\frac{\partial f}{\partial y} = b + dx
$$

$$
\frac{\partial^{2}f}{\partial y^{2}} = 0 + 0 = 0
$$

# Conclusions:

The solution to the regularizing function is the bilinear function in
2d.

# Future Work:

Prove a form of this for n-D dimensions.
