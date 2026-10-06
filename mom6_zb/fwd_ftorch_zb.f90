! FTorch coupling for zb_host, per cell: one forward per call.
module fwd_ftorch_zb_mod
  use, intrinsic :: iso_fortran_env, only : sp => real32
  use ftorch, only : torch_model, torch_tensor, torch_kCPU, torch_kCUDA, &
                     torch_tensor_from_array, torch_model_load, torch_model_forward
  implicit none
  integer, parameter :: n_in = 27, n_out = 3
  real(sp), dimension(1, n_in), target :: xin
  real(sp), dimension(1, n_out), target :: yout
  type(torch_model) :: model
  type(torch_tensor), dimension(1) :: in_t, out_t
  logical :: loaded = .false.
end module
subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
  use fwd_ftorch_zb_mod
  implicit none
  real(sp) :: x(n_in), y(n_out)
  if (.not. loaded) then
     call torch_model_load(model, "zb_nn.pt", torch_kCUDA, device_index=0)
     call torch_tensor_from_array(out_t(1), yout, torch_kCPU)
     loaded = .true.
  end if
  xin(1, :) = x
  call torch_tensor_from_array(in_t(1), xin, torch_kCUDA, device_index=0)
  call torch_model_forward(model, in_t, out_t)
  y = yout(1, :)
end subroutine
