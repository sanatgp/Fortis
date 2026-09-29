module fwd_torchfort_mod
  use torchfort
  implicit none
  logical, save :: loaded = .false.
contains
  subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
    real :: x(124,384), y(128,384)
    integer :: istat
    if (.not. loaded) then
      istat = torchfort_create_model("mlp", "/scratch/taghipouranvari.s/FTORCH/climsim_run/torchfort.yaml", 0)
      loaded = .true.
    end if
    istat = torchfort_inference("mlp", x, y)
  end subroutine
end module
