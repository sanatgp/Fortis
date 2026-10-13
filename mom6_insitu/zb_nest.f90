! The ANN nest of compute_stress_ANN_collocated (MOM_Zanna_Bolton.F90, m2lines/MOM6) as one
! translation unit with explicit shapes for one rank of a 2x2 layout of the 0.25-degree
! NeverWorld2 grid (120x280x15, halo 4, symmetric memory).  The per-cell call is the model
! call; everything else is as in the source.  Index 1 of each dummy array is isd (or IsdB
! for the corner arrays), so the compute domain starts at halo+1.
subroutine zb_ann_nest(sh_xy_h, sh_xx, vort_xy_h, norm_h, kappa_h, mask2dBu, Txx, Tyy, Txy) bind(c, name="zb_ann_nest")
  implicit none
  integer, parameter :: c_double = 8
  integer, parameter :: halo = 4, nih = 120, njh = 280, nz = 15
  integer, parameter :: szi = nih + 2 * halo, szj = njh + 2 * halo
  integer, parameter :: is = halo + 1, ie = halo + nih, js = halo + 1, je = halo + njh
  integer, parameter :: Isq = is - 1, Ieq = ie, Jsq = js - 1, Jeq = je
  integer, parameter :: stencil_size = 3, offset = (stencil_size - 1) / 2, stencil_points = stencil_size**2
  real(c_double), intent(in)    :: sh_xy_h(szi,szj,nz), sh_xx(szi,szj,nz), vort_xy_h(szi,szj,nz), norm_h(szi,szj,nz)
  real(c_double), intent(in)    :: kappa_h(szi,szj), mask2dBu(szi+1,szj+1)
  real(c_double), intent(inout) :: Txx(szi,szj,nz), Tyy(szi,szj,nz), Txy(szi+1,szj+1,nz)
  real(c_double), parameter :: subroundoff = 1.0e-30_8
  interface
     subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
       integer, parameter :: c_double = 8
       real(c_double) :: x(*)
       real(c_double) :: y(*)
     end subroutine
  end interface
  real(c_double) :: Txy_h(szi,szj)
  real(c_double) :: x(3 * stencil_points), y(3), input_norm
  integer :: i, j, k

  do k=1,nz
    do j=js-2,je+2 ; do i=is-2,ie+2
      x(1:stencil_points) =                                                            &
                        RESHAPE(sh_xy_h(i-offset:i+offset,                             &
                                        j-offset:j+offset,k), (/stencil_points/))
      x(stencil_points+1:2*stencil_points) =                                           &
                        RESHAPE(sh_xx(i-offset:i+offset,                               &
                                      j-offset:j+offset,k), (/stencil_points/))
      x(2*stencil_points+1:3*stencil_points) =                                         &
                        RESHAPE(vort_xy_h(i-offset:i+offset,                           &
                                          j-offset:j+offset,k), (/stencil_points/))

      input_norm = norm_h(i,j,k)

      x(:) = x(:) / (input_norm + subroundoff)

      call mlp_forward(x, y)

      y(:) = y(:) * input_norm * input_norm * kappa_h(i,j)

      Txy_h(i,j)   = y(1)
      Txx(i,j,k)   = y(2)
      Tyy(i,j,k)   = y(3)
    enddo ; enddo

    ! corner arrays are one larger in symmetric memory, so corner index I is I+1 here
    do j=Jsq-1,Jeq+1 ; do i=Isq-1,Ieq+1
      Txy(i+1,j+1,k) = 0.25 * ( (Txy_h(i+1,j+1) + Txy_h(i,j)) &
                              + (Txy_h(i+1,j)   + Txy_h(i,j+1))) * mask2dBu(i+1,j+1)
    enddo ; enddo
  enddo
end subroutine zb_ann_nest
