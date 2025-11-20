module fortis
  use iso_c_binding
  implicit none
  private

  public :: fortis_handle
  public :: fortis_init
  public :: fortis_forward
  public :: fortis_finalize

  type :: fortis_handle
    private
    type(c_ptr) :: model_ptr = c_null_ptr
    character(len=32) :: backend = "blas"
    integer :: comm = -1
    integer :: rank = 0
    integer :: nranks = 1
    logical :: is_initialized = .false.
    integer :: d_in = 0
    integer :: d_out = 0
    integer :: h1 = 0
    integer :: h2 = 0
    logical :: is_node_leader = .false.
  end type fortis_handle

contains

  subroutine fortis_init(handle, model_dir, backend, mpi_comm)
    type(fortis_handle), intent(out) :: handle
    character(len=*), intent(in) :: model_dir
    character(len=*), intent(in), optional :: backend
    integer, intent(in), optional :: mpi_comm

    handle%is_initialized = .false.
    
    if (present(backend)) then
      handle%backend = backend
    else
      handle%backend = "blas"
    end if

    if (present(mpi_comm)) then
      handle%comm = mpi_comm
      call setup_mpi_info(handle)
    end if

    select case(handle%backend)
    case("blas")
      call init_blas_backend(handle, model_dir)
    case("torch", "libtorch")
      call init_torch_backend(handle, model_dir)
    case default
      stop "Unknown backend"
    end select

    handle%is_initialized = .true.
  end subroutine fortis_init

  subroutine setup_mpi_info(handle)
    use fortis_mpi, only: mpi_get_node_info
    type(fortis_handle), intent(inout) :: handle
    call mpi_get_node_info(handle%comm, handle%rank, handle%nranks, handle%is_node_leader)
  end subroutine setup_mpi_info

  subroutine fortis_forward(handle, input, output, batch_size)
    type(fortis_handle), intent(inout) :: handle
    real(c_float), intent(in) :: input(:,:)
    real(c_float), intent(out) :: output(:,:)
    integer, intent(in) :: batch_size

    if (.not. handle%is_initialized) stop "FORTIS not initialized"

    select case(handle%backend)
    case("blas")
      call forward_blas(handle, input, output, batch_size)
    case("torch", "libtorch")
      call forward_torch(handle, input, output, batch_size)
    end select
  end subroutine fortis_forward

  subroutine fortis_finalize(handle)
    type(fortis_handle), intent(inout) :: handle

    if (.not. handle%is_initialized) return

    select case(handle%backend)
    case("blas")
      call finalize_blas(handle)
    case("torch", "libtorch")
      call finalize_torch(handle)
    end select

    handle%is_initialized = .false.
  end subroutine fortis_finalize

  subroutine init_blas_backend(handle, model_dir)
    use fortis_blas, only: blas_init
    type(fortis_handle), intent(inout) :: handle
    character(len=*), intent(in) :: model_dir
    call blas_init(handle, model_dir)
  end subroutine init_blas_backend

  subroutine init_torch_backend(handle, model_dir)
    use fortis_torch, only: torch_init
    type(fortis_handle), intent(inout) :: handle
    character(len=*), intent(in) :: model_dir
    call torch_init(handle, model_dir)
  end subroutine init_torch_backend

  subroutine forward_blas(handle, input, output, batch_size)
    use fortis_blas, only: blas_forward
    type(fortis_handle), intent(inout) :: handle
    real(c_float), intent(in) :: input(:,:)
    real(c_float), intent(out) :: output(:,:)
    integer, intent(in) :: batch_size
    call blas_forward(handle, input, output, batch_size)
  end subroutine forward_blas

  subroutine forward_torch(handle, input, output, batch_size)
    use fortis_torch, only: torch_forward
    type(fortis_handle), intent(inout) :: handle
    real(c_float), intent(in) :: input(:,:)
    real(c_float), intent(out) :: output(:,:)
    integer, intent(in) :: batch_size
    call torch_forward(handle, input, output, batch_size)
  end subroutine forward_torch

  subroutine finalize_blas(handle)
    use fortis_blas, only: blas_finalize
    type(fortis_handle), intent(inout) :: handle
    call blas_finalize(handle)
  end subroutine finalize_blas

  subroutine finalize_torch(handle)
    use fortis_torch, only: torch_finalize
    type(fortis_handle), intent(inout) :: handle
    call torch_finalize(handle)
  end subroutine finalize_torch

end module fortis