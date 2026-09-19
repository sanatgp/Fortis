program v
  implicit none
  interface
     subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
       real :: x(*)
       real :: y(*)
     end subroutine
  end interface
  integer, parameter :: nin = 124, nout = 128, ncol = 384
  real :: x(nin, ncol), y(nout, ncol), yref(nout, ncol), mean(nin), scale(nin), xn(nin), s
  real :: x3(nin, ncol, 2), y3(nout, ncol, 2)
  integer :: j
  logical :: hit(ncol)
  integer :: i, u, step
  integer(8) :: t0, t1, rate
  real :: err, untouched
  open(newunit=u, file="columns.bin", access="stream", form="unformatted"); read(u) x; close(u)
  do i = 1, ncol; x(:,i) = (x(:,i) - 0.0); end do
  open(newunit=u, file="norm.bin", access="stream", form="unformatted"); read(u) mean; read(u) scale; close(u)
  open(newunit=u, file="ref.bin", access="stream", form="unformatted"); read(u) yref; close(u)
  hit = .false.; s = 0.0
  open(newunit=u, file="norm.bin", access="stream", form="unformatted"); read(u) mean; read(u) scale; close(u)
  do i = 1, ncol; x(:,i) = (x(:,i) - mean) / scale; end do

  x3(:,:,1) = x; x3(:,:,2) = x
  call system_clock(t0, rate)
  do step = 1, 100
    y3 = -999.0
    do j = 1, 2
      do i = 1, ncol
        call mlp_forward(x3(:,i,j), y3(:,i,j)); hit(i) = .true.
      end do
    end do
    y = y3(:,:,2)
  end do
  call system_clock(t1)
  err = 0.0; untouched = 0.0
  do i = 1, ncol
     if (hit(i)) then; err = max(err, maxval(abs(y(:,i) - yref(:,i))) / maxval(abs(yref)))
     else; untouched = max(untouched, maxval(abs(y(:,i) + 999.0))); end if
  end do
  print *, 'per-step ms:', real(t1 - t0) / real(rate) * 1.0e3 / 100
  print *, 'iterated', count(hit), ' max rel err:', max(err, maxval(abs(y3(:,:,1) - y3(:,:,2))) / maxval(abs(yref))), ' untouched-columns disturbance:', untouched
end program v
