program v
  implicit none
  interface
     subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
       real :: x(*)
       real :: y(*)
     end subroutine
  end interface
  real :: x(124,384), y(128,384), x3(124,384,2), s, mean(124), scale(124), xn(124)
  integer :: i, j
  x = 1.0; s = 0.0; mean = 0.0; scale = 1.0
  do i = 1, 384
     call mlp_forward(x(:,i), y(:,i))
     s = s + y(1,i)
  end do
end program v
