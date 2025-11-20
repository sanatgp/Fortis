program test_mpi
  use iso_c_binding
  use mpi
  use fortis
  implicit none
  
  type(fortis_handle) :: h
  real(c_float), allocatable :: input(:,:), output(:,:)
  real(c_float), allocatable :: all_outputs(:,:,:)
  integer :: ierr, rank, nranks, comm
  integer :: batch_size, d_in, d_out
  integer :: i, j, r
  real :: local_sum, global_sum
  logical :: passed
  
  call MPI_Init(ierr)
  comm = MPI_COMM_WORLD
  call MPI_Comm_rank(comm, rank, ierr)
  call MPI_Comm_size(comm, nranks, ierr)
  
  batch_size = 16
  d_in = 128
  d_out = 128
  
  allocate(input(d_in, batch_size))
  allocate(output(d_out, batch_size))
  
  do j = 1, batch_size
    do i = 1, d_in
      input(i, j) = real(rank * batch_size + j) / real(nranks * batch_size)
    end do
  end do
  
  call fortis_init(h, "./test_model", backend="blas", mpi_comm=comm)
  
  if (rank == 0) then
    print *, "Testing with ", nranks, " MPI ranks"
  end if
  
  call fortis_forward(h, input, output, batch_size)
  
  local_sum = sum(output)
  call MPI_Reduce(local_sum, global_sum, 1, MPI_REAL, MPI_SUM, 0, comm, ierr)
  
  if (rank == 0) then
    print *, "Global output sum across all ranks: ", global_sum
  end if
  
  if (rank == 0) then
    allocate(all_outputs(d_out, batch_size, nranks))
  end if
  
  call MPI_Gather(output, d_out * batch_size, MPI_REAL, &
                  all_outputs, d_out * batch_size, MPI_REAL, &
                  0, comm, ierr)
  
  if (rank == 0) then
    passed = .true.
    do r = 1, nranks
      do j = 1, batch_size
        do i = 1, d_out
          if (all_outputs(i,j,r) /= all_outputs(i,j,r)) then
            print *, "NaN detected from rank ", r-1
            passed = .false.
          end if
        end do
      end do
    end do
    
    if (passed) then
      print *, "All rank outputs valid: OK"
    else
      print *, "Invalid outputs detected: FAILED"
    end if
    
    deallocate(all_outputs)
  end if
  
  call MPI_Barrier(comm, ierr)
  
  do i = 1, 3
    call fortis_forward(h, input, output, batch_size)
    call MPI_Barrier(comm, ierr)
  end do
  
  if (rank == 0) then
    print *, "Multiple inference calls: OK"
  end if
  
  call fortis_finalize(h)
  
  deallocate(input, output)
  
  call MPI_Barrier(comm, ierr)
  if (rank == 0) then
    print *, "MPI tests completed"
  end if
  
  call MPI_Finalize(ierr)
  
end program test_mpi