program test_blas
  use iso_c_binding
  use fortis
  implicit none
  
  type(fortis_handle) :: h
  real(c_float), allocatable :: input(:,:), output(:,:)
  real(c_float), allocatable :: reference(:,:)
  integer :: batch_size, d_in, d_out
  integer :: i, j, test_count, failed_count
  real :: tolerance, max_diff
  
  batch_size = 32
  d_in = 128
  d_out = 128
  tolerance = 1.0e-5
  test_count = 0
  failed_count = 0
  
  allocate(input(d_in, batch_size))
  allocate(output(d_out, batch_size))
  allocate(reference(d_out, batch_size))
  
  call fortis_init(h, "./test_model", backend="blas")
  
  test_count = test_count + 1
  do j = 1, batch_size
    do i = 1, d_in
      input(i, j) = real(i + j * 0.01) / real(d_in)
    end do
  end do
  
  call fortis_forward(h, input, output, batch_size)
  
  if (any(output /= output)) then
    print *, "TEST FAILED: NaN detected in output"
    failed_count = failed_count + 1
  else if (any(abs(output) > 1.0e6)) then
    print *, "TEST FAILED: Overflow detected"
    failed_count = failed_count + 1
  else
    print *, "TEST PASSED: Forward pass stability"
  end if
  
  test_count = test_count + 1
  reference = output
  call fortis_forward(h, input, output, batch_size)
  
  max_diff = maxval(abs(output - reference))
  if (max_diff > tolerance) then
    print *, "TEST FAILED: Non-deterministic output, max diff = ", max_diff
    failed_count = failed_count + 1
  else
    print *, "TEST PASSED: Deterministic execution"
  end if
  
  test_count = test_count + 1
  input = 0.0
  call fortis_forward(h, input, output, batch_size)
  
  if (all(abs(output - output(1,1)) < tolerance)) then
    print *, "TEST PASSED: Zero input consistency"
  else
    print *, "TEST FAILED: Inconsistent zero input response"
    failed_count = failed_count + 1
  end if
  
  test_count = test_count + 1
  do i = 1, 10
    batch_size = 2**i
    if (allocated(input)) deallocate(input)
    if (allocated(output)) deallocate(output)
    
    allocate(input(d_in, batch_size))
    allocate(output(d_out, batch_size))
    
    input = 0.5
    call fortis_forward(h, input, output, batch_size)
    
    if (any(output /= output)) then
      print *, "TEST FAILED: Batch size ", batch_size
      failed_count = failed_count + 1
      exit
    end if
  end do
  print *, "TEST PASSED: Variable batch sizes"
  
  test_count = test_count + 1
  batch_size = 1
  deallocate(input, output)
  allocate(input(d_in, batch_size))
  allocate(output(d_out, batch_size))
  
  input(:,1) = [(real(i)/real(d_in), i=1,d_in)]
  call fortis_forward(h, input, output, batch_size)
  
  if (norm2(output) > 0.0 .and. norm2(output) < 1.0e6) then
    print *, "TEST PASSED: Single sample inference"
  else
    print *, "TEST FAILED: Single sample output invalid"
    failed_count = failed_count + 1
  end if
  
  call fortis_finalize(h)
  
  deallocate(input, output, reference)
  
  print *, ""
  print *, "Summary: ", test_count - failed_count, "/", test_count, " tests passed"
  
  if (failed_count == 0) then
    call exit(0)
  else
    call exit(1)
  end if
  
end program test_blas