program bench
  use, intrinsic :: iso_fortran_env, only : sp => real32
  use ftorch, only : torch_model, torch_tensor, torch_kCPU, torch_kCUDA, &
                     torch_tensor_from_array, torch_model_load, torch_model_forward
  implicit none
  integer, parameter :: n = 3*16*16*16, iters = 1000
  real(sp), dimension(1, 3, 16, 16, 16), target :: xin
  real(sp), dimension(1, 8, 16, 16, 16), target :: yout
  real(sp) :: y(n)
  integer :: i, c, d, h, w
  integer(8) :: t0, t1, rate
  type(torch_model) :: model
  type(torch_tensor), dimension(1) :: in_t, out_t
  do i = 1, n
     y(i) = real(i) / n
  end do
  y = (y - sum(y)/n) / sqrt(sum((y - sum(y)/n)**2)/n)
  do c = 0, 2
     do d = 0, 15
        do h = 0, 15
           do w = 0, 15
              xin(1, c+1, d+1, h+1, w+1) = y(((c*16 + d)*16 + h)*16 + w + 1)
           end do
        end do
     end do
  end do
  call torch_tensor_from_array(in_t(1), xin, torch_kCUDA, device_index=0)
  call torch_tensor_from_array(out_t(1), yout, torch_kCPU)
  call torch_model_load(model, "conv.pt", torch_kCUDA, device_index=0)
  call torch_model_forward(model, in_t, out_t)
  call system_clock(t0, rate)
  do i = 1, iters
     call torch_model_forward(model, in_t, out_t)
  end do
  call system_clock(t1)
  print *, 'per-call us:', real(t1 - t0) / real(rate) * 1.0e6 / iters
  print *, 'checksum:', sum(yout)
end program bench
