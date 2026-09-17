program bench
  use, intrinsic :: iso_fortran_env, only : sp => real32
  use ftorch, only : torch_model, torch_tensor, torch_kCPU, torch_kCUDA, &
                     torch_tensor_from_array, torch_model_load, torch_model_forward
  implicit none
  integer, parameter :: n = 1024, iters = 1000
  real(sp), dimension(1, n), target :: y2, z2
  real(sp) :: y(n), z(n)
  integer :: i
  integer(8) :: t0, t1, rate
  type(torch_model) :: model
  type(torch_tensor), dimension(1) :: in_t, out_t

  do i = 1, n
     y(i) = real(i) / n
  end do
  y = (y - sum(y)/n) / sqrt(sum((y - sum(y)/n)**2)/n)
  y2(1, :) = y

  call torch_tensor_from_array(in_t(1), y2, torch_kCUDA, device_index=0)
  call torch_tensor_from_array(out_t(1), z2, torch_kCPU)
  call torch_model_load(model, "mlp_ts.pt", torch_kCUDA, device_index=0)

  call torch_model_forward(model, in_t, out_t)   ! warmup
  call system_clock(t0, rate)
  do i = 1, iters
     call torch_model_forward(model, in_t, out_t)
  end do
  call system_clock(t1)
  z = z2(1, :)
  print *, 'per-call us:', real(t1 - t0) / real(rate) * 1.0e6 / iters
  print *, 'checksum:', sum(z)
  print *, 'z(1:5) =', z(1:5)
end program bench
