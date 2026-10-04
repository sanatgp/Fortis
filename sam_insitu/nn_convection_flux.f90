
! neural_net convection emulator

module nn_convection_flux_mod


!----------------------------------------------------------------------
use netcdf
use vars
use grid
use params , only: fac_cond, fac_fus, tprmin, a_pr, cp
implicit none
private


!---------------------------------------------------------------------
!  ---- public interfaces ----

   public  nn_convection_flux, nn_convection_flux_init, check

!-----------------------------------------------------------------------
!   ---- version number ----

 character(len=128) :: version = '$Id: nn_convection_flux.f90,v 1 2017/08 fms Exp $'
 character(len=128) :: tag = '$Name: fez $'

!-----------------------------------------------------------------------
!   ---- local/private data ----

    logical :: do_init=.true.

    integer :: n_in ! Input dim features
    integer :: n_h1 ! hidden dim
    integer :: n_h2 ! hidden dim
    integer :: n_h3 ! hidden dim
    integer :: n_h4 ! hidden dim
    integer :: n_out ! outputs dim
    integer :: nrf  ! number of vertical levels the NN uses
    integer :: nrfq ! number of vertical levels the NN uses
    integer :: it,jt
    integer :: o_var_dim ! number of output variables  (different types)

    real(4), allocatable, dimension(:,:)     :: r_w1
    real(4), allocatable, dimension(:,:)     :: r_w2
    real(4), allocatable, dimension(:,:)     :: r_w3
    real(4), allocatable, dimension(:,:)     :: r_w4
    real(4), allocatable, dimension(:,:)     :: r_w5
    real(4), allocatable, dimension(:)       :: r_b1
    real(4), allocatable, dimension(:)       :: r_b2
    real(4), allocatable, dimension(:)       :: r_b3
    real(4), allocatable, dimension(:)       :: r_b4
    real(4), allocatable, dimension(:)       :: r_b5
    real(4), allocatable, dimension(:)       :: xscale_mean
    real(4), allocatable, dimension(:)       :: xscale_stnd

    real(4), allocatable, dimension(:)       :: z1
    real(4), allocatable, dimension(:)       :: z2
    real(4), allocatable, dimension(:)       :: z3
    real(4), allocatable, dimension(:)       :: z4
    real(4), allocatable, dimension(:)       :: z5

    real(4), allocatable, dimension(:)       :: yscale_mean
    real(4), allocatable, dimension(:)       :: yscale_stnd
    real(8) :: nn_ms = 0.d0
    integer :: nn_calls = 0
    interface
       subroutine nn_core(t, q, tabs, qn, t_i, q_i, precsfc, prec_xy, xm, xs, ym, ys, adz, rho, dz, dtn, jt) bind(c, name="nn_core")
         real(4) :: t(72,45,48), q(72,45,48), tabs(72,45,48), qn(72,45,48), t_i(72,45,48), q_i(72,45,48)
         real(4) :: precsfc(72,45), prec_xy(72,45), xm(61), xs(61), ym(5), ys(5), adz(48), rho(48), dz, dtn
         integer :: jt
       end subroutine
    end interface



!-----------------------------------------------------------------------

contains

!#######################################################################

   subroutine nn_convection_flux_init

!-----------------------------------------------------------------------
!
!        initialization for nn convection
!
!-----------------------------------------------------------------------
integer  unit,io,ierr

! This will be the netCDF ID for the file and data variable.
integer :: ncid
integer :: in_dimid, h1_dimid, out_dimid, single_dimid
integer :: h2_dimid, h3_dimid, h4_dimid
integer :: r_w1_varid, r_w2_varid, r_b1_varid, r_b2_varid
integer :: r_w3_varid, r_w4_varid, r_b3_varid, r_b4_varid
integer :: r_w5_varid, r_b5_varid


integer :: xscale_mean_varid, xscale_stnd_varid
integer :: yscale_mean_varid, yscale_stnd_varid

character(len=256) :: nn_filename
 
      call task_rank_to_index(rank,it,jt)
 

!-------------allocate arrays and read data-------------------------


    if(masterproc)  write(*,*) rf_filename
    nn_filename = rf_filename

