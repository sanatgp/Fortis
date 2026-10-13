/* The cluster's netCDF-C was built against a parallel HDF5 but is paired with a serial one.
   These four parallel-I/O property setters are the only references; MOM6 under FMS1 does
   per-rank serial I/O, so they are satisfied as no-ops that report success. */
#include <stdint.h>
int H5Pset_fapl_mpio(int64_t a, int b, int c) { (void)a; (void)b; (void)c; return 0; }
int H5Pset_dxpl_mpio(int64_t a, int b) { (void)a; (void)b; return 0; }
int H5Pset_all_coll_metadata_ops(int64_t a, int b) { (void)a; (void)b; return 0; }
int H5Pset_coll_metadata_write(int64_t a, int b) { (void)a; (void)b; return 0; }
