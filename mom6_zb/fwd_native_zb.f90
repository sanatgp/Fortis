! The ANN as shipped in MOM_ANN.F90 (m2lines/MOM6): ANN_apply with Layer_apply loops and ReLU,
! on the CPU, with the per-call allocation of the original.  rk = 4 is single precision;
! rk = 8 is the fp64 reference (MOM6's own precision).
module fwd_native_zb_mod
  implicit none
  integer, parameter :: rk = RKVAL
  integer, parameter :: n_in = 27, n_h = 20, n_out = 3
  real(rk), allocatable :: A0(:,:), b0(:), A1(:,:), b1(:), input_norms(:), output_norms(:)
  logical :: loaded = .false.
contains
  subroutine load()
    real(4), allocatable :: w(:,:), b(:)
    integer :: u
    allocate(A0(n_h,n_in), b0(n_h), A1(n_out,n_h), b1(n_out), input_norms(n_in), output_norms(n_out))
    open(newunit=u, file="zb_nn.bin", access="stream", form="unformatted", status="old")
    allocate(w(n_h,n_in), b(n_h)); read(u) w; A0 = real(w, rk); read(u) b; b0 = real(b, rk); deallocate(w, b)
    allocate(w(n_out,n_h), b(n_out)); read(u) w; A1 = real(w, rk); read(u) b; b1 = real(b, rk); deallocate(w, b)
    allocate(b(n_in)); read(u) b; input_norms = real(b, rk); deallocate(b)
    allocate(b(n_out)); read(u) b; output_norms = real(b, rk); deallocate(b)
    close(u)
    loaded = .true.
  end subroutine

  pure function activation_fn(x) result (y)
    real(rk), intent(in)  :: x
    real(rk) :: y
    y = max(x, 0.0_rk)
  end function activation_fn

  subroutine Layer_apply(x, y, A, b, activation, input_width, output_width)
    integer, intent(in) :: input_width, output_width
    real(rk), intent(in) :: x(input_width), A(output_width, input_width), b(output_width)
    real(rk), intent(out) :: y(output_width)
    logical, intent(in) :: activation
    integer :: i, j
    y(:) = 0.
    do i=1,input_width
      do j=1,output_width
        y(j) = y(j) + ( x(i) * A(j, i) )
      enddo
    enddo
    do j=1,output_width
      y(j) = y(j) + b(j)
      if (activation) then
        y(j) = activation_fn(y(j))
      endif
    enddo
  end subroutine Layer_apply
end module fwd_native_zb_mod

subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
  use fwd_native_zb_mod
  implicit none
  real(rk) :: x(n_in), y(n_out)
  real(rk), allocatable :: x_1(:), x_2(:)
  integer :: i
  if (.not. loaded) call load()
  allocate(x_1(n_in))
  do i = 1,n_in
      x_1(i) = x(i) / input_norms(i)
  enddo
  allocate(x_2(n_h))
  call Layer_apply(x_1, x_2, A0, b0, .true., n_in, n_h)
  deallocate(x_1)
  allocate(x_1(n_h))
  x_1 = x_2
  deallocate(x_2)
  allocate(x_2(n_out))
  call Layer_apply(x_1, x_2, A1, b1, .false., n_h, n_out)
  deallocate(x_1)
  allocate(x_1(n_out))
  x_1 = x_2
  deallocate(x_2)
  do i = 1, n_out
    y(i) = x_1(i) * output_norms(i)
  enddo
  deallocate(x_1)
end subroutine mlp_forward
