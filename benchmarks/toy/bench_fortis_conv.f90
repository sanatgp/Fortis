program bench
  implicit none
  interface
     subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
       real :: x(*)
       real :: y(*)
     end subroutine mlp_forward
  end interface
  integer, parameter :: n = 3*16*16*16, iters = 1000
  real :: y(n), z(8*16*16*16)
  integer :: i
  integer(8) :: t0, t1, rate
  do i = 1, n
     y(i) = real(i) / n
  end do
  y = (y - sum(y)/n) / sqrt(sum((y - sum(y)/n)**2)/n)
  call mlp_forward(y, z)          ! warmup
  call system_clock(t0, rate)
  do i = 1, iters
     call mlp_forward(y, z)
  end do
  call system_clock(t1)
  print *, 'per-call us:', real(t1 - t0) / real(rate) * 1.0e6 / iters
  print *, 'checksum:', sum(z)
end program bench
