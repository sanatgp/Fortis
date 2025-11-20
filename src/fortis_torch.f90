program test_torch
  use iso_c_binding
  use fortis
  implicit none
  
  type(fortis_handle) :: h
  real(c_float), allocatable :: input(:,:), output(:,:)
  real(c_float), allocatable :: ref_input(:,:), ref_output(:,:)
  integer :: batch_sizes(5)
  integer :: batch_size, d_in, d_out
  integer :: i, j, idx, test_count, failed_count
  real :: norm_in, norm_out
  
  d_in = 128
  d_out = 128
  batch_sizes = [1, 8, 32, 128, 512]
  test_count = 0
  failed_count = 0
  
  call fortis_init(h, "./test_model", backend="torch")
  
  test_count = test_count + 1
  batch_size = 1
  allocate(input(d_in, batch_size))
  allocate(output(d_out, batch_size))
  
  input(:,1) = [(real(i)/real(d_in), i=1,d_in)]
  call fortis_forward(h, input, output, batch_size)
  
  if (any(output /= output)) then
    print *, "TEST FAILED: NaN in single sample"
    failed_count = failed_count + 1
  else if (norm2(output) == 0.0) then
    print *, "TEST FAILED: Zero output for non-zero input"
    failed_count = failed_count + 1
  else
    print *, "TEST PASSED: Single sample inference"
  end if
  
  deallocate(input, output)
  
  test_count = test_count + 1
  do idx = 1, size(batch_sizes)
    batch_size = batch_sizes(idx)
    
    allocate(input(d_in, batch_size))
    allocate(output(d_out, batch_size))
    
    do j = 1, batch_size
      do i = 1, d_in
        input(i, j) = sin(real(i * j) / real(d_in * batch_size))
      end do
    end do
    
    call fortis_forward(h, input, output, batch_size)
    
    if (any(output /= output)) then
      print *, "TEST FAILED: Batch size ", batch_size, " produced NaN"
      failed_count = failed_count + 1
      deallocate(input, output)
      exit
    end if
    
    deallocate(input, output)
  end do
  
  if (idx > size(batch_sizes)) then
    print *, "TEST PASSED: Multiple batch sizes"
  end if
  
  test_count = test_count + 1
  batch_size = 16
  allocate(input(d_in, batch_size))
  allocate(output(d_out, batch_size))
  allocate(ref_input(d_in, batch_size))
  allocate(ref_output(d_out, batch_size))
  
  ref_input = 0.0
  call fortis_forward(h, ref_input, ref_output, batch_size)
  norm_out = norm2(ref_output)
  
  if (norm_out > 0.0 .and. norm_out < 100.0) then
    print *, "TEST PASSED: Zero input handling"
  else
    print *, "TEST FAILED: Unexpected zero input response"
    failed_count = failed_count + 1
  end if
  
  test_count = test_count + 1
  ref_input = 1.0
  call fortis_forward(h, ref_input, ref_output, batch_size)
  norm_out = norm2(ref_output)
  
  if (norm_out > 0.0 .and. norm_out < 1000.0) then
    print *, "TEST PASSED: Unity input handling"
  else
    print *, "TEST FAILED: Unexpected unity input response"
    failed_count = failed_count + 1
  end if
  
  test_count = test_count + 1
  do j = 1, batch_size
    do i = 1, d_in
      input(i, j) = exp(-real((i-d_in/2)**2) / real(d_in))
    end do
  end do
  
  call fortis_forward(h, input, output, batch_size)
  norm_in = norm2(input)
  norm_out = norm2(output)
  
  if (norm_out > 0.0 .and. norm_out/norm_in < 100.0) then
    print *, "TEST PASSED: Gaussian input handling"
  else
    print *, "TEST FAILED: Output scale mismatch"
    failed_count = failed_count + 1
  end if
  
  test_count = test_count + 1
  do i = 1, 100
    call random_number(input)
    call fortis_forward(h, input, output, batch_size)
    
    if (any(output /= output)) then
      print *, "TEST FAILED: Random input produced NaN at iteration ", i
      failed_count = failed_count + 1
      exit
    end if
  end do
  
  if (i > 100) then
    print *, "TEST PASSED: Random input stress test"
  end if
  
  call fortis_finalize(h)
  
  deallocate(input, output, ref_input, ref_output)
  
  print *, ""
  print *, "Summary: ", test_count - failed_count, "/", test_count, " tests passed"
  
  if (failed_count == 0) then
    call exit(0)
  else
    call exit(1)
  end if
  
end program test_torch