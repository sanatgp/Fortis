program toy
  implicit none
  interface
     subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
       real :: x(*)
       real :: y(*)
     end subroutine mlp_forward
  end interface
  integer, parameter :: n = 1024
  real :: x(n), y(n), z(n)
  real :: mu, sigma
  integer :: i
  do i = 1, n
     x(i) = real(i) / n
  end do
  mu = sum(x) / n
  sigma = sqrt(sum((x - mu)**2) / n)
  do i = 1, n
     y(i) = (x(i) - mu) / sigma
  end do
  call mlp_forward(y, z)
  print *, 'z(1:5) =', z(1:5)
end program toy
