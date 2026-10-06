! TorchFort coupling for zb_host, per cell.
module fwd_torchfort_zb_mod
  use torchfort
  implicit none
  integer, parameter :: n_in = 27, n_out = 3
  real :: xin(n_in, 1), yout(n_out, 1)
  logical :: loaded = .false.
end module
subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
  use fwd_torchfort_zb_mod
  implicit none
  real :: x(n_in), y(n_out)
  integer :: istat
  if (.not. loaded) then
     istat = torchfort_create_model("nn", "torchfort_zb.yaml", 0)
     if (istat /= TORCHFORT_RESULT_SUCCESS) then; print *, 'create_model failed', istat; stop; end if
     loaded = .true.
  end if
  xin(:, 1) = x
  istat = torchfort_inference("nn", xin, yout)
  y = yout(:, 1)
end subroutine
