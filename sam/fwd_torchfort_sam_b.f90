! TorchFort coupling for sam_host_batch, one inference per step over the hand-batched 3240 columns.
! TorchFort reverses Fortran dimensions, so x(61,3240) is the tensor [3240,61] the model expects.
module fwd_torchfort_sam_b_mod
  use torchfort
  implicit none
  integer, parameter :: n_in = 61, n_out = 148, nb = 3240
  real :: xin(n_in, nb), yout(n_out, nb)
  logical :: loaded = .false.
end module
subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
  use fwd_torchfort_sam_b_mod
  implicit none
  real :: x(n_in, nb), y(n_out, nb)
  integer :: istat
  if (.not. loaded) then
     istat = torchfort_create_model("nn", "torchfort_sam.yaml", 0)
     if (istat /= TORCHFORT_RESULT_SUCCESS) then; print *, 'create_model failed', istat; stop; end if
     loaded = .true.
  end if
  xin = x
  istat = torchfort_inference("nn", xin, yout)
  y = yout
end subroutine
