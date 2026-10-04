! The Yuval-O'Gorman convection loop as one external unit with explicit-shape arguments.
! Body is nn_convection_flux.f90 as shipped with the inline matmul replaced by the call.
subroutine nn_core(t, q, tabs, qn, t_i, q_i, precsfc, prec_xy, xscale_mean, xscale_stnd, yscale_mean, yscale_stnd, adz, rho, dz, dtn, jt) bind(c, name="nn_core")
  implicit none
  integer, parameter :: rk = 4
  interface
     subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
       import :: rk
       real(rk) :: x(*)
       real(rk) :: y(*)
     end subroutine
  end interface
  integer, parameter :: nx = 72, ny = 45, nzm = 48, nrf = 30, nrfq = 29, input_ver_dim = 30
  integer, parameter :: n_in = 61, n_out = 148, o_var_dim = 5
  integer, parameter :: ny_gl = 180, YES3D = 1
  real(rk), parameter :: dy = 96000., cp = 1004.
  real(rk), parameter :: fac_cond = 2.5104e6 / cp, fac_fus = 0.3336e6 / cp
  real(rk), parameter :: tprmin = 268.16, a_pr = 1. / (283.16 - 268.16)
  real(rk) :: t(nx,ny,nzm), q(nx,ny,nzm), tabs(nx,ny,nzm), qn(nx,ny,nzm), t_i(nx,ny,nzm), q_i(nx,ny,nzm)
  real(rk) :: precsfc(nx,ny), prec_xy(nx,ny)
  real(rk) :: xscale_mean(n_in), xscale_stnd(n_in), yscale_mean(o_var_dim), yscale_stnd(o_var_dim)
  real(rk) :: adz(nzm), rho(nzm), dz, dtn
  integer :: jt
  real(rk) :: irhoadz(nzm), irhoadzdz(nzm), rev_dz
  real(rk) :: features(n_in), outputs(n_out)
  real(rk), dimension(nrf) :: t_tendency_adv, q_tendency_adv, q_tendency_auto, q_tendency_sed, t_tendency_auto
  real(rk), dimension(nrf) :: q_flux_sed, t_tendency_sed, q_tend_tot, t_flux_adv, q_flux_adv, t_rad_rest_tend, omp, fac
  integer :: i, j, k, dim_counter, out_dim_counter, out_var_control

  rev_dz = 1 / dz
  do k = 1, nzm
     irhoadz(k) = dtn / (rho(k) * adz(k))
     irhoadzdz(k) = irhoadz(k) / dz
  end do
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
        features(dim_counter+1:dim_counter+input_ver_dim) = real(t_i(i,j,1:input_ver_dim), rk)
        dim_counter = dim_counter + input_ver_dim
        features(dim_counter+1:dim_counter+input_ver_dim) = real(q_i(i,j,1:input_ver_dim), rk)
        dim_counter = dim_counter + input_ver_dim
        features(dim_counter+1) = real(abs(dy * (j + jt - (ny_gl + YES3D - 1) / 2 - 0.5)), rk)
        dim_counter = dim_counter + 1
        features = (features - xscale_mean) / xscale_stnd
        call mlp_forward(features, outputs)
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
end subroutine nn_core
