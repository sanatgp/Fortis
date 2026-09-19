program v
  implicit none
  interface
     subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
       real :: x(*)
       real :: y(*)
     end subroutine
  end interface
  real :: x(124,384), y(128,384), x3(124,384,2), s
  integer :: i, j
  x = 1.0; s = 0.0
  call mlp_forward(x(:,1), y(:,1))
end program v
