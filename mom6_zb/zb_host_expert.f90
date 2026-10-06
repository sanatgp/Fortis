! MOM6 Zanna-Bolton ANN momentum-closure host, transcribed from compute_stress_ANN_collocated
! in MOM_Zanna_Bolton.F90 of m2lines/MOM6 (dev/m2lines, commit 89f1fb3) with the ANN of
! Perezhogin, Zanna and Adcroft (2025).  The inline ANN_apply(x, y, CS%ann_Tall) is the call
! mlp_forward(x, y); the stencil packing, normalization, de-scaling, stores and the corner
! interpolation of Txy are as in the original.  One rank's 60x70 subdomain of the NeverWorld2
! 0.25-degree grid (240x560, 15 layers) with a 4-point halo; the halo exchanges (pass_var) are
! replaced by computing the interpolated fields over the halo directly.
! EXPERT REWRITE: the per-cell call is hand-batched per layer as in the production MOM6 branch
! (NOAA-GFDL/MOM6 dev/gfdl, ANN_apply_array_sio): a pre-loop packs the normalized stencil of
! every cell into column m of xb(27,nij), one call runs the whole layer, and a post-loop
! de-scales and stores.  xb is feature-leading so that one column is one sample.
program zb_host_expert
  implicit none
  integer, parameter :: rk = 4
  interface
     subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
       import :: rk
       real(rk) :: x(*)
       real(rk) :: y(*)
     end subroutine
  end interface
  integer, parameter :: halo = 4, nih = 60, njh = 70, nz = 15
  integer, parameter :: is = halo + 1, ie = halo + nih, js = halo + 1, je = halo + njh
  integer, parameter :: szi = nih + 2 * halo, szj = njh + 2 * halo
  integer, parameter :: Isq = is - 1, Ieq = ie, Jsq = js - 1, Jeq = je
  integer, parameter :: stencil_size = 3, offset = (stencil_size - 1) / 2, stencil_points = stencil_size**2
  integer, parameter :: nsteps = 11
  real(rk), parameter :: subroundoff_shear = 1.0e-30_rk, amplitude = 1.0_rk, areaT = 6.25e8_rk
  real(rk) :: sh_xy(szi,szj,nz), sh_xx(szi,szj,nz), vort_xy(szi,szj,nz)
  real(rk) :: Txx(szi,szj,nz), Tyy(szi,szj,nz), Txy(szi,szj,nz)
  real(rk) :: mask2dT(szi,szj), mask2dBu(szi,szj), kappa_h(szi,szj)
  real(rk) :: sh_xy_h(szi,szj,nz), vort_xy_h(szi,szj,nz), norm_h(szi,szj,nz)
  real(rk) :: sqr_h(szi,szj), Txy_h(szi,szj)
  integer, parameter :: nij = (ie - is + 5) * (je - js + 5)
  real(rk) :: xb(3 * stencil_size**2, nij), yb(3, nij), yy(3), tmp
  integer :: m
  real(8) :: fld(szi,szj,nz), ref(szi,szj,nz), err, errmax
  integer :: i, j, k, ii, jj, step, u, ios
  integer(8) :: seed
  integer(8) :: c0, c1, rate

  ! --- synthesized velocity-gradient fields, O(1e-5 s^-1), the same values in every precision
  seed = 12345
  call make_field(fld, 0.31d0, 0.23d0, 0.17d0); sh_xy = real(fld, rk)
  call make_field(fld, 0.27d0, 0.19d0, 0.13d0); sh_xx = real(fld, rk)
  call make_field(fld, 0.29d0, 0.21d0, 0.11d0); vort_xy = real(fld, rk)
  mask2dT = 1.0_rk; mask2dBu = 1.0_rk
  mask2dT(1,:) = 0.0_rk; mask2dT(szi,:) = 0.0_rk; mask2dT(:,1) = 0.0_rk; mask2dT(:,szj) = 0.0_rk
  mask2dBu(1,:) = 0.0_rk; mask2dBu(szi,:) = 0.0_rk; mask2dBu(:,1) = 0.0_rk; mask2dBu(:,szj) = 0.0_rk
  do j = 1, szj; do i = 1, szi
     kappa_h(i,j) = -amplitude * areaT * mask2dT(i,j)
  enddo; enddo
  Txx = 0.0_rk; Tyy = 0.0_rk; Txy = 0.0_rk; Txy_h = 0.0_rk

  call system_clock(c0, rate)
  do step = 1, nsteps
     if (step == 2) call system_clock(c0)
     sh_xy_h = 0.
     vort_xy_h = 0.
     norm_h = 0.

     ! Interpolate input features
     do k=1,nz
       do j=js-3,je+3 ; do i=is-3,ie+3
         sh_xy_h(i,j,k) = 0.25 * ( (sh_xy(I-1,J-1,k) + sh_xy(I,J,k)) &
                                 + (sh_xy(I-1,J,k) + sh_xy(I,J-1,k)) )

         vort_xy_h(i,j,k) = 0.25 * ( (vort_xy(I-1,J-1,k) + vort_xy(I,J,k)) &
                                   + (vort_xy(I-1,J,k) + vort_xy(I,J-1,k)) )

         sqr_h(i,j) = (sh_xx(i,j,k)**2 + sh_xy_h(i,j,k)**2 + vort_xy_h(i,j,k)**2) * mask2dT(i,j)
       enddo; enddo

       do j=js-2,je+2 ; do i=is-2,ie+2
         tmp = 0.0
         do jj=j-offset,j+offset; do ii=i-offset,i+offset
           tmp = tmp + sqr_h(ii,jj)
         enddo; enddo
         norm_h(i,j,k) = sqrt(tmp)
       enddo; enddo
     enddo

     do k=1,nz
       m = 0
       do j=js-2,je+2 ; do i=is-2,ie+2
         m = m + 1
         xb(1:stencil_points, m) =                                                        &
                           RESHAPE(sh_xy_h(i-offset:i+offset,                             &
                                           j-offset:j+offset,k), (/stencil_points/))
         xb(stencil_points+1:2*stencil_points, m) =                                       &
                           RESHAPE(sh_xx(i-offset:i+offset,                               &
                                         j-offset:j+offset,k), (/stencil_points/))
         xb(2*stencil_points+1:3*stencil_points, m) =                                     &
                           RESHAPE(vort_xy_h(i-offset:i+offset,                           &
                                             j-offset:j+offset,k), (/stencil_points/))

         xb(:, m) = xb(:, m) / (norm_h(i,j,k) + subroundoff_shear)
       enddo; enddo

       call mlp_forward(xb, yb)

       m = 0
       do j=js-2,je+2 ; do i=is-2,ie+2
         m = m + 1
         yy(:) = yb(:, m) * norm_h(i,j,k) * norm_h(i,j,k) * kappa_h(i,j)

         Txy_h(i,j)   = yy(1)
         Txx(i,j,k)   = yy(2)
         Tyy(i,j,k)   = yy(3)
       enddo ; enddo

       do J=Jsq-1,Jeq+1 ; do I=Isq-1,Ieq+1
         Txy(I,J,k) = 0.25 * ( (Txy_h(i+1,j+1) + Txy_h(i,j)) &
                             + (Txy_h(i+1,j)   + Txy_h(i,j+1))) * mask2dBu(I,J)
       enddo; enddo

     enddo ! end of k loop
  end do
  call system_clock(c1)

  print *, 'per-step ms:', real(c1 - c0) / real(rate) * 1.0e3 / (nsteps - 1)
  print *, 'checksum Txx:', sum(real(Txx, 8)), '  Tyy:', sum(real(Tyy, 8)), '  Txy:', sum(real(Txy, 8))
  open(newunit=u, file="zb_out.bin", access="stream", form="unformatted", status="replace")
  write(u) real(Txx, 8); write(u) real(Tyy, 8); write(u) real(Txy, 8); close(u)
  open(newunit=u, file="zb_ref.bin", access="stream", form="unformatted", status="old", iostat=ios)
  if (ios == 0) then
     errmax = 0d0
     read(u) ref; err = maxval(abs(real(Txx, 8) - ref)) / maxval(abs(ref)); errmax = max(errmax, err)
     read(u) ref; err = maxval(abs(real(Tyy, 8) - ref)) / maxval(abs(ref)); errmax = max(errmax, err)
     read(u) ref; err = maxval(abs(real(Txy, 8) - ref)) / maxval(abs(ref)); errmax = max(errmax, err)
     close(u)
     print *, 'max rel err vs fp64 reference:', errmax
  end if

contains

  ! smooth field plus a deterministic pseudo-random part, amplitude 1e-5 s^-1, computed in fp64
  subroutine make_field(f, a, b, c)
    real(8), intent(out) :: f(szi,szj,nz)
    real(8), intent(in) :: a, b, c
    integer :: i, j, k
    real(8) :: r
    do k = 1, nz; do j = 1, szj; do i = 1, szi
       seed = mod(seed * 1103515245_8 + 12345_8, 2147483648_8)
       r = real(seed, 8) / 2147483648d0 - 0.5d0
       f(i,j,k) = 1d-5 * (0.6d0 * sin(a * i + b * j + c * k) * cos(b * i - a * j) + 0.4d0 * r)
    enddo; enddo; enddo
  end subroutine
end program zb_host_expert