! Open the file. NF90_NOWRITE tells netCDF we want read-only access
! Get the varid or dimid for each variable or dimension based on its name.

      call check( nf90_open(     trim(nn_filename),NF90_NOWRITE,ncid ))

      call check( nf90_inq_dimid(ncid, 'N_in', in_dimid))
      call check( nf90_inquire_dimension(ncid, in_dimid, len=n_in))

      call check( nf90_inq_dimid(ncid, 'N_h1', h1_dimid))
      call check( nf90_inquire_dimension(ncid, h1_dimid, len=n_h1))
      call check( nf90_inq_dimid(ncid, 'N_h2', h2_dimid))
      call check( nf90_inquire_dimension(ncid, h2_dimid, len=n_h2))

      call check( nf90_inq_dimid(ncid, 'N_h3', h3_dimid))
      call check( nf90_inquire_dimension(ncid, h3_dimid, len=n_h3))

      call check( nf90_inq_dimid(ncid, 'N_h4', h4_dimid))
      call check( nf90_inquire_dimension(ncid, h4_dimid, len=n_h4)) 
      call check( nf90_inq_dimid(ncid, 'N_out', out_dimid))
      call check( nf90_inquire_dimension(ncid, out_dimid, len=n_out))

      call check( nf90_inq_dimid(ncid, 'N_out_dim', out_dimid))
      call check( nf90_inquire_dimension(ncid, out_dimid, len=o_var_dim)) 

     print *, 'size of features', n_in
     print *, 'size of outputs', n_out

     nrf = 30 ! Size in the vertical 
     nrfq = 29 !Size in the vertical  for advection

      call check( nf90_open(     trim(nn_filename),NF90_NOWRITE,ncid ))

      allocate(r_w1(n_in,n_h1))
      allocate(r_w2(n_h1,n_h2))
      allocate(r_w3(n_h2,n_h3))
      allocate(r_w4(n_h3,n_h4))
      allocate(r_w5(n_h4,n_out))

      allocate(r_b1(n_h1))
      allocate(r_b2(n_h2))
      allocate(r_b3(n_h3))
      allocate(r_b4(n_h4))
      allocate(r_b5(n_out))
      allocate(z1(n_h1))
      allocate(z2(n_h2))
      allocate(z3(n_h3))
      allocate(z4(n_h4))
      allocate(z5(n_out))

     
      allocate(xscale_mean(n_in))
      allocate(xscale_stnd(n_in))

      allocate(yscale_mean(o_var_dim))
      allocate(yscale_stnd(o_var_dim))

      call check( nf90_inq_varid(ncid, "w1", r_w1_varid))
      call check( nf90_get_var(ncid, r_w1_varid, r_w1))
      call check( nf90_inq_varid(ncid, "w2", r_w2_varid))
      call check( nf90_get_var(ncid, r_w2_varid, r_w2))

      call check( nf90_inq_varid(ncid, "w3", r_w3_varid))
      call check( nf90_get_var(ncid, r_w3_varid, r_w3))
      call check( nf90_inq_varid(ncid, "w4", r_w4_varid))
      call check( nf90_get_var(ncid, r_w4_varid, r_w4))

      call check( nf90_inq_varid(ncid, "w5", r_w5_varid))
      call check( nf90_get_var(ncid, r_w5_varid, r_w5))

      call check( nf90_inq_varid(ncid, "b1", r_b1_varid))
      call check( nf90_get_var(ncid, r_b1_varid, r_b1))
      call check( nf90_inq_varid(ncid, "b2", r_b2_varid))
      call check( nf90_get_var(ncid, r_b2_varid, r_b2))

      call check( nf90_inq_varid(ncid, "b3", r_b3_varid))
      call check( nf90_get_var(ncid, r_b3_varid, r_b3))
      call check( nf90_inq_varid(ncid, "b4", r_b4_varid))
      call check( nf90_get_var(ncid, r_b4_varid, r_b4))
      call check( nf90_inq_varid(ncid, "b5", r_b5_varid))
      call check( nf90_get_var(ncid, r_b5_varid, r_b5))

      call check( nf90_inq_varid(ncid,"fscale_mean",     xscale_mean_varid))
      call check( nf90_get_var(  ncid, xscale_mean_varid,xscale_mean      ))
      call check( nf90_inq_varid(ncid,"fscale_stnd",     xscale_stnd_varid))
      call check( nf90_get_var(  ncid, xscale_stnd_varid,xscale_stnd      ))

      call check( nf90_inq_varid(ncid,"oscale_mean",     yscale_mean_varid))
      call check( nf90_get_var(  ncid, yscale_mean_varid,yscale_mean      ))
      call check( nf90_inq_varid(ncid,"oscale_stnd",     yscale_stnd_varid))
      call check( nf90_get_var(  ncid, yscale_stnd_varid,yscale_stnd      ))

    
! Close the file
      call check( nf90_close(ncid))

      write(*, *) 'Finished reading NN regression file.'

      do_init=.false.
   end subroutine nn_convection_flux_init


!#######################################################################

   subroutine nn_convection_flux
   integer(8) :: c0, c1, rate
   if (do_init) call error_mesg('nn_convection_flux_init has not been called.')
   if (.not. rf_uses_qp) then
    if(mod(nstep-1,nstatis).eq.0.and.icycle.eq.1) precsfc(:,:)=0.
   end if
   call system_clock(c0, rate)
   call nn_core(t(1:nx,1:ny,:), q(1:nx,1:ny,:), tabs, qn, t_i, q_i, precsfc, prec_xy, &
                xscale_mean, xscale_stnd, yscale_mean, yscale_stnd, adz, rho, dz, dtn, jt)
   call system_clock(c1)
   nn_ms = nn_ms + real(c1 - c0, 8) / real(rate, 8) * 1.0d3
   nn_calls = nn_calls + 1
   if (masterproc .and. nstep .eq. nstop .and. icycle .eq. ncycle) print *, 'nn_core ms per call (rank 0):', nn_ms / nn_calls, ' calls:', nn_calls

   end subroutine nn_convection_flux





!#######################################################################


!##############################################################################
  subroutine check(status)

    ! checks error status after each netcdf, prints out text message each time
    !   an error code is returned. 

    integer, intent(in) :: status

    if(status /= nf90_noerr) then
       write(*, *) trim(nf90_strerror(status))
    end if
  end subroutine check

!#######################################################################
 subroutine error_mesg (message)
  character(len=*), intent(in) :: message

!  input:
!      message   message written to output   (character string)

    if(masterproc) print*, 'Neural network  module: ', message
    stop

 end subroutine error_mesg



!#######################################################################


end module nn_convection_flux_mod

