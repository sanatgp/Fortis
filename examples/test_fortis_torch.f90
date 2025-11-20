program test_fortis_torch
  use fortis
  use mpi
  implicit none
  type(fortis_handle) :: h
  integer :: ierr, comm, rank, nprocs
  integer, parameter :: nin=8, nout=4, B=3
  real :: x(nin,B), y(nout,B)
  integer :: i, j

  call MPI_Init(ierr)
  comm = MPI_COMM_WORLD
  call MPI_Comm_rank(comm, rank, ierr)
  call MPI_Comm_size(comm, nprocs, ierr)

  do j = 1, B
     do i = 1, nin
        x(i,j) = 0.1*rank + 0.01*((j-1)*nin + i)
     end do
  end do

  call fortis_init(h, "model_dir/torch", "torch", nin, nout, B)
  call fortis_forward(h, x, y, nin, B, nout)

  if (rank == 0) then
     print *, "y(:,1) from rank 0:"
     print "(*(f8.4,1x))", y(:,1)
  end if

  call fortis_finalize(h)
  call MPI_Finalize(ierr)
end program
