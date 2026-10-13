! Standalone driver for zb_ann_nest: fields as in the harness (zb_host.f90), MOM6 sizes and symmetric
! corner arrays, 3 steps.  Prints checksums and the NaN count so the gfortran and FORTIS builds can be compared.
program zb_unit_test
  implicit none
  integer, parameter :: halo = 4, nih = 120, njh = 280, nz = 15
  integer, parameter :: szi = nih + 2 * halo, szj = njh + 2 * halo
  real(8) :: sh_xy_h(szi,szj,nz), sh_xx(szi,szj,nz), vort_xy_h(szi,szj,nz), norm_h(szi,szj,nz)
  real(8) :: kappa_h(szi,szj), mask2dBu(szi+1,szj+1), Txx(szi,szj,nz), Tyy(szi,szj,nz), Txy(szi+1,szj+1,nz)
  integer(8) :: seed, c0, c1, rate
  integer :: step, u
  interface
    subroutine zb_ann_nest(sh_xy_h, sh_xx, vort_xy_h, norm_h, kappa_h, mask2dBu, Txx, Tyy, Txy) bind(c, name="zb_ann_nest")
      real(8), intent(in)    :: sh_xy_h(*), sh_xx(*), vort_xy_h(*), norm_h(*), kappa_h(*), mask2dBu(*)
      real(8), intent(inout) :: Txx(*), Tyy(*), Txy(*)
    end subroutine
  end interface
  seed = 12345
  call make_field(sh_xy_h, 0.31d0, 0.23d0, 0.17d0)
  call make_field(sh_xx, 0.27d0, 0.19d0, 0.13d0)
  call make_field(vort_xy_h, 0.29d0, 0.21d0, 0.11d0)
  norm_h = sqrt(sh_xy_h**2 + sh_xx**2 + vort_xy_h**2) * 3d0
  kappa_h = -6.25d8; mask2dBu = 1d0; mask2dBu(1,:) = 0d0; mask2dBu(szi+1,:) = 0d0; mask2dBu(:,1) = 0d0; mask2dBu(:,szj+1) = 0d0
  Txx = 0d0; Tyy = 0d0; Txy = 0d0
  call system_clock(c0, rate)
  do step = 1, 3
    if (step == 2) call system_clock(c0)
    call zb_ann_nest(sh_xy_h, sh_xx, vort_xy_h, norm_h, kappa_h, mask2dBu, Txx, Tyy, Txy)
  end do
  call system_clock(c1)
  print *, 'per-step ms:', real(c1 - c0) / real(rate) * 1.0e3 / 2
  print *, 'checksum Txx:', sum(Txx), ' Tyy:', sum(Tyy), ' Txy:', sum(Txy)
  print *, 'NaN count:', count(Txx /= Txx) + count(Tyy /= Tyy) + count(Txy /= Txy)
  open(newunit=u, file="zb_unit_out.bin", access="stream", form="unformatted", status="replace")
  write(u) Txx; write(u) Tyy; write(u) Txy; close(u)
contains
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
end program
