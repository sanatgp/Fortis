# zb_host_rt.f90 from zb_host.f90: the grid read at run time, allocatable fields, loop bounds from variables.
s = open('zb_host.f90').read()
def rep(old, new):
    global s
    assert s.count(old) == 1, old[:50]; s = s.replace(old, new)
rep("""! replaced by computing the interpolated fields over the halo directly.
program zb_host""", """! replaced by computing the interpolated fields over the halo directly.
! RUN-TIME EXTENTS: as in MOM6 itself, the subdomain size comes from the run (here zb_grid.txt:
! nih njh nz), the fields are allocatable, and the loop bounds are the grid's is, ie, js, je, nz.
program zb_host_rt""")
rep("""  integer, parameter :: halo = 4, nih = 60, njh = 70, nz = 15
  integer, parameter :: is = halo + 1, ie = halo + nih, js = halo + 1, je = halo + njh
  integer, parameter :: szi = nih + 2 * halo, szj = njh + 2 * halo
  integer, parameter :: Isq = is - 1, Ieq = ie, Jsq = js - 1, Jeq = je
""", """  integer, parameter :: halo = 4
  integer :: nih, njh, nz, is, ie, js, je, szi, szj, Isq, Ieq, Jsq, Jeq
""")
rep("""  real(rk) :: sh_xy(szi,szj,nz), sh_xx(szi,szj,nz), vort_xy(szi,szj,nz)
  real(rk) :: Txx(szi,szj,nz), Tyy(szi,szj,nz), Txy(szi,szj,nz)
  real(rk) :: mask2dT(szi,szj), mask2dBu(szi,szj), kappa_h(szi,szj)
  real(rk) :: sh_xy_h(szi,szj,nz), vort_xy_h(szi,szj,nz), norm_h(szi,szj,nz)
  real(rk) :: sqr_h(szi,szj), Txy_h(szi,szj)
  real(rk) :: x(3 * stencil_size**2), y(3), input_norm, tmp
  real(8) :: fld(szi,szj,nz), ref(szi,szj,nz), err, errmax
""", """  real(rk), allocatable :: sh_xy(:,:,:), sh_xx(:,:,:), vort_xy(:,:,:)
  real(rk), allocatable :: Txx(:,:,:), Tyy(:,:,:), Txy(:,:,:)
  real(rk), allocatable :: mask2dT(:,:), mask2dBu(:,:), kappa_h(:,:)
  real(rk), allocatable :: sh_xy_h(:,:,:), vort_xy_h(:,:,:), norm_h(:,:,:)
  real(rk), allocatable :: sqr_h(:,:), Txy_h(:,:)
  real(rk) :: x(3 * stencil_size**2), y(3), input_norm, tmp
  real(8), allocatable :: fld(:,:,:), ref(:,:,:)
  real(8) :: err, errmax
""")
rep("""  ! --- synthesized velocity-gradient fields, O(1e-5 s^-1), the same values in every precision
  seed = 12345
""", """  ! --- the grid of this run
  open(newunit=u, file="zb_grid.txt", status="old"); read(u, *) nih, njh, nz; close(u)
  is = halo + 1; ie = halo + nih; js = halo + 1; je = halo + njh
  szi = nih + 2 * halo; szj = njh + 2 * halo
  Isq = is - 1; Ieq = ie; Jsq = js - 1; Jeq = je
  allocate(sh_xy(szi,szj,nz), sh_xx(szi,szj,nz), vort_xy(szi,szj,nz), Txx(szi,szj,nz), Tyy(szi,szj,nz), Txy(szi,szj,nz))
  allocate(mask2dT(szi,szj), mask2dBu(szi,szj), kappa_h(szi,szj), sqr_h(szi,szj), Txy_h(szi,szj))
  allocate(sh_xy_h(szi,szj,nz), vort_xy_h(szi,szj,nz), norm_h(szi,szj,nz), fld(szi,szj,nz), ref(szi,szj,nz))
  print *, 'grid', nih, 'x', njh, 'x', nz, ' cells per layer in the ANN loop', (ie - is + 5) * (je - js + 5)

  ! --- synthesized velocity-gradient fields, O(1e-5 s^-1), the same values in every precision
  seed = 12345
""")
rep("""  subroutine make_field(f, a, b, c)
    real(8), intent(out) :: f(szi,szj,nz)
""", """  subroutine make_field(f, a, b, c)
    real(8), intent(out) :: f(:,:,:)
""")
rep("end program zb_host", "end program zb_host_rt")
open('zb_host_rt.f90', 'w').write(s); print('wrote zb_host_rt.f90')
