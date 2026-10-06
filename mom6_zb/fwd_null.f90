subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
  real(4) :: x(*), y(*)
  y(1) = x(1); y(2) = x(2); y(3) = x(3)
end subroutine
