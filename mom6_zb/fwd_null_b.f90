subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
  real(4) :: x(27, 4736), y(3, 4736)
  y(1:3, :) = x(1:3, :)
end subroutine
