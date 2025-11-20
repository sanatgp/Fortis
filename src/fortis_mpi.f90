program test_mpi
  use iso_c_binding
  use mpi
  use fortis
  implicit none
  
  type(fortis_handle) :: h
  real(c_float), allocatable :: input(:,:), output(:,:)
  real(c_float), allocatable :: all_outputs(:,:,:)
  real(c_float), allocatable :: rank_sums(:)
  integer :: ierr, rank, nranks, comm
  integer :: batch_size, d_in, d_out
  integer :: i, j, r, test_count, failed_count
  integer :: local_failed, global_failed
  real :: local_sum, global_sum, expected_sum
  real :: local_min, local_max, global_min, global_max
  
  call MPI_Init(ierr)
  comm = MPI_COMM_WORLD
  call MPI_Comm_rank(comm, rank, ierr)
  call MPI_Comm_size(comm, nranks, ierr)
  
  batch_size = 16
  d_in = 128
  d_out = 128
  test_count = 0
  failed_count = 0
  
  allocate(input(d_in, batch_size))
  allocate(output(d_out, batch_size))
  
  if (rank == 0) then
    print *, "Running MPI tests with ", nranks, " ranks"
  end if
  
  call fortis_init(h, "./test_model", backend="blas", mpi_comm=comm)
  
  test_count = test_count + 1
  do j = 1, batch_size
    do i = 1, d_in
      input(i, j) = real(rank * batch_size + j) / real(nranks * batch_size)
    end do
  end do
  
  call fortis_forward(h, input, output, batch_size)
  
  local_failed = 0
  if (any(output /= output)) local_failed = 1
  call MPI_Allreduce(local_failed, global_failed, 1, MPI_INTEGER, MPI_SUM, comm, ierr)
  
  if (rank == 0) then
    if (global_failed == 0) then
      print *, "TEST PASSED: All ranks produced valid outputs"
    else
      print *, "TEST FAILED: ", global_failed, " ranks produced NaN"
      failed_count = failed_count + 1
    end if
  end if
  
  test_count = test_count + 1
  local_sum = sum(output)
  call MPI_Reduce(local_sum, global_sum, 1, MPI_REAL, MPI_SUM, 0, comm, ierr)
  
  if (rank == 0) then
    if (abs(global_sum) < 1.0e6) then
      print *, "TEST PASSED: Global sum reasonable (", global_sum, ")"
    else
      print *, "TEST FAILED: Global sum overflow"
      failed_count = failed_count + 1
    end if
  end if
  
  test_count = test_count + 1
  local_min = minval(output)
  local_max = maxval(output)
  call MPI_Reduce(local_min, global_min, 1, MPI_REAL, MPI_MIN, 0, comm, ierr)
  call MPI_Reduce(local_max, global_max, 1, MPI_REAL, MPI_MAX, 0, comm, ierr)
  
  if (rank == 0) then
    if (global_min > -1.0e6 .and. global_max < 1.0e6) then
      print *, "TEST PASSED: Output range [", global_min, ",", global_max, "]"
    else
      print *, "TEST FAILED: Output range invalid"
      failed_count = failed_count + 1
    end if
  end if
  
  test_count = test_count + 1
  if (rank == 0) then
    allocate(all_outputs(d_out, batch_size, nranks))
    allocate(rank_sums(nranks))
  end if
  
  call MPI_Gather(output, d_out * batch_size, MPI_REAL, &
                  all_outputs, d_out * batch_size, MPI_REAL, &
                  0, comm, ierr)
  
  if (rank == 0) then
    do r = 1, nranks
      rank_sums(r) = sum(all_outputs(:,:,r))
    end do
    
    if (maxval(rank_sums) - minval(rank_sums) < 1000.0) then
      print *, "TEST PASSED: Rank output consistency"
    else
      print *, "TEST FAILED: Large variance between ranks"
      failed_count = failed_count + 1
    end if
    
    deallocate(all_outputs, rank_sums)
  end if
  
  test_count = test_count + 1
  call MPI_Barrier(comm, ierr)
  
  do i = 1, 10
    input = real(i * rank) / real(10 * nranks)
    call fortis_forward(h, input, output, batch_size)
    call MPI_Barrier(comm, ierr)
  end do
  
  if (rank == 0) then
    print *, "TEST PASSED: Multiple synchronized calls"
  end if
  
  test_count = test_count + 1
  input = 0.5
  call fortis_forward(h, input, output, batch_size)
  expected_sum = sum(output)
  
  input = 0.5
  call fortis_forward(h, input, output, batch_size)
  
  if (abs(sum(output) - expected_sum) < 1.0e-5) then
    local_failed = 0
  else
    local_failed = 1
  end if
  
  call MPI_Allreduce(local_failed, global_failed, 1, MPI_INTEGER, MPI_SUM, comm, ierr)
  
  if (rank == 0) then
    if (global_failed == 0) then
      print *, "TEST PASSED: Deterministic parallel execution"
    else
      print *, "TEST FAILED: Non-deterministic results"
      failed_count = failed_count + 1
    end if
  end if
  
  call fortis_finalize(h)
  
  deallocate(input, output)
  
  call MPI_Barrier(comm, ierr)
  
  if (rank == 0) then
    print *, ""
    print *, "Summary: ", test_count - failed_count, "/", test_count, " tests passed"
  end if
  
  call MPI_Finalize(ierr)
  
  if (failed_count == 0) then
    call exit(0)
  else
    call exit(1)
  end if
  
end program test_mpi