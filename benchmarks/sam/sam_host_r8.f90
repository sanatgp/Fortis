! SAM neural-network convection host, transcribed from nn_convection_flux.f90 of
! Yuval and O'Gorman (2020), github.com/yaniyuval/Neural_nework_parameterization.
! The inline matmul network of the original is the call mlp_forward(features, outputs);
! everything around it, feature packing, normalization, output de-scaling by group,
! flux limiters, tendencies, precipitation and clamps, is as in the original.
program sam_host
  implicit none
  integer, parameter :: rk = 8
  interface
     subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
       import :: rk
       real(rk) :: x(*)
       real(rk) :: y(*)
     end subroutine
  end interface
  integer, parameter :: nx = 72, ny = 45, nzm = 48, nrf = 30, nrfq = 29, input_ver_dim = 30
  integer, parameter :: n_in = 61, n_out = 148, o_var_dim = 5, nsteps = 100
  integer, parameter :: jt = 68, ny_gl = 180, YES3D = 1
  real(rk), parameter :: dy = 96000., dtn = 20., cp = 1004.
  real(rk), parameter :: fac_cond = 2.5104e6 / cp, fac_fus = 0.3336e6 / cp
  real(rk), parameter :: tprmin = 268.16, a_pr = 1. / (283.16 - 268.16)
  real(rk) :: t(nx,ny,nzm), q(nx,ny,nzm), tabs(nx,ny,nzm), qn(nx,ny,nzm), t_i(nx,ny,nzm), q_i(nx,ny,nzm)
  real(rk) :: precsfc(nx,ny), prec_xy(nx,ny), t0f(nx,ny,nzm)
  real(rk) :: xscale_mean(n_in), xscale_stnd(n_in), yscale_mean(o_var_dim), yscale_stnd(o_var_dim)
  real(rk) :: dz, adz(nzm), rho(nzm), irhoadz(nzm), irhoadzdz(nzm), rev_dz
  real(rk) :: features(n_in), outputs(n_out)
  real(rk), dimension(nrf) :: t_tendency_adv, q_tendency_adv, q_tendency_auto, q_tendency_sed, t_tendency_auto
  real(rk), dimension(nrf) :: q_flux_sed, t_tendency_sed, q_tend_tot, t_flux_adv, q_flux_adv, t_rad_rest_tend, omp, fac
  real(8) :: buf(nx,ny,nzm), gdz, gadz(nzm), grho(nzm), tref(nx,ny,nzm), qref(nx,ny,nzm), pref(nx,ny), errt, errq
  real(4) :: sbuf(n_in)
  integer :: i, j, k, step, u, dim_counter, out_dim_counter, out_var_control
  integer(8) :: c0, c1, rate
  logical :: have_ref

  open(newunit=u, file="sam_state.bin", access="stream", form="unformatted", status="old")
  read(u) buf; t = real(buf, rk); read(u) buf; q = real(buf, rk); read(u) buf; qn = real(buf, rk); close(u)
  open(newunit=u, file="sam_grid.bin", access="stream", form="unformatted", status="old")
  read(u) gdz; read(u) gadz; read(u) grho; close(u)
  dz = real(gdz, rk); adz = real(gadz, rk); rho = real(grho, rk)
  open(newunit=u, file="sam_scale.bin", access="stream", form="unformatted", status="old")
  read(u) sbuf; xscale_mean = real(sbuf, rk); read(u) sbuf; xscale_stnd = real(sbuf, rk)
  read(u) sbuf(1:o_var_dim); yscale_mean = real(sbuf(1:o_var_dim), rk); read(u) sbuf(1:o_var_dim); yscale_stnd = real(sbuf(1:o_var_dim), rk)
  close(u)
  tabs = t; precsfc = 0.; prec_xy = 0.; t0f = t

  rev_dz = 1 / dz
  do k = 1, nzm
     irhoadz(k) = dtn / (rho(k) * adz(k))
     irhoadzdz(k) = irhoadz(k) / dz
  end do

  call system_clock(c0, rate)
  do step = 1, nsteps
     if (step == 2) call system_clock(c0)
     t_i = t
     q_i = q
     do j = 1, ny
        do i = 1, nx
           features = 0.
           outputs = 0.
           t_tendency_adv = 0.
           q_tendency_adv = 0.
           q_tendency_auto = 0.
           t_tendency_auto = 0.
           q_tendency_sed = 0.
           t_tendency_sed = 0.
           t_rad_rest_tend = 0.
           q_tend_tot = 0.
           t_flux_adv = 0.
           q_flux_adv = 0.
           q_flux_sed = 0.
           dim_counter = 0
           omp = 0.
           fac = 0.
           ! ---- pack the features: temperature, non-precipitating water, distance from the equator
           features(dim_counter+1:dim_counter+input_ver_dim) = real(t_i(i,j,1:input_ver_dim), rk)
           dim_counter = dim_counter + input_ver_dim
           features(dim_counter+1:dim_counter+input_ver_dim) = real(q_i(i,j,1:input_ver_dim), rk)
           dim_counter = dim_counter + input_ver_dim
           features(dim_counter+1) = real(abs(dy * (j + jt - (ny_gl + YES3D - 1) / 2 - 0.5)), rk)
           dim_counter = dim_counter + 1
           ! ---- normalize
           features = (features - xscale_mean) / xscale_stnd
           ! ---- the network
           call mlp_forward(features, outputs)
           ! ---- de-scale the five output groups
           out_var_control = 1
           t_rad_rest_tend(1:nrf) = (outputs(1:nrf) * yscale_stnd(out_var_control)) + yscale_mean(out_var_control)
           out_dim_counter = nrf
           out_var_control = out_var_control + 1
           t_flux_adv(2:nrf) = (outputs(out_dim_counter+1:out_dim_counter+nrfq) * yscale_stnd(out_var_control)) + yscale_mean(out_var_control)
           out_dim_counter = out_dim_counter + nrfq
           out_var_control = out_var_control + 1
           q_flux_adv(2:nrf) = (outputs(out_dim_counter+1:out_dim_counter+nrfq) * yscale_stnd(out_var_control)) + yscale_mean(out_var_control)
           out_dim_counter = out_dim_counter + nrfq
           out_var_control = out_var_control + 1
           q_tendency_auto(1:nrf) = (outputs(out_dim_counter+1:out_dim_counter+nrf) * yscale_stnd(out_var_control)) + yscale_mean(out_var_control)
           out_dim_counter = out_dim_counter + nrf
           out_var_control = out_var_control + 1
           q_flux_sed(1:nrf) = (outputs(out_dim_counter+1:out_dim_counter+nrf) * yscale_stnd(out_var_control)) + yscale_mean(out_var_control)
           out_dim_counter = out_dim_counter + nrf
           out_var_control = out_var_control + 1
           ! ---- advection surface flux is zero
           t_flux_adv(1) = 0.0
           q_flux_adv(1) = 0.0
           do k = 2, nrf
              if (q_flux_adv(k) .lt. 0) then
                 if (q(i,j,k) .lt. -q_flux_adv(k) * irhoadzdz(k)) then
                    q_flux_adv(k) = -q(i,j,k) / irhoadzdz(k)
                 end if
              else
                 if (q(i,j,k-1) .lt. q_flux_adv(k) * irhoadzdz(k)) then
                    q_flux_adv(k) = q(i,j,k-1) / irhoadzdz(k)
                 end if
              end if
           end do
           do k = 1, nrf-1
              t_tendency_adv(k) = -(t_flux_adv(k+1) - t_flux_adv(k)) * irhoadzdz(k)
              q_tendency_adv(k) = -(q_flux_adv(k+1) - q_flux_adv(k)) * irhoadzdz(k)
           end do
           k = nrf
           t_tendency_adv(k) = -(0.0 - t_flux_adv(k)) * irhoadzdz(k)
           q_tendency_adv(k) = -(0.0 - q_flux_adv(k)) * irhoadzdz(k)
           do k = 1, nrf
              if (q(i,j,k) .lt. -q_tendency_adv(k)) then
                 q_tendency_adv(k) = -q(i,j,k)
              end if
           end do
           t(i,j,1:nrf) = t(i,j,1:nrf) + t_tendency_adv(1:nrf)
           q(i,j,1:nrf) = q(i,j,1:nrf) + q_tendency_adv(1:nrf)
           do k = 1, nrf
              omp(k) = max(0., min(1., (tabs(i,j,k) - tprmin) * a_pr))
              fac(k) = (fac_cond + fac_fus * (1.0 - omp(k)))
              if (q_tendency_auto(k) .lt. 0) then
                 q_tend_tot(k) = min(-q_tendency_auto(k) * dtn, q(i,j,k))
                 q_tend_tot(k) = -q_tend_tot(k)
              else
                 q_tend_tot(k) = q_tendency_auto(k) * dtn
              end if
           end do
           q(i,j,1:nrf) = q(i,j,1:nrf) + q_tend_tot(1:nrf)
           t(i,j,1:nrf) = t(i,j,1:nrf) - q_tend_tot(1:nrf) * fac(1:nrf)
           do k = 2, nrf
              if (q_flux_sed(k) .lt. 0) then
                 if (q(i,j,k) .lt. -q_flux_sed(k) * irhoadzdz(k)) then
                    q_flux_sed(k) = -q(i,j,k) / irhoadzdz(k)
                 end if
              else
                 if (q(i,j,k-1) .lt. q_flux_sed(k) * irhoadzdz(k)) then
                    q_flux_sed(k) = q(i,j,k-1) / irhoadzdz(k)
                 end if
              end if
           end do
           do k = 1, nrf-1
              q_tendency_sed(k) = -(q_flux_sed(k+1) - q_flux_sed(k)) * irhoadzdz(k)
           end do
           k = nrf
           q_tendency_sed(k) = -(0.0 - q_flux_sed(k)) * irhoadzdz(k)
           do k = 1, nrf
              if (q_tendency_sed(k) .lt. 0) then
                 q_tendency_sed(k) = min(-q_tendency_sed(k), q(i,j,k))
                 q_tendency_sed(k) = -q_tendency_sed(k)
              end if
           end do
           t(i,j,1:nrf) = t(i,j,1:nrf) - q_tendency_sed(1:nrf) * (fac_fus + fac_cond)
           q(i,j,1:nrf) = q(i,j,1:nrf) + q_tendency_sed(1:nrf)
           t(i,j,1:nrf) = t(i,j,1:nrf) + t_rad_rest_tend(1:nrf) * dtn
           precsfc(i,j) = precsfc(i,j) - q_flux_sed(1) * dtn * rev_dz
           prec_xy(i,j) = prec_xy(i,j) - q_flux_sed(1) * dtn * rev_dz
           do k = 1, nrf
              precsfc(i,j) = precsfc(i,j) - q_tend_tot(k) * adz(k) * dz * rho(k) * (1 / dz)
              prec_xy(i,j) = prec_xy(i,j) - q_tend_tot(k) * adz(k) * dz * rho(k) * (1 / dz)
           end do
           do k = 1, nrf
              q(i,j,k) = max(0., q(i,j,k))
           end do
           where (qn(i,j,1:nrf) .gt. 0.0)
              qn(i,j,1:nrf) = qn(i,j,1:nrf) + q_tend_tot(1:nrf) + q_tendency_adv(1:nrf) + q_tendency_sed(1:nrf)
           end where
           where (qn(i,j,:) .lt. 0.0)
              qn(i,j,:) = 0.0
           end where
        end do
     end do
  end do
  call system_clock(c1)

  print *, 'per-step ms:', real(c1 - c0) / real(rate) * 1.0e3 / (nsteps - 1)
  print *, 'checksum t:', sum(real(t - t0f, 8)), '  q:', sum(real(q, 8)), '  precip:', sum(real(precsfc, 8))
  open(newunit=u, file="sam_out.bin", access="stream", form="unformatted", status="replace")
  write(u) real(t - t0f, 8); write(u) real(q, 8); write(u) real(precsfc, 8); close(u)
  inquire(file="sam_ref.bin", exist=have_ref)
  if (have_ref) then
     open(newunit=u, file="sam_ref.bin", access="stream", form="unformatted", status="old")
     read(u) tref; read(u) qref; read(u) pref; close(u)
     errt = maxval(abs(real(t - t0f, 8) - tref)) / maxval(abs(tref))
     errq = maxval(abs(real(q, 8) - qref)) / maxval(abs(qref))
     print *, 'max rel err vs fp64 reference:  dt', errt, '  q', errq, '  precip', maxval(abs(real(precsfc, 8) - pref)) / maxval(abs(pref))
  end if
end program sam_host
