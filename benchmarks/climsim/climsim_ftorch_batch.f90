program climsim_ftorch
  use, intrinsic :: iso_fortran_env, only : sp => real32
  use ftorch, only : torch_model, torch_tensor, torch_kCPU, torch_kCUDA, &
                     torch_tensor_from_array, torch_model_load, torch_model_forward
  implicit none
  integer, parameter :: nin = 124, nout = 128, ncol = 384, nsteps = 100
  real(sp) :: x(nin, ncol), y(nout, ncol), yref(nout, ncol), nmean(nin), nscale(nin)
  real(sp), dimension(ncol, nin), target :: xin
  real(sp), dimension(ncol, nout), target :: yout
  integer :: c, s, u
  integer(8) :: t0, t1, rate
  type(torch_model) :: model
  type(torch_tensor), dimension(1) :: in_t, out_t

  open(newunit=u, file="columns.bin", access="stream", form="unformatted", status="old"); read(u) x; close(u)
  open(newunit=u, file="norm.bin", access="stream", form="unformatted", status="old"); read(u) nmean, nscale; close(u)
  do c = 1, ncol
     x(:, c) = (x(:, c) - nmean) / nscale
  end do
  open(newunit=u, file="ref.bin", access="stream", form="unformatted", status="old"); read(u) yref; close(u)

  call torch_model_load(model, "climsim_mlp.pt", torch_kCUDA, device_index=0)
  call torch_tensor_from_array(out_t(1), yout, torch_kCPU)

  xin = transpose(x)
  call torch_tensor_from_array(in_t(1), xin, torch_kCUDA, device_index=0)
  call torch_model_forward(model, in_t, out_t)
  y = transpose(yout)
  call system_clock(t0, rate)
  do s = 1, nsteps
     xin = transpose(x)
     call torch_tensor_from_array(in_t(1), xin, torch_kCUDA, device_index=0)
     call torch_model_forward(model, in_t, out_t)
     y = transpose(yout)
  end do
  call system_clock(t1)
  print *, 'per-step ms:', real(t1 - t0) / real(rate) * 1.0e3 / nsteps
  print *, 'per-column us:', real(t1 - t0) / real(rate) * 1.0e6 / (nsteps * ncol)
  print *, 'checksum:', sum(y), '  ref:', sum(yref), '  max rel err:', maxval(abs(y - yref)) / maxval(abs(yref))
end program climsim_ftorch
