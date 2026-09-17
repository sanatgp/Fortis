program conv_host
  implicit none
  interface
     subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
       real :: x(*)
       real :: y(*)
     end subroutine
  end interface
  integer, parameter :: nin = 3*16*16*16, nout = 8*16*16*16
  real :: x(nin), y(nout)
  integer :: i
  do i = 1, nin
     x(i) = real(i) / nin
  end do
  x = (x - sum(x)/nin) / sqrt(sum((x - sum(x)/nin)**2)/nin)
  call mlp_forward(x, y)
  print *, 'fortis:    checksum', sum(y), ' y(1:4)', y(1:4)
end program conv_host
