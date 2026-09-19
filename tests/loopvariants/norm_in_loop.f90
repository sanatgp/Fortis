program climsim_host_norm
  implicit none
  interface
     subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
       real :: x(*)
       real :: y(*)
     end subroutine
  end interface
  integer, parameter :: nin = 124, nout = 128, ncol = 384, nsteps = 100
  real :: x(nin, ncol), y(nout, ncol), yref(nout, ncol)
  real :: mean(nin), scale(nin), xn(nin)
  integer :: i, step, u
  integer(8) :: t0, t1, rate
  real :: err
  open(newunit=u, file="columns.bin", access="stream", form="unformatted"); read(u) x; close(u)
  open(newunit=u, file="norm.bin", access="stream", form="unformatted"); read(u) mean; read(u) scale; close(u)
  open(newunit=u, file="ref.bin", access="stream", form="unformatted"); read(u) yref; close(u)
  do i = 1, ncol
     xn = (x(:, i) - mean) / scale
     call mlp_forward(xn, y(:, i))
  end do
  call system_clock(t0, rate)
  do step = 1, nsteps
     do i = 1, ncol
        xn = (x(:, i) - mean) / scale
        call mlp_forward(xn, y(:, i))
     end do
  end do
  call system_clock(t1)
  err = maxval(abs(y - yref)) / maxval(abs(yref))
  print *, 'per-step ms:', real(t1 - t0) / real(rate) * 1.0e3 / nsteps
  print *, 'checksum:', sum(y), '  ref:', sum(yref), '  max rel err:', err
end program climsim_host_norm
