subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
  real(4) :: x(61), y(148)
  y = 0.0
end subroutine
