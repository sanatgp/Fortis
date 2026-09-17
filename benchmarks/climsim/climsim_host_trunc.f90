program climsim_host
  implicit none
  interface
     subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
       real :: x(*)
       real :: y(*)
     end subroutine
  end interface
  integer, parameter :: nin = 124, nout = 128, ncol = 384, nsteps = 100
  real :: x(nin, ncol), y(nout, ncol), yref(nout, ncol)
  integer :: c, s, u
  integer(8) :: t0, t1, rate
  real :: maxrel, nmean(nin), nscale(nin)

  open(newunit=u, file="columns.bin", access="stream", form="unformatted", status="old"); read(u) x; close(u)
  open(newunit=u, file="norm.bin", access="stream", form="unformatted", status="old"); read(u) nmean, nscale; close(u)
  do c = 1, ncol
     x(:, c) = (x(:, c) - nmean) / nscale
  end do
  open(newunit=u, file="ref.bin", access="stream", form="unformatted", status="old"); read(u) yref; close(u)

  do c = 1, ncol
     call mlp_forward(x(:, c), y(:, c))        ! warmup step
  end do
  call system_clock(t0, rate)
  do s = 1, nsteps
     do c = 1, ncol
        call mlp_forward(x(:, c), y(:, c))
     end do
  end do
  call system_clock(t1)
  maxrel = maxval(abs(y - yref)) / maxval(abs(yref))
  open(newunit=u, file='fortis_out.bin', access='stream', form='unformatted', status='replace'); write(u) y; close(u)
  print *, 'per-step ms:', real(t1 - t0) / real(rate) * 1.0e3 / nsteps
  print *, 'per-column us:', real(t1 - t0) / real(rate) * 1.0e6 / (nsteps * ncol)
  print *, 'checksum:', sum(y), '  ref:', sum(yref), '  max rel err:', maxrel
end program climsim_host
