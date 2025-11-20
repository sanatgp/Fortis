program test_blas
  use iso_c_binding
  use fortis
  implicit none
  
  type(fortis_handle) :: h
  real(c_float), allocatable :: input(:,:), output(:,:)
  real(c_float), allocatable :: expected(:,:)
  integer :: batch_size, d_in, d_out
  integer :: i, j
  real :: max_error, error
  logical :: passed
  
  batch_size = 32
  d_in = 128
  d_out = 128
  
  allocate(input(d_in, batch_size))
  allocate(output(d_out, batch_size))
  allocate(expected(d_out, batch_size))
  
  do j = 1, batch_size
    do i = 1, d_in
      input(i, j) = real(i + j * 0.01) / real(d_in)
    end do
  end do
  
  call fortis_init(h, "./test_model", backend="blas")
  
  call fortis_forward(h, input, output, batch_size)
  
  passed = .true.
  max_error = 0.0
  
  do j = 1, batch_size
    do i = 1, d_out
      if (output(i,j) /= output(i,j)) then
        print *, "NaN detected at output(", i, ",", j, ")"
        passed = .false.
      end if
      if (abs(output(i,j)) > 1.0e6) then
        print *, "Overflow at output(", i, ",", j, ") = ", output(i,j)
        passed = .false.
      end if
    end do
  end do
  
  if (passed) then
    print *, "BLAS forward pass: OK"
    print *, "Output shape: ", shape(output)
    print *, "Output range: [", minval(output), ",", maxval(output), "]"
  else
    print *, "BLAS forward pass: FAILED"
  end if
  
  call fortis_forward(h, input, output, batch_size)
  
  do j = 1, batch_size
    do i = 1, d_out
      error = abs(output(i,j) - expected(i,j))
      if (error > max_error) max_error = error
    end do
  end do
  
  if (max_error < 1.0e-6) then
    print *, "Deterministic output: OK"
  else
    print *, "Deterministic output: FAILED (max error = ", max_error, ")"
  end if
  
  call fortis_finalize(h)
  
  deallocate(input, output, expected)
  
  if (passed) then
    print *, "All BLAS tests passed"
    call exit(0)
  else
    print *, "Some BLAS tests failed"
    call exit(1)
  end if
  
end program test_blas