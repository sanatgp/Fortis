program bench
  implicit none
  interface
     subroutine mlp_upload(x) bind(c, name="mlp_upload")
       real :: x(*)
     end subroutine
     subroutine mlp_forward_dev() bind(c, name="mlp_forward_dev")
     end subroutine
     subroutine mlp_download(y) bind(c, name="mlp_download")
       real :: y(*)
     end subroutine
  end interface
  integer, parameter :: n = 1024, iters = 1000
  real :: y(n), z(n)
  integer :: i
  integer(8) :: t0, t1, rate
  do i = 1, n
     y(i) = real(i) / n
  end do
  y = (y - sum(y)/n) / sqrt(sum((y - sum(y)/n)**2)/n)
  call mlp_upload(y)
  call mlp_forward_dev()
  call mlp_download(z)          ! warmup + correctness below
  call system_clock(t0, rate)
  do i = 1, iters
     call mlp_forward_dev()
  end do
  call mlp_download(z)
  call system_clock(t1)
  print *, 'per-call us:', real(t1 - t0) / real(rate) * 1.0e6 / iters
  print *, 'checksum:', sum(z)
end program bench
