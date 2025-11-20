
# === tests/test_mpi.f90 ===
program test_mpi
  use mpi
  use fortis_mpi
  implicit none
  integer :: ierr, rank, nodecomm
  call MPI_Init(ierr)
  call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)
  call fortis_node_comm(MPI_COMM_WORLD, nodecomm)
  if (fortis_is_node_leader(nodecomm)) print *, 'Node leader rank', rank
  call MPI_Finalize(ierr)
end program test_mpi
