program tsrgan_host
  implicit none
  interface
     subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
       real :: x(*)
       real :: y(*)
     end subroutine
  end interface
  integer, parameter :: nin = 33*33*33*3, nout = 132*132*132*3, nsteps = 5
  real, allocatable :: x(:), y(:)
  integer :: i, u
  integer(8) :: t0, t1, rate
  allocate(x(nin), y(nout))
  do i = 1, nin
     x(i) = 0.5 * sin(real(i) * 1.7e-3) * cos(real(i) * 5.3e-5)
  end do
  open(newunit=u, file="tsrgan_in.bin", access="stream", form="unformatted", status="replace"); write(u) x; close(u)
  call mlp_forward(x, y)
  call system_clock(t0, rate)
  do i = 1, nsteps
     call mlp_forward(x, y)
  end do
  call system_clock(t1)
  open(newunit=u, file="tsrgan_out.bin", access="stream", form="unformatted", status="replace"); write(u) y; close(u)
  print *, 'per-call ms:', real(t1 - t0) / real(rate) * 1.0e3 / nsteps
  print *, 'checksum:', sum(y), ' y(1:3):', y(1:3)
end program tsrgan_host
