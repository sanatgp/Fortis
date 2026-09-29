module fwd_ftorch_mod
  use ftorch, only : torch_model, torch_tensor, torch_kCPU, torch_kCUDA, &
                     torch_tensor_from_array, torch_model_load, torch_model_forward
  implicit none
  type(torch_model), save :: model
  type(torch_tensor), dimension(1), save :: in_t, out_t
  real, dimension(384,124), target, save :: xin
  real, dimension(384,128), target, save :: yout
  logical, save :: loaded = .false.
contains
  ! E3SM hands over input_torch(inputlength, pcols). This FTorch maps Fortran dims in order,
  ! so the coupling must transpose into a (pcols, inputlength) temporary and back.
  subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
    real :: x(124,384), y(128,384)
    if (.not. loaded) then
      call torch_model_load(model, "/scratch/taghipouranvari.s/FTORCH/climsim_run/climsim_mlp.pt", torch_kCUDA, device_index=0)
      call torch_tensor_from_array(out_t(1), yout, torch_kCPU)
      loaded = .true.
    end if
    xin = transpose(x)
    call torch_tensor_from_array(in_t(1), xin, torch_kCUDA, device_index=0)
    call torch_model_forward(model, in_t, out_t)
    y = transpose(yout)
  end subroutine
end module
