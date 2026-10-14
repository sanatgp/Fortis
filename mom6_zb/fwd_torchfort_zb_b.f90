! TorchFort coupling for zb_host_expert, one inference per layer over the hand-batched rows.
! TorchFort reverses Fortran dimensions, so x(27,nij) is the tensor [nij,27] the model expects.
module fwd_torchfort_zb_b_mod
  use torchfort
  implicit none
  integer, parameter :: n_in = 27, n_out = 3, nb = 4736
  real :: xin(n_in, nb), yout(n_out, nb)
  logical :: loaded = .false.
end module
subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
  use fwd_torchfort_zb_b_mod
  implicit none
  real :: x(n_in, nb), y(n_out, nb)
  integer :: istat
  if (.not. loaded) then
     istat = torchfort_create_model("nn", "torchfort_zb.yaml", 0)
     if (istat /= TORCHFORT_RESULT_SUCCESS) then; print *, 'create_model failed', istat; stop; end if
     loaded = .true.
  end if
  xin = x
  istat = torchfort_inference("nn", xin, yout)
  y = yout
end subroutine
