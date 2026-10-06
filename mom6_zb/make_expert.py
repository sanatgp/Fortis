# zb_host_expert.f90 from zb_host.f90: the per-cell nest hand-batched per layer as in the production
# MOM6 branch (NOAA-GFDL/MOM6 dev/gfdl, ANN_apply_array_sio), everything else identical.
s = open('zb_host.f90').read()
s = s.replace("! replaced by computing the interpolated fields over the halo directly.\nprogram zb_host",
"""! replaced by computing the interpolated fields over the halo directly.
! EXPERT REWRITE: the per-cell call is hand-batched per layer as in the production MOM6 branch
! (NOAA-GFDL/MOM6 dev/gfdl, ANN_apply_array_sio): a pre-loop packs the normalized stencil of
! every cell into column m of xb(27,nij), one call runs the whole layer, and a post-loop
! de-scales and stores.  xb is feature-leading so that one column is one sample.
program zb_host_expert""")
s = s.replace("  real(rk) :: x(3 * stencil_size**2), y(3), input_norm, tmp\n",
"""  integer, parameter :: nij = (ie - is + 5) * (je - js + 5)
  real(rk) :: xb(3 * stencil_size**2, nij), yb(3, nij), yy(3), tmp
  integer :: m
""")
a = s.index("     do k=1,nz\n       do j=js-2,je+2 ; do i=is-2,ie+2\n         x(1:stencil_points)")
b = s.index("       do J=Jsq-1,Jeq+1 ; do I=Isq-1,Ieq+1")
nest = """     do k=1,nz
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

"""
s = s[:a] + nest + s[b:]
s = s.replace("end program zb_host", "end program zb_host_expert")
open('zb_host_expert.f90', 'w').write(s)
m = open('fwd_native_zb.f90').read().split('subroutine mlp_forward(x, y)')[0]
open('fwd_native_zb_mod.f90', 'w').write(m)
print('wrote zb_host_expert.f90 fwd_native_zb_mod.f90')
