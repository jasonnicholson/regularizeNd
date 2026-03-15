# Theory of the Regularizer

The default regularizer in regularizeNd penalizes second derivative along each axis. The idealized zero-penalty condition is

$$
\frac{\partial^{2}f}{\partial x_k^{2}} = 0, \qquad k = 1,\dots,d.
$$

This means the gradient in each axis is constant with respect to that same axis. Equivalently, the function is linear in each axis when the other axes are held fixed.

## 1D

If

$$
\frac{d^2 f}{dx^2} = 0,
$$

then the exact zero-penalty function is affine:

$$
f(x) = a_0 + a_1 x.
$$

## 2D

If

$$
\frac{\partial^{2}f}{\partial x^{2}} = 0,
\qquad
\frac{\partial^{2}f}{\partial y^{2}} = 0,
$$

then the exact zero-penalty function is bilinear:

$$
f(x,y) = c + ax + by + dxy.
$$

Check:

$$
\frac{\partial f}{\partial x} = a + dy,
\qquad
\frac{\partial^{2}f}{\partial x^{2}} = 0,
$$

$$
\frac{\partial f}{\partial y} = b + dx,
\qquad
\frac{\partial^{2}f}{\partial y^{2}} = 0.
$$

## 3D

In three dimensions, the exact zero-penalty function class is trilinear:

$$
f(x,y,z) = c_0 + c_1 x + c_2 y + c_3 z + c_4 xy + c_5 xz + c_6 yz + c_7 xyz.
$$

This is linear in each axis separately.

## nD

In $d$ dimensions, the exact zero-penalty functions are multilinear:

$$
f(x_1,\dots,x_d) = \sum_{S \subseteq \{1,\dots,d\}} c_S \prod_{i \in S} x_i.
$$

Each variable appears with power at most 1, so every pure second derivative with respect to a single axis is zero.

## Conclusion

The null space of the second-derivative regularizer is not just globally linear in all variables together. It is multilinear: affine in 1D, bilinear in 2D, trilinear in 3D, and multilinear in nD.
