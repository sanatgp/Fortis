subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
  real :: x(124,384), y(128,384)
  y = 0.
end subroutine
