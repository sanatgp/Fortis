! FTorch coupling for zb_host_expert, one forward per layer over the hand-batched rows.
! The (27,nij) feature-leading batch is presented to FTorch as a [nij,27] tensor by strides (layout=[2,1]); no host transpose.
module fwd_ftorch_zb_b_mod
  use, intrinsic :: iso_fortran_env, only : sp => real32
  use ftorch, only : torch_model, torch_tensor, torch_kCPU, torch_kCUDA, &
                     torch_tensor_from_array, torch_tensor_delete, torch_model_load, torch_model_forward
  implicit none
  integer, parameter :: n_in = 27, n_out = 3, nb = 4736
  type(torch_model) :: model
  type(torch_tensor), dimension(1) :: in_t, out_t
  logical :: loaded = .false.
end module
subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
  use fwd_ftorch_zb_b_mod
  implicit none
  real(sp), target :: x(n_in, nb), y(n_out, nb)
  real(sp), pointer, contiguous :: xp(:,:), yp(:,:)
  if (.not. loaded) then
     call torch_model_load(model, "zb_nn.pt", torch_kCUDA, device_index=0)
     loaded = .true.
  end if
  xp(1:nb, 1:n_in) => x
  yp(1:nb, 1:n_out) => y
  call torch_tensor_from_array(in_t(1), xp, [2, 1], torch_kCUDA, device_index=0)
  call torch_tensor_from_array(out_t(1), yp, [2, 1], torch_kCPU)
  call torch_model_forward(model, in_t, out_t)
  call torch_tensor_delete(in_t(1))
  call torch_tensor_delete(out_t(1))
end subroutine
