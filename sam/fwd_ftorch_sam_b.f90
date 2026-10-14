! FTorch coupling for sam_host_batch, one forward per step over the hand-batched 3240 columns.
! FTorch keeps Fortran index order, so the (61,3240) feature-leading batch is transposed into a (3240,61) buffer.
module fwd_ftorch_sam_b_mod
  use, intrinsic :: iso_fortran_env, only : sp => real32
  use ftorch, only : torch_model, torch_tensor, torch_kCPU, torch_kCUDA, &
                     torch_tensor_from_array, torch_model_load, torch_model_forward
  implicit none
  integer, parameter :: n_in = 61, n_out = 148, nb = 3240
  real(sp), dimension(nb, n_in), target :: xin
  real(sp), dimension(nb, n_out), target :: yout
  type(torch_model) :: model
  type(torch_tensor), dimension(1) :: in_t, out_t
  logical :: loaded = .false.
end module
subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
  use fwd_ftorch_sam_b_mod
  implicit none
  real(sp) :: x(n_in, nb), y(n_out, nb)
  if (.not. loaded) then
     call torch_model_load(model, "sam_nn.pt", torch_kCUDA, device_index=0)
     call torch_tensor_from_array(out_t(1), yout, torch_kCPU)
     loaded = .true.
  end if
  xin = transpose(x)
  call torch_tensor_from_array(in_t(1), xin, torch_kCUDA, device_index=0)
  call torch_model_forward(model, in_t, out_t)
  y = transpose(yout)
end subroutine
