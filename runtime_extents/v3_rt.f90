! ClimSim column loop with the column count fixed at run time: ncol is read from ncol.txt and the arrays
! are allocated to it, as in hosts whose column count comes from a namelist or a dummy argument.
! The call takes a per-column temporary, as CAM-GW and SPCAM do.
program v3_rt
  implicit none
  interface
     subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
       real :: x(*)
       real :: y(*)
     end subroutine
  end interface
  integer, parameter :: nin = 124, nout = 128
  integer :: ncol
  real, allocatable :: x(:,:), y(:,:), yref(:,:)
  logical, allocatable :: hit(:)
  real :: mean(nin), scale(nin), xcol(nin), ycol(nout)
  integer :: i, u, step
  integer(8) :: t0, t1, rate
  real :: err
  open(newunit=u, file="ncol.txt", status="old"); read(u, *) ncol; close(u)
  allocate(x(nin, ncol), y(nout, ncol), yref(nout, ncol), hit(ncol))
  open(newunit=u, file="columns.bin", access="stream", form="unformatted"); read(u) x; close(u)
  open(newunit=u, file="norm.bin", access="stream", form="unformatted"); read(u) mean; read(u) scale; close(u)
  open(newunit=u, file="ref.bin", access="stream", form="unformatted"); read(u) yref; close(u)
  hit = .false.
  do i = 1, ncol; x(:,i) = (x(:,i) - mean) / scale; end do
  print *, 'ncol', ncol

  call system_clock(t0, rate)
  do step = 1, 1000
    if (step == 2) call system_clock(t0)
    if (step == 1000) y = -999.0
    do i = 1, ncol
      xcol = x(:,i)
      call mlp_forward(xcol, ycol)
      y(:,i) = ycol
      hit(i) = .true.
    end do
  end do
  call system_clock(t1)
  err = 0.0
  do i = 1, ncol
     if (hit(i)) err = max(err, maxval(abs(y(:,i) - yref(:,i))) / maxval(abs(yref)))
  end do
  print *, 'per-step ms:', real(t1 - t0) / real(rate) * 1.0e3 / 999
  print *, 'iterated', count(hit), ' max rel err:', err
end program v3_rt
