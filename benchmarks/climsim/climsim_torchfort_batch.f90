program climsim_torchfort
  use torchfort
  implicit none
  integer, parameter :: nin = 124, nout = 128, ncol = 384, nsteps = 100
  real :: x(nin, ncol), y(nout, ncol), yref(nout, ncol), nmean(nin), nscale(nin)
  real :: xin(nin, ncol), yout(nout, ncol)
  integer :: c, s, u, istat
  integer(8) :: t0, t1, rate
  open(newunit=u, file="columns.bin", access="stream", form="unformatted", status="old"); read(u) x; close(u)
  open(newunit=u, file="norm.bin", access="stream", form="unformatted", status="old"); read(u) nmean, nscale; close(u)
  do c = 1, ncol
     x(:, c) = (x(:, c) - nmean) / nscale
  end do
  open(newunit=u, file="ref.bin", access="stream", form="unformatted", status="old"); read(u) yref; close(u)
  istat = torchfort_create_model("mlp", "torchfort.yaml", 0)
  if (istat /= TORCHFORT_RESULT_SUCCESS) then; print *, 'create_model failed', istat; stop; end if
  xin = x
  istat = torchfort_inference("mlp", xin, yout)
  y = yout
  call system_clock(t0, rate)
  do s = 1, nsteps
     xin = x
     istat = torchfort_inference("mlp", xin, yout)
     y = yout
  end do
  call system_clock(t1)
  print *, 'per-step ms:', real(t1 - t0) / real(rate) * 1.0e3 / nsteps
  print *, 'per-column us:', real(t1 - t0) / real(rate) * 1.0e6 / (nsteps * ncol)
  print *, 'checksum:', sum(y), '  ref:', sum(yref), '  max rel err:', maxval(abs(y - yref)) / maxval(abs(yref))
end program climsim_torchfort
