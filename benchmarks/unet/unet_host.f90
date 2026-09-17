program unet_host
  implicit none
  interface
     subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
       real :: x(*)
       real :: y(*)
     end subroutine
  end interface
  integer, parameter :: n = 2044*2044, nsteps = 20
  real, allocatable :: x(:), y(:)
  integer :: i, u
  integer(8) :: t0, t1, rate
  allocate(x(n), y(n))
  do i = 1, n
     x(i) = 0.5 + 0.5 * sin(real(i) * 1.0e-3) * cos(real(i) * 3.7e-5)
  end do
  open(newunit=u, file="unet_in.bin", access="stream", form="unformatted", status="replace"); write(u) x; close(u)
  call mlp_forward(x, y)
  call system_clock(t0, rate)
  do i = 1, nsteps
     call mlp_forward(x, y)
  end do
  call system_clock(t1)
  open(newunit=u, file="unet_out.bin", access="stream", form="unformatted", status="replace"); write(u) y; close(u)
  print *, 'per-call ms:', real(t1 - t0) / real(rate) * 1.0e3 / nsteps
  print *, 'checksum:', sum(y), ' y(1:3):', y(1:3)
end program unet_host
