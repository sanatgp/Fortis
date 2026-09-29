! The network as shipped by Yuval and O'Gorman: inline matmul with ReLU, on the CPU.
! rk = 4 is the original single-precision code; rk = 8 is the fp64 reference.
module fwd_native_mod
  implicit none
  integer, parameter :: rk = 4
  integer, parameter :: n_in = 61, n_h = 128, n_out = 148
  real(rk), allocatable :: r_w1(:,:), r_w2(:,:), r_w3(:,:), r_w4(:,:), r_w5(:,:)
  real(rk), allocatable :: r_b1(:), r_b2(:), r_b3(:), r_b4(:), r_b5(:)
  logical :: loaded = .false.
contains
  subroutine load()
    real(4), allocatable :: w(:,:), b(:)
    integer :: u
    allocate(r_w1(n_in,n_h), r_w2(n_h,n_h), r_w3(n_h,n_h), r_w4(n_h,n_h), r_w5(n_h,n_out))
    allocate(r_b1(n_h), r_b2(n_h), r_b3(n_h), r_b4(n_h), r_b5(n_out))
    open(newunit=u, file="sam_nn.bin", access="stream", form="unformatted", status="old")
    allocate(w(n_in,n_h), b(n_h)); read(u) w; r_w1 = real(w, rk); read(u) b; r_b1 = real(b, rk); deallocate(w, b)
    allocate(w(n_h,n_h), b(n_h))
    read(u) w; r_w2 = real(w, rk); read(u) b; r_b2 = real(b, rk)
    read(u) w; r_w3 = real(w, rk); read(u) b; r_b3 = real(b, rk)
    read(u) w; r_w4 = real(w, rk); read(u) b; r_b4 = real(b, rk); deallocate(w, b)
    allocate(w(n_h,n_out), b(n_out)); read(u) w; r_w5 = real(w, rk); read(u) b; r_b5 = real(b, rk); deallocate(w, b)
    close(u)
    loaded = .true.
  end subroutine
end module fwd_native_mod

subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
  use fwd_native_mod
  implicit none
  real(rk) :: x(n_in), y(n_out)
  real(rk) :: z1(n_h), z2(n_h), z3(n_h), z4(n_h)
  if (.not. loaded) call load()
  z1 = matmul(x, r_w1) + r_b1
  where (z1 .lt. 0.0) z1 = 0.0
  z2 = matmul(z1, r_w2) + r_b2
  where (z2 .lt. 0.0) z2 = 0.0
  z3 = matmul(z2, r_w3) + r_b3
  where (z3 .lt. 0.0) z3 = 0.0
  z4 = matmul(z3, r_w4) + r_b4
  where (z4 .lt. 0.0) z4 = 0.0
  y = matmul(z4, r_w5) + r_b5
end subroutine mlp_forward
