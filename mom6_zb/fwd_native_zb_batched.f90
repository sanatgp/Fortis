! Batched CPU forward for the expert host's reference: mlp_forward(xb, yb) over nij columns,
! each column through the shipped ANN_apply semantics.  rk as in fwd_native_zb.f90.
subroutine mlp_forward(x, y) bind(c, name="mlp_forward")
  use fwd_native_zb_mod
  implicit none
  integer, parameter :: nij = 64 * 74
  real(rk) :: x(n_in, nij), y(n_out, nij)
  real(rk) :: h(n_h), x1(n_in)
  integer :: m, i
  if (.not. loaded) call load()
  do m = 1, nij
    do i = 1, n_in
      x1(i) = x(i, m) / input_norms(i)
    enddo
    call Layer_apply(x1, h, A0, b0, .true., n_in, n_h)
    call Layer_apply(h, y(:, m), A1, b1, .false., n_h, n_out)
    do i = 1, n_out
      y(i, m) = y(i, m) * output_norms(i)
    enddo
  enddo
end subroutine mlp_forward
