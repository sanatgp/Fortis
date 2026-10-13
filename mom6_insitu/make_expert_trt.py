import sys
src = open(sys.argv[1]).read()
def rep(a, b):
    global src
    assert src.count(a) == 1, a
    src = src.replace(a, b)
rep("  real, allocatable :: x(:,:)        ! Vector of non-dimensional input features",
    "  real, allocatable, save :: x(:,:)  ! Vector of non-dimensional input features")
rep("  real, allocatable :: y(:,:)        ! Vector of nondimensional",
    "  real, allocatable, save :: y(:,:)  ! Vector of nondimensional")
rep("  allocate(x(nij, 3 * CS%stencil_size**2))\n  allocate(y(nij, 3))",
    "  if (.not. allocated(x)) allocate(x(nij, 3 * CS%stencil_size**2))\n  if (.not. allocated(y)) allocate(y(nij, 3))")
rep("    call ANN_apply_array_sio(nij, x, y, CS%ann_Tall)", "    call zb_trt_apply(nij, x, y)")
rep("  deallocate(x)\n  deallocate(y)\n", "")
rep("  call cpu_clock_begin(CS%id_clock_stress_ANN)\n\n  is  = G%isc",
    "  interface\n    subroutine zb_trt_apply(nij, x, y) bind(c, name=\"zb_trt_apply\")\n"
    "      integer, intent(in) :: nij\n      real(8), intent(in) :: x(*)\n      real(8), intent(inout) :: y(*)\n"
    "    end subroutine\n  end interface\n\n  call cpu_clock_begin(CS%id_clock_stress_ANN)\n\n  is  = G%isc")
open(sys.argv[2], "w").write(src)
print("wrote", sys.argv[2])
