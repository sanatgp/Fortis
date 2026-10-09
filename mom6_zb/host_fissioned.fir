module attributes {dlti.dl_spec = #dlti.dl_spec<!llvm.ptr<270> = dense<32> : vector<4xi64>, !llvm.ptr<271> = dense<32> : vector<4xi64>, !llvm.ptr<272> = dense<64> : vector<4xi64>, i64 = dense<64> : vector<2xi64>, i128 = dense<128> : vector<2xi64>, f80 = dense<128> : vector<2xi64>, !llvm.ptr = dense<64> : vector<4xi64>, i1 = dense<8> : vector<2xi64>, i8 = dense<8> : vector<2xi64>, i16 = dense<16> : vector<2xi64>, i32 = dense<32> : vector<2xi64>, f16 = dense<16> : vector<2xi64>, f64 = dense<64> : vector<2xi64>, f128 = dense<128> : vector<2xi64>, "dlti.endianness" = "little", "dlti.mangling_mode" = "e", "dlti.legal_int_widths" = array<i32: 8, 16, 32, 64>, "dlti.stack_alignment" = 128 : i64>, fir.defaultkind = "a1c4d8i4l4r4", fir.kindmap = "", fir.relocation_model = 1 : i32, llvm.data_layout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128", llvm.ident = "flang version 24.0.0 (https://github.com/llvm/llvm-project.git 10dbfc4863c9aea2fb237022c3f47fc24c02265e)", llvm.target_triple = "x86_64-unknown-linux-gnu"} {
  func.func @_QQmain() attributes {fir.bindc_name = "ZB_HOST"} {
    %0 = fir.dummy_scope : !fir.dscope
    %1 = fir.address_of(@_QFECamplitude) : !fir.ref<f32>
    %2:2 = hlfir.declare %1 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECamplitude"} : (!fir.ref<f32>) -> (!fir.ref<f32>, !fir.ref<f32>)
    %3 = fir.address_of(@_QFECareat) : !fir.ref<f32>
    %4:2 = hlfir.declare %3 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECareat"} : (!fir.ref<f32>) -> (!fir.ref<f32>, !fir.ref<f32>)
    %5 = fir.alloca i64 {bindc_name = "c0", uniq_name = "_QFEc0"}
    %6:2 = hlfir.declare %5 {uniq_name = "_QFEc0"} : (!fir.ref<i64>) -> (!fir.ref<i64>, !fir.ref<i64>)
    %7 = fir.alloca i64 {bindc_name = "c1", uniq_name = "_QFEc1"}
    %8:2 = hlfir.declare %7 {uniq_name = "_QFEc1"} : (!fir.ref<i64>) -> (!fir.ref<i64>, !fir.ref<i64>)
    %9 = fir.alloca f64 {bindc_name = "err", uniq_name = "_QFEerr"}
    %10:2 = hlfir.declare %9 {uniq_name = "_QFEerr"} : (!fir.ref<f64>) -> (!fir.ref<f64>, !fir.ref<f64>)
    %11 = fir.alloca f64 {bindc_name = "errmax", uniq_name = "_QFEerrmax"}
    %12:2 = hlfir.declare %11 {uniq_name = "_QFEerrmax"} : (!fir.ref<f64>) -> (!fir.ref<f64>, !fir.ref<f64>)
    %13 = fir.address_of(@_QFEfld) : !fir.ref<!fir.array<68x78x15xf64>>
    %c68 = arith.constant 68 : index
    %c78 = arith.constant 78 : index
    %c15 = arith.constant 15 : index
    %14 = fir.shape %c68, %c78, %c15 : (index, index, index) -> !fir.shape<3>
    %15:2 = hlfir.declare %13(%14) {uniq_name = "_QFEfld"} : (!fir.ref<!fir.array<68x78x15xf64>>, !fir.shape<3>) -> (!fir.ref<!fir.array<68x78x15xf64>>, !fir.ref<!fir.array<68x78x15xf64>>)
    %16 = fir.address_of(@_QFEChalo) : !fir.ref<i32>
    %17:2 = hlfir.declare %16 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFEChalo"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %18 = fir.alloca i32 {bindc_name = "i", uniq_name = "_QFEi"}
    %19:2 = hlfir.declare %18 {uniq_name = "_QFEi"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %20 = fir.address_of(@_QFECie) : !fir.ref<i32>
    %21:2 = hlfir.declare %20 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECie"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %22 = fir.address_of(@_QFECieq) : !fir.ref<i32>
    %23:2 = hlfir.declare %22 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECieq"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %24 = fir.alloca i32 {bindc_name = "ii", uniq_name = "_QFEii"}
    %25:2 = hlfir.declare %24 {uniq_name = "_QFEii"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %26 = fir.alloca f32 {bindc_name = "input_norm", uniq_name = "_QFEinput_norm"}
    %27:2 = hlfir.declare %26 {uniq_name = "_QFEinput_norm"} : (!fir.ref<f32>) -> (!fir.ref<f32>, !fir.ref<f32>)
    %28 = fir.alloca i32 {bindc_name = "ios", uniq_name = "_QFEios"}
    %29:2 = hlfir.declare %28 {uniq_name = "_QFEios"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %30 = fir.address_of(@_QFECis) : !fir.ref<i32>
    %31:2 = hlfir.declare %30 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECis"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %32 = fir.address_of(@_QFECisq) : !fir.ref<i32>
    %33:2 = hlfir.declare %32 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECisq"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %34 = fir.alloca i32 {bindc_name = "j", uniq_name = "_QFEj"}
    %35:2 = hlfir.declare %34 {uniq_name = "_QFEj"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %36 = fir.address_of(@_QFECje) : !fir.ref<i32>
    %37:2 = hlfir.declare %36 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECje"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %38 = fir.address_of(@_QFECjeq) : !fir.ref<i32>
    %39:2 = hlfir.declare %38 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECjeq"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %40 = fir.alloca i32 {bindc_name = "jj", uniq_name = "_QFEjj"}
    %41:2 = hlfir.declare %40 {uniq_name = "_QFEjj"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %42 = fir.address_of(@_QFECjs) : !fir.ref<i32>
    %43:2 = hlfir.declare %42 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECjs"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %44 = fir.address_of(@_QFECjsq) : !fir.ref<i32>
    %45:2 = hlfir.declare %44 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECjsq"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %46 = fir.alloca i32 {bindc_name = "k", uniq_name = "_QFEk"}
    %47:2 = hlfir.declare %46 {uniq_name = "_QFEk"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %48 = fir.address_of(@_QFEkappa_h) : !fir.ref<!fir.array<68x78xf32>>
    %c68_0 = arith.constant 68 : index
    %c78_1 = arith.constant 78 : index
    %49 = fir.shape %c68_0, %c78_1 : (index, index) -> !fir.shape<2>
    %50:2 = hlfir.declare %48(%49) {uniq_name = "_QFEkappa_h"} : (!fir.ref<!fir.array<68x78xf32>>, !fir.shape<2>) -> (!fir.ref<!fir.array<68x78xf32>>, !fir.ref<!fir.array<68x78xf32>>)
    %51 = fir.address_of(@_QFEmask2dbu) : !fir.ref<!fir.array<68x78xf32>>
    %c68_2 = arith.constant 68 : index
    %c78_3 = arith.constant 78 : index
    %52 = fir.shape %c68_2, %c78_3 : (index, index) -> !fir.shape<2>
    %53:2 = hlfir.declare %51(%52) {uniq_name = "_QFEmask2dbu"} : (!fir.ref<!fir.array<68x78xf32>>, !fir.shape<2>) -> (!fir.ref<!fir.array<68x78xf32>>, !fir.ref<!fir.array<68x78xf32>>)
    %54 = fir.address_of(@_QFEmask2dt) : !fir.ref<!fir.array<68x78xf32>>
    %c68_4 = arith.constant 68 : index
    %c78_5 = arith.constant 78 : index
    %55 = fir.shape %c68_4, %c78_5 : (index, index) -> !fir.shape<2>
    %56:2 = hlfir.declare %54(%55) {uniq_name = "_QFEmask2dt"} : (!fir.ref<!fir.array<68x78xf32>>, !fir.shape<2>) -> (!fir.ref<!fir.array<68x78xf32>>, !fir.ref<!fir.array<68x78xf32>>)
    %57 = fir.address_of(@_QFECnih) : !fir.ref<i32>
    %58:2 = hlfir.declare %57 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECnih"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %59 = fir.address_of(@_QFECnjh) : !fir.ref<i32>
    %60:2 = hlfir.declare %59 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECnjh"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %61 = fir.address_of(@_QFEnorm_h) : !fir.ref<!fir.array<68x78x15xf32>>
    %c68_6 = arith.constant 68 : index
    %c78_7 = arith.constant 78 : index
    %c15_8 = arith.constant 15 : index
    %62 = fir.shape %c68_6, %c78_7, %c15_8 : (index, index, index) -> !fir.shape<3>
    %63:2 = hlfir.declare %61(%62) {uniq_name = "_QFEnorm_h"} : (!fir.ref<!fir.array<68x78x15xf32>>, !fir.shape<3>) -> (!fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78x15xf32>>)
    %64 = fir.address_of(@_QFECnsteps) : !fir.ref<i32>
    %65:2 = hlfir.declare %64 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECnsteps"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %66 = fir.address_of(@_QFECnz) : !fir.ref<i32>
    %67:2 = hlfir.declare %66 {fortran_attrs = #fir.var_attrs<parameter, internal_assoc>, uniq_name = "_QFECnz"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %68 = fir.address_of(@_QFECoffset) : !fir.ref<i32>
    %69:2 = hlfir.declare %68 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECoffset"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %70 = fir.alloca i64 {bindc_name = "rate", uniq_name = "_QFErate"}
    %71:2 = hlfir.declare %70 {uniq_name = "_QFErate"} : (!fir.ref<i64>) -> (!fir.ref<i64>, !fir.ref<i64>)
    %72 = fir.address_of(@_QFEref) : !fir.ref<!fir.array<68x78x15xf64>>
    %c68_9 = arith.constant 68 : index
    %c78_10 = arith.constant 78 : index
    %c15_11 = arith.constant 15 : index
    %73 = fir.shape %c68_9, %c78_10, %c15_11 : (index, index, index) -> !fir.shape<3>
    %74:2 = hlfir.declare %72(%73) {uniq_name = "_QFEref"} : (!fir.ref<!fir.array<68x78x15xf64>>, !fir.shape<3>) -> (!fir.ref<!fir.array<68x78x15xf64>>, !fir.ref<!fir.array<68x78x15xf64>>)
    %75 = fir.address_of(@_QFECrk) : !fir.ref<i32>
    %76:2 = hlfir.declare %75 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECrk"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %77 = fir.alloca i64 {bindc_name = "seed", uniq_name = "_QFEseed"}
    %78:2 = hlfir.declare %77 {fortran_attrs = #fir.var_attrs<internal_assoc>, uniq_name = "_QFEseed"} : (!fir.ref<i64>) -> (!fir.ref<i64>, !fir.ref<i64>)
    %79 = fir.address_of(@_QFEsh_xx) : !fir.ref<!fir.array<68x78x15xf32>>
    %c68_12 = arith.constant 68 : index
    %c78_13 = arith.constant 78 : index
    %c15_14 = arith.constant 15 : index
    %80 = fir.shape %c68_12, %c78_13, %c15_14 : (index, index, index) -> !fir.shape<3>
    %81:2 = hlfir.declare %79(%80) {uniq_name = "_QFEsh_xx"} : (!fir.ref<!fir.array<68x78x15xf32>>, !fir.shape<3>) -> (!fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78x15xf32>>)
    %82 = fir.address_of(@_QFEsh_xy) : !fir.ref<!fir.array<68x78x15xf32>>
    %c68_15 = arith.constant 68 : index
    %c78_16 = arith.constant 78 : index
    %c15_17 = arith.constant 15 : index
    %83 = fir.shape %c68_15, %c78_16, %c15_17 : (index, index, index) -> !fir.shape<3>
    %84:2 = hlfir.declare %82(%83) {uniq_name = "_QFEsh_xy"} : (!fir.ref<!fir.array<68x78x15xf32>>, !fir.shape<3>) -> (!fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78x15xf32>>)
    %85 = fir.address_of(@_QFEsh_xy_h) : !fir.ref<!fir.array<68x78x15xf32>>
    %c68_18 = arith.constant 68 : index
    %c78_19 = arith.constant 78 : index
    %c15_20 = arith.constant 15 : index
    %86 = fir.shape %c68_18, %c78_19, %c15_20 : (index, index, index) -> !fir.shape<3>
    %87:2 = hlfir.declare %85(%86) {uniq_name = "_QFEsh_xy_h"} : (!fir.ref<!fir.array<68x78x15xf32>>, !fir.shape<3>) -> (!fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78x15xf32>>)
    %88 = fir.address_of(@_QFEsqr_h) : !fir.ref<!fir.array<68x78xf32>>
    %c68_21 = arith.constant 68 : index
    %c78_22 = arith.constant 78 : index
    %89 = fir.shape %c68_21, %c78_22 : (index, index) -> !fir.shape<2>
    %90:2 = hlfir.declare %88(%89) {uniq_name = "_QFEsqr_h"} : (!fir.ref<!fir.array<68x78xf32>>, !fir.shape<2>) -> (!fir.ref<!fir.array<68x78xf32>>, !fir.ref<!fir.array<68x78xf32>>)
    %91 = fir.address_of(@_QFECstencil_points) : !fir.ref<i32>
    %92:2 = hlfir.declare %91 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECstencil_points"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %93 = fir.address_of(@_QFECstencil_size) : !fir.ref<i32>
    %94:2 = hlfir.declare %93 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECstencil_size"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %95 = fir.alloca i32 {bindc_name = "step", uniq_name = "_QFEstep"}
    %96:2 = hlfir.declare %95 {uniq_name = "_QFEstep"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %97 = fir.address_of(@_QFECsubroundoff_shear) : !fir.ref<f32>
    %98:2 = hlfir.declare %97 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECsubroundoff_shear"} : (!fir.ref<f32>) -> (!fir.ref<f32>, !fir.ref<f32>)
    %99 = fir.address_of(@_QFECszi) : !fir.ref<i32>
    %100:2 = hlfir.declare %99 {fortran_attrs = #fir.var_attrs<parameter, internal_assoc>, uniq_name = "_QFECszi"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %101 = fir.address_of(@_QFECszj) : !fir.ref<i32>
    %102:2 = hlfir.declare %101 {fortran_attrs = #fir.var_attrs<parameter, internal_assoc>, uniq_name = "_QFECszj"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %103 = fir.alloca f32 {bindc_name = "tmp", uniq_name = "_QFEtmp"}
    %104:2 = hlfir.declare %103 {uniq_name = "_QFEtmp"} : (!fir.ref<f32>) -> (!fir.ref<f32>, !fir.ref<f32>)
    %105 = fir.address_of(@_QFEtxx) : !fir.ref<!fir.array<68x78x15xf32>>
    %c68_23 = arith.constant 68 : index
    %c78_24 = arith.constant 78 : index
    %c15_25 = arith.constant 15 : index
    %106 = fir.shape %c68_23, %c78_24, %c15_25 : (index, index, index) -> !fir.shape<3>
    %107:2 = hlfir.declare %105(%106) {uniq_name = "_QFEtxx"} : (!fir.ref<!fir.array<68x78x15xf32>>, !fir.shape<3>) -> (!fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78x15xf32>>)
    %108 = fir.address_of(@_QFEtxy) : !fir.ref<!fir.array<68x78x15xf32>>
    %c68_26 = arith.constant 68 : index
    %c78_27 = arith.constant 78 : index
    %c15_28 = arith.constant 15 : index
    %109 = fir.shape %c68_26, %c78_27, %c15_28 : (index, index, index) -> !fir.shape<3>
    %110:2 = hlfir.declare %108(%109) {uniq_name = "_QFEtxy"} : (!fir.ref<!fir.array<68x78x15xf32>>, !fir.shape<3>) -> (!fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78x15xf32>>)
    %111 = fir.address_of(@_QFEtxy_h) : !fir.ref<!fir.array<68x78xf32>>
    %c68_29 = arith.constant 68 : index
    %c78_30 = arith.constant 78 : index
    %112 = fir.shape %c68_29, %c78_30 : (index, index) -> !fir.shape<2>
    %113:2 = hlfir.declare %111(%112) {uniq_name = "_QFEtxy_h"} : (!fir.ref<!fir.array<68x78xf32>>, !fir.shape<2>) -> (!fir.ref<!fir.array<68x78xf32>>, !fir.ref<!fir.array<68x78xf32>>)
    %114 = fir.address_of(@_QFEtyy) : !fir.ref<!fir.array<68x78x15xf32>>
    %c68_31 = arith.constant 68 : index
    %c78_32 = arith.constant 78 : index
    %c15_33 = arith.constant 15 : index
    %115 = fir.shape %c68_31, %c78_32, %c15_33 : (index, index, index) -> !fir.shape<3>
    %116:2 = hlfir.declare %114(%115) {uniq_name = "_QFEtyy"} : (!fir.ref<!fir.array<68x78x15xf32>>, !fir.shape<3>) -> (!fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78x15xf32>>)
    %117 = fir.alloca i32 {bindc_name = "u", uniq_name = "_QFEu"}
    %118:2 = hlfir.declare %117 {uniq_name = "_QFEu"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %119 = fir.address_of(@_QFEvort_xy) : !fir.ref<!fir.array<68x78x15xf32>>
    %c68_34 = arith.constant 68 : index
    %c78_35 = arith.constant 78 : index
    %c15_36 = arith.constant 15 : index
    %120 = fir.shape %c68_34, %c78_35, %c15_36 : (index, index, index) -> !fir.shape<3>
    %121:2 = hlfir.declare %119(%120) {uniq_name = "_QFEvort_xy"} : (!fir.ref<!fir.array<68x78x15xf32>>, !fir.shape<3>) -> (!fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78x15xf32>>)
    %122 = fir.address_of(@_QFEvort_xy_h) : !fir.ref<!fir.array<68x78x15xf32>>
    %c68_37 = arith.constant 68 : index
    %c78_38 = arith.constant 78 : index
    %c15_39 = arith.constant 15 : index
    %123 = fir.shape %c68_37, %c78_38, %c15_39 : (index, index, index) -> !fir.shape<3>
    %124:2 = hlfir.declare %122(%123) {uniq_name = "_QFEvort_xy_h"} : (!fir.ref<!fir.array<68x78x15xf32>>, !fir.shape<3>) -> (!fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78x15xf32>>)
    %125 = fir.address_of(@_QFEx) : !fir.ref<!fir.array<27xf32>>
    %c27 = arith.constant 27 : index
    %126 = fir.shape %c27 : (index) -> !fir.shape<1>
    %127:2 = hlfir.declare %125(%126) {uniq_name = "_QFEx"} : (!fir.ref<!fir.array<27xf32>>, !fir.shape<1>) -> (!fir.ref<!fir.array<27xf32>>, !fir.ref<!fir.array<27xf32>>)
    %c3 = arith.constant 3 : index
    %128 = fir.alloca !fir.array<3xf32> {bindc_name = "y", uniq_name = "_QFEy"}
    %129 = fir.shape %c3 : (index) -> !fir.shape<1>
    %130:2 = hlfir.declare %128(%129) {uniq_name = "_QFEy"} : (!fir.ref<!fir.array<3xf32>>, !fir.shape<1>) -> (!fir.ref<!fir.array<3xf32>>, !fir.ref<!fir.array<3xf32>>)
    %131 = fir.alloca tuple<!fir.ref<i64>>
    %c0_i32 = arith.constant 0 : i32
    %132 = fir.coordinate_of %131, %c0_i32 : (!fir.ref<tuple<!fir.ref<i64>>>, i32) -> !fir.llvm_ptr<!fir.ref<i64>>
    fir.store %78#0 to %132 : !fir.llvm_ptr<!fir.ref<i64>>
    %c12345_i64 = arith.constant 12345 : i64
    hlfir.assign %c12345_i64 to %78#0 : i64, !fir.ref<i64>
    %cst = arith.constant 3.100000e-01 : f64
    %cst_40 = arith.constant 2.300000e-01 : f64
    %cst_41 = arith.constant 1.700000e-01 : f64
    %133:3 = hlfir.associate %cst {adapt.valuebyref} : (f64) -> (!fir.ref<f64>, !fir.ref<f64>, i1)
    %134:3 = hlfir.associate %cst_40 {adapt.valuebyref} : (f64) -> (!fir.ref<f64>, !fir.ref<f64>, i1)
    %135:3 = hlfir.associate %cst_41 {adapt.valuebyref} : (f64) -> (!fir.ref<f64>, !fir.ref<f64>, i1)
    fir.call @_QFPmake_field(%15#0, %133#0, %134#0, %135#0, %131) fastmath<contract> : (!fir.ref<!fir.array<68x78x15xf64>>, !fir.ref<f64>, !fir.ref<f64>, !fir.ref<f64>, !fir.ref<tuple<!fir.ref<i64>>>) -> ()
    hlfir.end_associate %133#1, %133#2 : !fir.ref<f64>, i1
    hlfir.end_associate %134#1, %134#2 : !fir.ref<f64>, i1
    hlfir.end_associate %135#1, %135#2 : !fir.ref<f64>, i1
    %136 = hlfir.elemental %14 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf32> {
    ^bb0(%arg0: index, %arg1: index, %arg2: index):
      %307 = hlfir.designate %15#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf64>>, index, index, index) -> !fir.ref<f64>
      %308 = fir.load %307 : !fir.ref<f64>
      %309 = fir.convert %308 : (f64) -> f32
      hlfir.yield_element %309 : f32
    }
    hlfir.assign %136 to %84#0 : !hlfir.expr<68x78x15xf32>, !fir.ref<!fir.array<68x78x15xf32>>
    hlfir.destroy %136 : !hlfir.expr<68x78x15xf32>
    %cst_42 = arith.constant 2.700000e-01 : f64
    %cst_43 = arith.constant 1.900000e-01 : f64
    %cst_44 = arith.constant 1.300000e-01 : f64
    %137:3 = hlfir.associate %cst_42 {adapt.valuebyref} : (f64) -> (!fir.ref<f64>, !fir.ref<f64>, i1)
    %138:3 = hlfir.associate %cst_43 {adapt.valuebyref} : (f64) -> (!fir.ref<f64>, !fir.ref<f64>, i1)
    %139:3 = hlfir.associate %cst_44 {adapt.valuebyref} : (f64) -> (!fir.ref<f64>, !fir.ref<f64>, i1)
    fir.call @_QFPmake_field(%15#0, %137#0, %138#0, %139#0, %131) fastmath<contract> : (!fir.ref<!fir.array<68x78x15xf64>>, !fir.ref<f64>, !fir.ref<f64>, !fir.ref<f64>, !fir.ref<tuple<!fir.ref<i64>>>) -> ()
    hlfir.end_associate %137#1, %137#2 : !fir.ref<f64>, i1
    hlfir.end_associate %138#1, %138#2 : !fir.ref<f64>, i1
    hlfir.end_associate %139#1, %139#2 : !fir.ref<f64>, i1
    %140 = hlfir.elemental %14 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf32> {
    ^bb0(%arg0: index, %arg1: index, %arg2: index):
      %307 = hlfir.designate %15#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf64>>, index, index, index) -> !fir.ref<f64>
      %308 = fir.load %307 : !fir.ref<f64>
      %309 = fir.convert %308 : (f64) -> f32
      hlfir.yield_element %309 : f32
    }
    hlfir.assign %140 to %81#0 : !hlfir.expr<68x78x15xf32>, !fir.ref<!fir.array<68x78x15xf32>>
    hlfir.destroy %140 : !hlfir.expr<68x78x15xf32>
    %cst_45 = arith.constant 2.900000e-01 : f64
    %cst_46 = arith.constant 2.100000e-01 : f64
    %cst_47 = arith.constant 1.100000e-01 : f64
    %141:3 = hlfir.associate %cst_45 {adapt.valuebyref} : (f64) -> (!fir.ref<f64>, !fir.ref<f64>, i1)
    %142:3 = hlfir.associate %cst_46 {adapt.valuebyref} : (f64) -> (!fir.ref<f64>, !fir.ref<f64>, i1)
    %143:3 = hlfir.associate %cst_47 {adapt.valuebyref} : (f64) -> (!fir.ref<f64>, !fir.ref<f64>, i1)
    fir.call @_QFPmake_field(%15#0, %141#0, %142#0, %143#0, %131) fastmath<contract> : (!fir.ref<!fir.array<68x78x15xf64>>, !fir.ref<f64>, !fir.ref<f64>, !fir.ref<f64>, !fir.ref<tuple<!fir.ref<i64>>>) -> ()
    hlfir.end_associate %141#1, %141#2 : !fir.ref<f64>, i1
    hlfir.end_associate %142#1, %142#2 : !fir.ref<f64>, i1
    hlfir.end_associate %143#1, %143#2 : !fir.ref<f64>, i1
    %144 = hlfir.elemental %14 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf32> {
    ^bb0(%arg0: index, %arg1: index, %arg2: index):
      %307 = hlfir.designate %15#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf64>>, index, index, index) -> !fir.ref<f64>
      %308 = fir.load %307 : !fir.ref<f64>
      %309 = fir.convert %308 : (f64) -> f32
      hlfir.yield_element %309 : f32
    }
    hlfir.assign %144 to %121#0 : !hlfir.expr<68x78x15xf32>, !fir.ref<!fir.array<68x78x15xf32>>
    hlfir.destroy %144 : !hlfir.expr<68x78x15xf32>
    %cst_48 = arith.constant 1.000000e+00 : f32
    hlfir.assign %cst_48 to %56#0 : f32, !fir.ref<!fir.array<68x78xf32>>
    %cst_49 = arith.constant 1.000000e+00 : f32
    hlfir.assign %cst_49 to %53#0 : f32, !fir.ref<!fir.array<68x78xf32>>
    %cst_50 = arith.constant 0.000000e+00 : f32
    %c1 = arith.constant 1 : index
    %c1_51 = arith.constant 1 : index
    %c1_52 = arith.constant 1 : index
    %c78_53 = arith.constant 78 : index
    %145 = fir.shape %c78_53 : (index) -> !fir.shape<1>
    %146 = hlfir.designate %56#0 (%c1, %c1_51:%c78_5:%c1_52)  shape %145 : (!fir.ref<!fir.array<68x78xf32>>, index, index, index, index, !fir.shape<1>) -> !fir.box<!fir.array<78xf32>>
    hlfir.assign %cst_50 to %146 : f32, !fir.box<!fir.array<78xf32>>
    %cst_54 = arith.constant 0.000000e+00 : f32
    %c68_55 = arith.constant 68 : index
    %c1_56 = arith.constant 1 : index
    %c1_57 = arith.constant 1 : index
    %c78_58 = arith.constant 78 : index
    %147 = fir.shape %c78_58 : (index) -> !fir.shape<1>
    %148 = hlfir.designate %56#0 (%c68_55, %c1_56:%c78_5:%c1_57)  shape %147 : (!fir.ref<!fir.array<68x78xf32>>, index, index, index, index, !fir.shape<1>) -> !fir.box<!fir.array<78xf32>>
    hlfir.assign %cst_54 to %148 : f32, !fir.box<!fir.array<78xf32>>
    %cst_59 = arith.constant 0.000000e+00 : f32
    %c1_60 = arith.constant 1 : index
    %c1_61 = arith.constant 1 : index
    %c68_62 = arith.constant 68 : index
    %c1_63 = arith.constant 1 : index
    %149 = fir.shape %c68_62 : (index) -> !fir.shape<1>
    %150 = hlfir.designate %56#0 (%c1_60:%c68_4:%c1_61, %c1_63)  shape %149 : (!fir.ref<!fir.array<68x78xf32>>, index, index, index, index, !fir.shape<1>) -> !fir.ref<!fir.array<68xf32>>
    hlfir.assign %cst_59 to %150 : f32, !fir.ref<!fir.array<68xf32>>
    %cst_64 = arith.constant 0.000000e+00 : f32
    %c1_65 = arith.constant 1 : index
    %c1_66 = arith.constant 1 : index
    %c68_67 = arith.constant 68 : index
    %c78_68 = arith.constant 78 : index
    %151 = fir.shape %c68_67 : (index) -> !fir.shape<1>
    %152 = hlfir.designate %56#0 (%c1_65:%c68_4:%c1_66, %c78_68)  shape %151 : (!fir.ref<!fir.array<68x78xf32>>, index, index, index, index, !fir.shape<1>) -> !fir.ref<!fir.array<68xf32>>
    hlfir.assign %cst_64 to %152 : f32, !fir.ref<!fir.array<68xf32>>
    %cst_69 = arith.constant 0.000000e+00 : f32
    %c1_70 = arith.constant 1 : index
    %c1_71 = arith.constant 1 : index
    %c1_72 = arith.constant 1 : index
    %c78_73 = arith.constant 78 : index
    %153 = fir.shape %c78_73 : (index) -> !fir.shape<1>
    %154 = hlfir.designate %53#0 (%c1_70, %c1_71:%c78_3:%c1_72)  shape %153 : (!fir.ref<!fir.array<68x78xf32>>, index, index, index, index, !fir.shape<1>) -> !fir.box<!fir.array<78xf32>>
    hlfir.assign %cst_69 to %154 : f32, !fir.box<!fir.array<78xf32>>
    %cst_74 = arith.constant 0.000000e+00 : f32
    %c68_75 = arith.constant 68 : index
    %c1_76 = arith.constant 1 : index
    %c1_77 = arith.constant 1 : index
    %c78_78 = arith.constant 78 : index
    %155 = fir.shape %c78_78 : (index) -> !fir.shape<1>
    %156 = hlfir.designate %53#0 (%c68_75, %c1_76:%c78_3:%c1_77)  shape %155 : (!fir.ref<!fir.array<68x78xf32>>, index, index, index, index, !fir.shape<1>) -> !fir.box<!fir.array<78xf32>>
    hlfir.assign %cst_74 to %156 : f32, !fir.box<!fir.array<78xf32>>
    %cst_79 = arith.constant 0.000000e+00 : f32
    %c1_80 = arith.constant 1 : index
    %c1_81 = arith.constant 1 : index
    %c68_82 = arith.constant 68 : index
    %c1_83 = arith.constant 1 : index
    %157 = fir.shape %c68_82 : (index) -> !fir.shape<1>
    %158 = hlfir.designate %53#0 (%c1_80:%c68_2:%c1_81, %c1_83)  shape %157 : (!fir.ref<!fir.array<68x78xf32>>, index, index, index, index, !fir.shape<1>) -> !fir.ref<!fir.array<68xf32>>
    hlfir.assign %cst_79 to %158 : f32, !fir.ref<!fir.array<68xf32>>
    %cst_84 = arith.constant 0.000000e+00 : f32
    %c1_85 = arith.constant 1 : index
    %c1_86 = arith.constant 1 : index
    %c68_87 = arith.constant 68 : index
    %c78_88 = arith.constant 78 : index
    %159 = fir.shape %c68_87 : (index) -> !fir.shape<1>
    %160 = hlfir.designate %53#0 (%c1_85:%c68_2:%c1_86, %c78_88)  shape %159 : (!fir.ref<!fir.array<68x78xf32>>, index, index, index, index, !fir.shape<1>) -> !fir.ref<!fir.array<68xf32>>
    hlfir.assign %cst_84 to %160 : f32, !fir.ref<!fir.array<68xf32>>
    %c1_i32 = arith.constant 1 : i32
    %c78_i32 = arith.constant 78 : i32
    %c1_i32_89 = arith.constant 1 : i32
    fir.do_loop %arg0 = %c1_i32 to %c78_i32 step %c1_i32_89 : i32 {
      fir.store %arg0 to %35#0 : !fir.ref<i32>
      %c1_i32_112 = arith.constant 1 : i32
      %c68_i32 = arith.constant 68 : i32
      %c1_i32_113 = arith.constant 1 : i32
      fir.do_loop %arg1 = %c1_i32_112 to %c68_i32 step %c1_i32_113 : i32 {
        fir.store %arg1 to %19#0 : !fir.ref<i32>
        %cst_115 = arith.constant 6.250000e+08 : f32
        %318 = fir.load %19#0 : !fir.ref<i32>
        %319 = fir.convert %318 : (i32) -> i64
        %320 = fir.load %35#0 : !fir.ref<i32>
        %321 = fir.convert %320 : (i32) -> i64
        %322 = hlfir.designate %56#0 (%319, %321)  : (!fir.ref<!fir.array<68x78xf32>>, i64, i64) -> !fir.ref<f32>
        %323 = fir.load %322 : !fir.ref<f32>
        %324 = arith.mulf %cst_115, %323 fastmath<contract> : f32
        %325 = arith.negf %324 fastmath<contract> : f32
        %326 = fir.load %19#0 : !fir.ref<i32>
        %327 = fir.convert %326 : (i32) -> i64
        %328 = fir.load %35#0 : !fir.ref<i32>
        %329 = fir.convert %328 : (i32) -> i64
        %330 = hlfir.designate %50#0 (%327, %329)  : (!fir.ref<!fir.array<68x78xf32>>, i64, i64) -> !fir.ref<f32>
        hlfir.assign %325 to %330 : f32, !fir.ref<f32>
      }
      %307 = fir.convert %c1_i32_112 : (i32) -> index
      %308 = fir.convert %c68_i32 : (i32) -> index
      %309 = fir.convert %c1_i32_113 : (i32) -> index
      %c0_114 = arith.constant 0 : index
      %310 = arith.subi %308, %307 : index
      %311 = arith.addi %310, %309 : index
      %312 = arith.divsi %311, %309 : index
      %313 = arith.cmpi slt, %312, %c0_114 : index
      %314 = arith.select %313, %c0_114, %312 : index
      %315 = arith.muli %314, %309 : index
      %316 = arith.addi %307, %315 : index
      %317 = fir.convert %316 : (index) -> i32
      fir.store %317 to %19#0 : !fir.ref<i32>
    }
    %161 = fir.convert %c1_i32 : (i32) -> index
    %162 = fir.convert %c78_i32 : (i32) -> index
    %163 = fir.convert %c1_i32_89 : (i32) -> index
    %c0 = arith.constant 0 : index
    %164 = arith.subi %162, %161 : index
    %165 = arith.addi %164, %163 : index
    %166 = arith.divsi %165, %163 : index
    %167 = arith.cmpi slt, %166, %c0 : index
    %168 = arith.select %167, %c0, %166 : index
    %169 = arith.muli %168, %163 : index
    %170 = arith.addi %161, %169 : index
    %171 = fir.convert %170 : (index) -> i32
    fir.store %171 to %35#0 : !fir.ref<i32>
    %cst_90 = arith.constant 0.000000e+00 : f32
    hlfir.assign %cst_90 to %107#0 : f32, !fir.ref<!fir.array<68x78x15xf32>>
    %cst_91 = arith.constant 0.000000e+00 : f32
    hlfir.assign %cst_91 to %116#0 : f32, !fir.ref<!fir.array<68x78x15xf32>>
    %cst_92 = arith.constant 0.000000e+00 : f32
    hlfir.assign %cst_92 to %110#0 : f32, !fir.ref<!fir.array<68x78x15xf32>>
    %cst_93 = arith.constant 0.000000e+00 : f32
    hlfir.assign %cst_93 to %113#0 : f32, !fir.ref<!fir.array<68x78xf32>>
    %c8_i32 = arith.constant 8 : i32
    %172 = fir.call @_FortranASystemClockCount(%c8_i32) fastmath<contract> : (i32) -> i64
    fir.store %172 to %6#0 : !fir.ref<i64>
    %c8_i32_94 = arith.constant 8 : i32
    %173 = fir.call @_FortranASystemClockCountRate(%c8_i32_94) fastmath<contract> : (i32) -> i64
    fir.store %173 to %71#0 : !fir.ref<i64>
    %c1_i32_95 = arith.constant 1 : i32
    %c11_i32 = arith.constant 11 : i32
    %c1_i32_96 = arith.constant 1 : i32
    fir.do_loop %arg0 = %c1_i32_95 to %c11_i32 step %c1_i32_96 : i32 {
      fir.store %arg0 to %96#0 : !fir.ref<i32>
      %307 = fir.load %96#0 : !fir.ref<i32>
      %c2_i32 = arith.constant 2 : i32
      %308 = arith.cmpi eq, %307, %c2_i32 : i32
      fir.if %308 {
        %c8_i32_122 = arith.constant 8 : i32
        %331 = fir.call @_FortranASystemClockCount(%c8_i32_122) fastmath<contract> : (i32) -> i64
        fir.store %331 to %6#0 : !fir.ref<i64>
      }
      %cst_112 = arith.constant 0.000000e+00 : f32
      hlfir.assign %cst_112 to %87#0 : f32, !fir.ref<!fir.array<68x78x15xf32>>
      %cst_113 = arith.constant 0.000000e+00 : f32
      hlfir.assign %cst_113 to %124#0 : f32, !fir.ref<!fir.array<68x78x15xf32>>
      %cst_114 = arith.constant 0.000000e+00 : f32
      hlfir.assign %cst_114 to %63#0 : f32, !fir.ref<!fir.array<68x78x15xf32>>
      %c1_i32_115 = arith.constant 1 : i32
      %c15_i32 = arith.constant 15 : i32
      %c1_i32_116 = arith.constant 1 : i32
      fir.do_loop %arg1 = %c1_i32_115 to %c15_i32 step %c1_i32_116 : i32 {
        fir.store %arg1 to %47#0 : !fir.ref<i32>
        %c2_i32_122 = arith.constant 2 : i32
        %c77_i32 = arith.constant 77 : i32
        %c1_i32_123 = arith.constant 1 : i32
        fir.do_loop %arg2 = %c2_i32_122 to %c77_i32 step %c1_i32_123 : i32 {
          fir.store %arg2 to %35#0 : !fir.ref<i32>
          %c2_i32_127 = arith.constant 2 : i32
          %c67_i32 = arith.constant 67 : i32
          %c1_i32_128 = arith.constant 1 : i32
          fir.do_loop %arg3 = %c2_i32_127 to %c67_i32 step %c1_i32_128 : i32 {
            fir.store %arg3 to %19#0 : !fir.ref<i32>
            %cst_130 = arith.constant 2.500000e-01 : f32
            %364 = fir.load %19#0 : !fir.ref<i32>
            %c1_i32_131 = arith.constant 1 : i32
            %365 = arith.subi %364, %c1_i32_131 overflow<nsw> : i32
            %366 = fir.convert %365 : (i32) -> i64
            %367 = fir.load %35#0 : !fir.ref<i32>
            %c1_i32_132 = arith.constant 1 : i32
            %368 = arith.subi %367, %c1_i32_132 overflow<nsw> : i32
            %369 = fir.convert %368 : (i32) -> i64
            %370 = fir.load %47#0 : !fir.ref<i32>
            %371 = fir.convert %370 : (i32) -> i64
            %372 = hlfir.designate %84#0 (%366, %369, %371)  : (!fir.ref<!fir.array<68x78x15xf32>>, i64, i64, i64) -> !fir.ref<f32>
            %373 = fir.load %372 : !fir.ref<f32>
            %374 = fir.load %19#0 : !fir.ref<i32>
            %375 = fir.convert %374 : (i32) -> i64
            %376 = fir.load %35#0 : !fir.ref<i32>
            %377 = fir.convert %376 : (i32) -> i64
            %378 = fir.load %47#0 : !fir.ref<i32>
            %379 = fir.convert %378 : (i32) -> i64
            %380 = hlfir.designate %84#0 (%375, %377, %379)  : (!fir.ref<!fir.array<68x78x15xf32>>, i64, i64, i64) -> !fir.ref<f32>
            %381 = fir.load %380 : !fir.ref<f32>
            %382 = arith.addf %373, %381 fastmath<contract> : f32
            %383 = hlfir.no_reassoc %382 : f32
            %384 = fir.load %19#0 : !fir.ref<i32>
            %c1_i32_133 = arith.constant 1 : i32
            %385 = arith.subi %384, %c1_i32_133 overflow<nsw> : i32
            %386 = fir.convert %385 : (i32) -> i64
            %387 = fir.load %35#0 : !fir.ref<i32>
            %388 = fir.convert %387 : (i32) -> i64
            %389 = fir.load %47#0 : !fir.ref<i32>
            %390 = fir.convert %389 : (i32) -> i64
            %391 = hlfir.designate %84#0 (%386, %388, %390)  : (!fir.ref<!fir.array<68x78x15xf32>>, i64, i64, i64) -> !fir.ref<f32>
            %392 = fir.load %391 : !fir.ref<f32>
            %393 = fir.load %19#0 : !fir.ref<i32>
            %394 = fir.convert %393 : (i32) -> i64
            %395 = fir.load %35#0 : !fir.ref<i32>
            %c1_i32_134 = arith.constant 1 : i32
            %396 = arith.subi %395, %c1_i32_134 overflow<nsw> : i32
            %397 = fir.convert %396 : (i32) -> i64
            %398 = fir.load %47#0 : !fir.ref<i32>
            %399 = fir.convert %398 : (i32) -> i64
            %400 = hlfir.designate %84#0 (%394, %397, %399)  : (!fir.ref<!fir.array<68x78x15xf32>>, i64, i64, i64) -> !fir.ref<f32>
            %401 = fir.load %400 : !fir.ref<f32>
            %402 = arith.addf %392, %401 fastmath<contract> : f32
            %403 = hlfir.no_reassoc %402 : f32
            %404 = arith.addf %383, %403 fastmath<contract> : f32
            %405 = hlfir.no_reassoc %404 : f32
            %406 = arith.mulf %cst_130, %405 fastmath<contract> : f32
            %407 = fir.load %19#0 : !fir.ref<i32>
            %408 = fir.convert %407 : (i32) -> i64
            %409 = fir.load %35#0 : !fir.ref<i32>
            %410 = fir.convert %409 : (i32) -> i64
            %411 = fir.load %47#0 : !fir.ref<i32>
            %412 = fir.convert %411 : (i32) -> i64
            %413 = hlfir.designate %87#0 (%408, %410, %412)  : (!fir.ref<!fir.array<68x78x15xf32>>, i64, i64, i64) -> !fir.ref<f32>
            hlfir.assign %406 to %413 : f32, !fir.ref<f32>
            %cst_135 = arith.constant 2.500000e-01 : f32
            %414 = fir.load %19#0 : !fir.ref<i32>
            %c1_i32_136 = arith.constant 1 : i32
            %415 = arith.subi %414, %c1_i32_136 overflow<nsw> : i32
            %416 = fir.convert %415 : (i32) -> i64
            %417 = fir.load %35#0 : !fir.ref<i32>
            %c1_i32_137 = arith.constant 1 : i32
            %418 = arith.subi %417, %c1_i32_137 overflow<nsw> : i32
            %419 = fir.convert %418 : (i32) -> i64
            %420 = fir.load %47#0 : !fir.ref<i32>
            %421 = fir.convert %420 : (i32) -> i64
            %422 = hlfir.designate %121#0 (%416, %419, %421)  : (!fir.ref<!fir.array<68x78x15xf32>>, i64, i64, i64) -> !fir.ref<f32>
            %423 = fir.load %422 : !fir.ref<f32>
            %424 = fir.load %19#0 : !fir.ref<i32>
            %425 = fir.convert %424 : (i32) -> i64
            %426 = fir.load %35#0 : !fir.ref<i32>
            %427 = fir.convert %426 : (i32) -> i64
            %428 = fir.load %47#0 : !fir.ref<i32>
            %429 = fir.convert %428 : (i32) -> i64
            %430 = hlfir.designate %121#0 (%425, %427, %429)  : (!fir.ref<!fir.array<68x78x15xf32>>, i64, i64, i64) -> !fir.ref<f32>
            %431 = fir.load %430 : !fir.ref<f32>
            %432 = arith.addf %423, %431 fastmath<contract> : f32
            %433 = hlfir.no_reassoc %432 : f32
            %434 = fir.load %19#0 : !fir.ref<i32>
            %c1_i32_138 = arith.constant 1 : i32
            %435 = arith.subi %434, %c1_i32_138 overflow<nsw> : i32
            %436 = fir.convert %435 : (i32) -> i64
            %437 = fir.load %35#0 : !fir.ref<i32>
            %438 = fir.convert %437 : (i32) -> i64
            %439 = fir.load %47#0 : !fir.ref<i32>
            %440 = fir.convert %439 : (i32) -> i64
            %441 = hlfir.designate %121#0 (%436, %438, %440)  : (!fir.ref<!fir.array<68x78x15xf32>>, i64, i64, i64) -> !fir.ref<f32>
            %442 = fir.load %441 : !fir.ref<f32>
            %443 = fir.load %19#0 : !fir.ref<i32>
            %444 = fir.convert %443 : (i32) -> i64
            %445 = fir.load %35#0 : !fir.ref<i32>
            %c1_i32_139 = arith.constant 1 : i32
            %446 = arith.subi %445, %c1_i32_139 overflow<nsw> : i32
            %447 = fir.convert %446 : (i32) -> i64
            %448 = fir.load %47#0 : !fir.ref<i32>
            %449 = fir.convert %448 : (i32) -> i64
            %450 = hlfir.designate %121#0 (%444, %447, %449)  : (!fir.ref<!fir.array<68x78x15xf32>>, i64, i64, i64) -> !fir.ref<f32>
            %451 = fir.load %450 : !fir.ref<f32>
            %452 = arith.addf %442, %451 fastmath<contract> : f32
            %453 = hlfir.no_reassoc %452 : f32
            %454 = arith.addf %433, %453 fastmath<contract> : f32
            %455 = hlfir.no_reassoc %454 : f32
            %456 = arith.mulf %cst_135, %455 fastmath<contract> : f32
            %457 = fir.load %19#0 : !fir.ref<i32>
            %458 = fir.convert %457 : (i32) -> i64
            %459 = fir.load %35#0 : !fir.ref<i32>
            %460 = fir.convert %459 : (i32) -> i64
            %461 = fir.load %47#0 : !fir.ref<i32>
            %462 = fir.convert %461 : (i32) -> i64
            %463 = hlfir.designate %124#0 (%458, %460, %462)  : (!fir.ref<!fir.array<68x78x15xf32>>, i64, i64, i64) -> !fir.ref<f32>
            hlfir.assign %456 to %463 : f32, !fir.ref<f32>
            %464 = fir.load %19#0 : !fir.ref<i32>
            %465 = fir.convert %464 : (i32) -> i64
            %466 = fir.load %35#0 : !fir.ref<i32>
            %467 = fir.convert %466 : (i32) -> i64
            %468 = fir.load %47#0 : !fir.ref<i32>
            %469 = fir.convert %468 : (i32) -> i64
            %470 = hlfir.designate %81#0 (%465, %467, %469)  : (!fir.ref<!fir.array<68x78x15xf32>>, i64, i64, i64) -> !fir.ref<f32>
            %471 = fir.load %470 : !fir.ref<f32>
            %c2_i32_140 = arith.constant 2 : i32
            %472 = math.fpowi %471, %c2_i32_140 fastmath<contract> : f32, i32
            %473 = fir.load %19#0 : !fir.ref<i32>
            %474 = fir.convert %473 : (i32) -> i64
            %475 = fir.load %35#0 : !fir.ref<i32>
            %476 = fir.convert %475 : (i32) -> i64
            %477 = fir.load %47#0 : !fir.ref<i32>
            %478 = fir.convert %477 : (i32) -> i64
            %479 = hlfir.designate %87#0 (%474, %476, %478)  : (!fir.ref<!fir.array<68x78x15xf32>>, i64, i64, i64) -> !fir.ref<f32>
            %480 = fir.load %479 : !fir.ref<f32>
            %c2_i32_141 = arith.constant 2 : i32
            %481 = math.fpowi %480, %c2_i32_141 fastmath<contract> : f32, i32
            %482 = arith.addf %472, %481 fastmath<contract> : f32
            %483 = fir.load %19#0 : !fir.ref<i32>
            %484 = fir.convert %483 : (i32) -> i64
            %485 = fir.load %35#0 : !fir.ref<i32>
            %486 = fir.convert %485 : (i32) -> i64
            %487 = fir.load %47#0 : !fir.ref<i32>
            %488 = fir.convert %487 : (i32) -> i64
            %489 = hlfir.designate %124#0 (%484, %486, %488)  : (!fir.ref<!fir.array<68x78x15xf32>>, i64, i64, i64) -> !fir.ref<f32>
            %490 = fir.load %489 : !fir.ref<f32>
            %c2_i32_142 = arith.constant 2 : i32
            %491 = math.fpowi %490, %c2_i32_142 fastmath<contract> : f32, i32
            %492 = arith.addf %482, %491 fastmath<contract> : f32
            %493 = hlfir.no_reassoc %492 : f32
            %494 = fir.load %19#0 : !fir.ref<i32>
            %495 = fir.convert %494 : (i32) -> i64
            %496 = fir.load %35#0 : !fir.ref<i32>
            %497 = fir.convert %496 : (i32) -> i64
            %498 = hlfir.designate %56#0 (%495, %497)  : (!fir.ref<!fir.array<68x78xf32>>, i64, i64) -> !fir.ref<f32>
            %499 = fir.load %498 : !fir.ref<f32>
            %500 = arith.mulf %493, %499 fastmath<contract> : f32
            %501 = fir.load %19#0 : !fir.ref<i32>
            %502 = fir.convert %501 : (i32) -> i64
            %503 = fir.load %35#0 : !fir.ref<i32>
            %504 = fir.convert %503 : (i32) -> i64
            %505 = hlfir.designate %90#0 (%502, %504)  : (!fir.ref<!fir.array<68x78xf32>>, i64, i64) -> !fir.ref<f32>
            hlfir.assign %500 to %505 : f32, !fir.ref<f32>
          }
          %353 = fir.convert %c2_i32_127 : (i32) -> index
          %354 = fir.convert %c67_i32 : (i32) -> index
          %355 = fir.convert %c1_i32_128 : (i32) -> index
          %c0_129 = arith.constant 0 : index
          %356 = arith.subi %354, %353 : index
          %357 = arith.addi %356, %355 : index
          %358 = arith.divsi %357, %355 : index
          %359 = arith.cmpi slt, %358, %c0_129 : index
          %360 = arith.select %359, %c0_129, %358 : index
          %361 = arith.muli %360, %355 : index
          %362 = arith.addi %353, %361 : index
          %363 = fir.convert %362 : (index) -> i32
          fir.store %363 to %19#0 : !fir.ref<i32>
        }
        %331 = fir.convert %c2_i32_122 : (i32) -> index
        %332 = fir.convert %c77_i32 : (i32) -> index
        %333 = fir.convert %c1_i32_123 : (i32) -> index
        %c0_124 = arith.constant 0 : index
        %334 = arith.subi %332, %331 : index
        %335 = arith.addi %334, %333 : index
        %336 = arith.divsi %335, %333 : index
        %337 = arith.cmpi slt, %336, %c0_124 : index
        %338 = arith.select %337, %c0_124, %336 : index
        %339 = arith.muli %338, %333 : index
        %340 = arith.addi %331, %339 : index
        %341 = fir.convert %340 : (index) -> i32
        fir.store %341 to %35#0 : !fir.ref<i32>
        %c3_i32 = arith.constant 3 : i32
        %c76_i32 = arith.constant 76 : i32
        %c1_i32_125 = arith.constant 1 : i32
        fir.do_loop %arg2 = %c3_i32 to %c76_i32 step %c1_i32_125 : i32 {
          fir.store %arg2 to %35#0 : !fir.ref<i32>
          %c3_i32_127 = arith.constant 3 : i32
          %c66_i32 = arith.constant 66 : i32
          %c1_i32_128 = arith.constant 1 : i32
          fir.do_loop %arg3 = %c3_i32_127 to %c66_i32 step %c1_i32_128 : i32 {
            fir.store %arg3 to %19#0 : !fir.ref<i32>
            %cst_130 = arith.constant 0.000000e+00 : f32
            hlfir.assign %cst_130 to %104#0 : f32, !fir.ref<f32>
            %364 = fir.load %35#0 : !fir.ref<i32>
            %c1_i32_131 = arith.constant 1 : i32
            %365 = arith.subi %364, %c1_i32_131 overflow<nsw> : i32
            %366 = fir.load %35#0 : !fir.ref<i32>
            %c1_i32_132 = arith.constant 1 : i32
            %367 = arith.addi %366, %c1_i32_132 overflow<nsw> : i32
            %c1_i32_133 = arith.constant 1 : i32
            fir.do_loop %arg4 = %365 to %367 step %c1_i32_133 : i32 {
              fir.store %arg4 to %41#0 : !fir.ref<i32>
              %388 = fir.load %19#0 : !fir.ref<i32>
              %c1_i32_135 = arith.constant 1 : i32
              %389 = arith.subi %388, %c1_i32_135 overflow<nsw> : i32
              %390 = fir.load %19#0 : !fir.ref<i32>
              %c1_i32_136 = arith.constant 1 : i32
              %391 = arith.addi %390, %c1_i32_136 overflow<nsw> : i32
              %c1_i32_137 = arith.constant 1 : i32
              fir.do_loop %arg5 = %389 to %391 step %c1_i32_137 : i32 {
                fir.store %arg5 to %25#0 : !fir.ref<i32>
                %403 = fir.load %104#0 : !fir.ref<f32>
                %404 = fir.load %25#0 : !fir.ref<i32>
                %405 = fir.convert %404 : (i32) -> i64
                %406 = fir.load %41#0 : !fir.ref<i32>
                %407 = fir.convert %406 : (i32) -> i64
                %408 = hlfir.designate %90#0 (%405, %407)  : (!fir.ref<!fir.array<68x78xf32>>, i64, i64) -> !fir.ref<f32>
                %409 = fir.load %408 : !fir.ref<f32>
                %410 = arith.addf %403, %409 fastmath<contract> : f32
                hlfir.assign %410 to %104#0 : f32, !fir.ref<f32>
              }
              %392 = fir.convert %389 : (i32) -> index
              %393 = fir.convert %391 : (i32) -> index
              %394 = fir.convert %c1_i32_137 : (i32) -> index
              %c0_138 = arith.constant 0 : index
              %395 = arith.subi %393, %392 : index
              %396 = arith.addi %395, %394 : index
              %397 = arith.divsi %396, %394 : index
              %398 = arith.cmpi slt, %397, %c0_138 : index
              %399 = arith.select %398, %c0_138, %397 : index
              %400 = arith.muli %399, %394 : index
              %401 = arith.addi %392, %400 : index
              %402 = fir.convert %401 : (index) -> i32
              fir.store %402 to %25#0 : !fir.ref<i32>
            }
            %368 = fir.convert %365 : (i32) -> index
            %369 = fir.convert %367 : (i32) -> index
            %370 = fir.convert %c1_i32_133 : (i32) -> index
            %c0_134 = arith.constant 0 : index
            %371 = arith.subi %369, %368 : index
            %372 = arith.addi %371, %370 : index
            %373 = arith.divsi %372, %370 : index
            %374 = arith.cmpi slt, %373, %c0_134 : index
            %375 = arith.select %374, %c0_134, %373 : index
            %376 = arith.muli %375, %370 : index
            %377 = arith.addi %368, %376 : index
            %378 = fir.convert %377 : (index) -> i32
            fir.store %378 to %41#0 : !fir.ref<i32>
            %379 = fir.load %104#0 : !fir.ref<f32>
            %380 = math.sqrt %379 fastmath<contract> : f32
            %381 = fir.load %19#0 : !fir.ref<i32>
            %382 = fir.convert %381 : (i32) -> i64
            %383 = fir.load %35#0 : !fir.ref<i32>
            %384 = fir.convert %383 : (i32) -> i64
            %385 = fir.load %47#0 : !fir.ref<i32>
            %386 = fir.convert %385 : (i32) -> i64
            %387 = hlfir.designate %63#0 (%382, %384, %386)  : (!fir.ref<!fir.array<68x78x15xf32>>, i64, i64, i64) -> !fir.ref<f32>
            hlfir.assign %380 to %387 : f32, !fir.ref<f32>
          }
          %353 = fir.convert %c3_i32_127 : (i32) -> index
          %354 = fir.convert %c66_i32 : (i32) -> index
          %355 = fir.convert %c1_i32_128 : (i32) -> index
          %c0_129 = arith.constant 0 : index
          %356 = arith.subi %354, %353 : index
          %357 = arith.addi %356, %355 : index
          %358 = arith.divsi %357, %355 : index
          %359 = arith.cmpi slt, %358, %c0_129 : index
          %360 = arith.select %359, %c0_129, %358 : index
          %361 = arith.muli %360, %355 : index
          %362 = arith.addi %353, %361 : index
          %363 = fir.convert %362 : (index) -> i32
          fir.store %363 to %19#0 : !fir.ref<i32>
        }
        %342 = fir.convert %c3_i32 : (i32) -> index
        %343 = fir.convert %c76_i32 : (i32) -> index
        %344 = fir.convert %c1_i32_125 : (i32) -> index
        %c0_126 = arith.constant 0 : index
        %345 = arith.subi %343, %342 : index
        %346 = arith.addi %345, %344 : index
        %347 = arith.divsi %346, %344 : index
        %348 = arith.cmpi slt, %347, %c0_126 : index
        %349 = arith.select %348, %c0_126, %347 : index
        %350 = arith.muli %349, %344 : index
        %351 = arith.addi %342, %350 : index
        %352 = fir.convert %351 : (index) -> i32
        fir.store %352 to %35#0 : !fir.ref<i32>
      }
      %309 = fir.convert %c1_i32_115 : (i32) -> index
      %310 = fir.convert %c15_i32 : (i32) -> index
      %311 = fir.convert %c1_i32_116 : (i32) -> index
      %c0_117 = arith.constant 0 : index
      %312 = arith.subi %310, %309 : index
      %313 = arith.addi %312, %311 : index
      %314 = arith.divsi %313, %311 : index
      %315 = arith.cmpi slt, %314, %c0_117 : index
      %316 = arith.select %315, %c0_117, %314 : index
      %317 = arith.muli %316, %311 : index
      %318 = arith.addi %309, %317 : index
      %319 = fir.convert %318 : (index) -> i32
      fir.store %319 to %47#0 : !fir.ref<i32>
      %c1_i32_118 = arith.constant 1 : i32
      %c15_i32_119 = arith.constant 15 : i32
      %c1_i32_120 = arith.constant 1 : i32
      %fxb_c3_i32_127 = arith.constant 3 : i32
      %fxb_c66_i32 = arith.constant 66 : i32
      %fxb_c1_i32_128 = arith.constant 1 : i32
      %fx_ilo = arith.constant 3 : i32
      %fx_ihi = arith.constant 66 : i32
      %fx_one = arith.constant 1 : i32
      %fx_ispan = arith.subi %fx_ihi, %fx_ilo : i32
      %fx_ni = arith.addi %fx_ispan, %fx_one : i32
      %fx_jlo = arith.constant 3 : i32
      %fx_jhi = arith.constant 76 : i32
      %fx_jspan = arith.subi %fx_jhi, %fx_jlo : i32
      %fx_nj = arith.addi %fx_jspan, %fx_one : i32
      %fx_count = arith.muli %fx_ni, %fx_nj : i32
      fir.call @fortis_gather(%87#1, %81#1, %124#1, %63#1) : (!fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78x15xf32>>) -> ()
      fir.call @mlp_forward_batched() : () -> ()
      fir.do_loop %arg1 = %c1_i32_118 to %c15_i32_119 step %c1_i32_120 : i32 {
        fir.store %arg1 to %47#0 : !fir.ref<i32>
        %c3_i32 = arith.constant 3 : i32
        %c76_i32 = arith.constant 76 : i32
        %c1_i32_122 = arith.constant 1 : i32
        %fxs_a0 = fir.load %47#0 : !fir.ref<i32>
        fir.call @fortis_scatter(%fxs_a0, %63#1, %50#1, %113#1, %107#1, %116#1) : (i32, !fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78xf32>>, !fir.ref<!fir.array<68x78xf32>>, !fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78x15xf32>>) -> ()
        %331 = fir.convert %c3_i32 : (i32) -> index
        %332 = fir.convert %c76_i32 : (i32) -> index
        %333 = fir.convert %c1_i32_122 : (i32) -> index
        %c0_123 = arith.constant 0 : index
        %334 = arith.subi %332, %331 : index
        %335 = arith.addi %334, %333 : index
        %336 = arith.divsi %335, %333 : index
        %337 = arith.cmpi slt, %336, %c0_123 : index
        %338 = arith.select %337, %c0_123, %336 : index
        %339 = arith.muli %338, %333 : index
        %340 = arith.addi %331, %339 : index
        %341 = fir.convert %340 : (index) -> i32
        fir.store %341 to %35#0 : !fir.ref<i32>
        %c3_i32_124 = arith.constant 3 : i32
        %c75_i32 = arith.constant 75 : i32
        %c1_i32_125 = arith.constant 1 : i32
        fir.do_loop %arg2 = %c3_i32_124 to %c75_i32 step %c1_i32_125 : i32 {
          fir.store %arg2 to %35#0 : !fir.ref<i32>
          %c3_i32_127 = arith.constant 3 : i32
          %c65_i32 = arith.constant 65 : i32
          %c1_i32_128 = arith.constant 1 : i32
          fir.do_loop %arg3 = %c3_i32_127 to %c65_i32 step %c1_i32_128 : i32 {
            fir.store %arg3 to %19#0 : !fir.ref<i32>
            %cst_130 = arith.constant 2.500000e-01 : f32
            %364 = fir.load %19#0 : !fir.ref<i32>
            %c1_i32_131 = arith.constant 1 : i32
            %365 = arith.addi %364, %c1_i32_131 overflow<nsw> : i32
            %366 = fir.convert %365 : (i32) -> i64
            %367 = fir.load %35#0 : !fir.ref<i32>
            %c1_i32_132 = arith.constant 1 : i32
            %368 = arith.addi %367, %c1_i32_132 overflow<nsw> : i32
            %369 = fir.convert %368 : (i32) -> i64
            %370 = hlfir.designate %113#0 (%366, %369)  : (!fir.ref<!fir.array<68x78xf32>>, i64, i64) -> !fir.ref<f32>
            %371 = fir.load %370 : !fir.ref<f32>
            %372 = fir.load %19#0 : !fir.ref<i32>
            %373 = fir.convert %372 : (i32) -> i64
            %374 = fir.load %35#0 : !fir.ref<i32>
            %375 = fir.convert %374 : (i32) -> i64
            %376 = hlfir.designate %113#0 (%373, %375)  : (!fir.ref<!fir.array<68x78xf32>>, i64, i64) -> !fir.ref<f32>
            %377 = fir.load %376 : !fir.ref<f32>
            %378 = arith.addf %371, %377 fastmath<contract> : f32
            %379 = hlfir.no_reassoc %378 : f32
            %380 = fir.load %19#0 : !fir.ref<i32>
            %c1_i32_133 = arith.constant 1 : i32
            %381 = arith.addi %380, %c1_i32_133 overflow<nsw> : i32
            %382 = fir.convert %381 : (i32) -> i64
            %383 = fir.load %35#0 : !fir.ref<i32>
            %384 = fir.convert %383 : (i32) -> i64
            %385 = hlfir.designate %113#0 (%382, %384)  : (!fir.ref<!fir.array<68x78xf32>>, i64, i64) -> !fir.ref<f32>
            %386 = fir.load %385 : !fir.ref<f32>
            %387 = fir.load %19#0 : !fir.ref<i32>
            %388 = fir.convert %387 : (i32) -> i64
            %389 = fir.load %35#0 : !fir.ref<i32>
            %c1_i32_134 = arith.constant 1 : i32
            %390 = arith.addi %389, %c1_i32_134 overflow<nsw> : i32
            %391 = fir.convert %390 : (i32) -> i64
            %392 = hlfir.designate %113#0 (%388, %391)  : (!fir.ref<!fir.array<68x78xf32>>, i64, i64) -> !fir.ref<f32>
            %393 = fir.load %392 : !fir.ref<f32>
            %394 = arith.addf %386, %393 fastmath<contract> : f32
            %395 = hlfir.no_reassoc %394 : f32
            %396 = arith.addf %379, %395 fastmath<contract> : f32
            %397 = hlfir.no_reassoc %396 : f32
            %398 = arith.mulf %cst_130, %397 fastmath<contract> : f32
            %399 = fir.load %19#0 : !fir.ref<i32>
            %400 = fir.convert %399 : (i32) -> i64
            %401 = fir.load %35#0 : !fir.ref<i32>
            %402 = fir.convert %401 : (i32) -> i64
            %403 = hlfir.designate %53#0 (%400, %402)  : (!fir.ref<!fir.array<68x78xf32>>, i64, i64) -> !fir.ref<f32>
            %404 = fir.load %403 : !fir.ref<f32>
            %405 = arith.mulf %398, %404 fastmath<contract> : f32
            %406 = fir.load %19#0 : !fir.ref<i32>
            %407 = fir.convert %406 : (i32) -> i64
            %408 = fir.load %35#0 : !fir.ref<i32>
            %409 = fir.convert %408 : (i32) -> i64
            %410 = fir.load %47#0 : !fir.ref<i32>
            %411 = fir.convert %410 : (i32) -> i64
            %412 = hlfir.designate %110#0 (%407, %409, %411)  : (!fir.ref<!fir.array<68x78x15xf32>>, i64, i64, i64) -> !fir.ref<f32>
            hlfir.assign %405 to %412 : f32, !fir.ref<f32>
          }
          %353 = fir.convert %c3_i32_127 : (i32) -> index
          %354 = fir.convert %c65_i32 : (i32) -> index
          %355 = fir.convert %c1_i32_128 : (i32) -> index
          %c0_129 = arith.constant 0 : index
          %356 = arith.subi %354, %353 : index
          %357 = arith.addi %356, %355 : index
          %358 = arith.divsi %357, %355 : index
          %359 = arith.cmpi slt, %358, %c0_129 : index
          %360 = arith.select %359, %c0_129, %358 : index
          %361 = arith.muli %360, %355 : index
          %362 = arith.addi %353, %361 : index
          %363 = fir.convert %362 : (index) -> i32
          fir.store %363 to %19#0 : !fir.ref<i32>
        }
        %342 = fir.convert %c3_i32_124 : (i32) -> index
        %343 = fir.convert %c75_i32 : (i32) -> index
        %344 = fir.convert %c1_i32_125 : (i32) -> index
        %c0_126 = arith.constant 0 : index
        %345 = arith.subi %343, %342 : index
        %346 = arith.addi %345, %344 : index
        %347 = arith.divsi %346, %344 : index
        %348 = arith.cmpi slt, %347, %c0_126 : index
        %349 = arith.select %348, %c0_126, %347 : index
        %350 = arith.muli %349, %344 : index
        %351 = arith.addi %342, %350 : index
        %352 = fir.convert %351 : (index) -> i32
        fir.store %352 to %35#0 : !fir.ref<i32>
      }
      %320 = fir.convert %c1_i32_118 : (i32) -> index
      %321 = fir.convert %c15_i32_119 : (i32) -> index
      %322 = fir.convert %c1_i32_120 : (i32) -> index
      %c0_121 = arith.constant 0 : index
      %323 = arith.subi %321, %320 : index
      %324 = arith.addi %323, %322 : index
      %325 = arith.divsi %324, %322 : index
      %326 = arith.cmpi slt, %325, %c0_121 : index
      %327 = arith.select %326, %c0_121, %325 : index
      %328 = arith.muli %327, %322 : index
      %329 = arith.addi %320, %328 : index
      %330 = fir.convert %329 : (index) -> i32
      fir.store %330 to %47#0 : !fir.ref<i32>
    }
    %174 = fir.convert %c1_i32_95 : (i32) -> index
    %175 = fir.convert %c11_i32 : (i32) -> index
    %176 = fir.convert %c1_i32_96 : (i32) -> index
    %c0_97 = arith.constant 0 : index
    %177 = arith.subi %175, %174 : index
    %178 = arith.addi %177, %176 : index
    %179 = arith.divsi %178, %176 : index
    %180 = arith.cmpi slt, %179, %c0_97 : index
    %181 = arith.select %180, %c0_97, %179 : index
    %182 = arith.muli %181, %176 : index
    %183 = arith.addi %174, %182 : index
    %184 = fir.convert %183 : (index) -> i32
    fir.store %184 to %96#0 : !fir.ref<i32>
    %c8_i32_98 = arith.constant 8 : i32
    %185 = fir.call @_FortranASystemClockCount(%c8_i32_98) fastmath<contract> : (i32) -> i64
    fir.store %185 to %8#0 : !fir.ref<i64>
    %c6_i32 = arith.constant 6 : i32
    %186 = fir.address_of(@_QQclX80a40c38ee47a5aede30bfbca1971818) : !fir.ref<!fir.char<1,53>>
    %187 = fir.convert %186 : (!fir.ref<!fir.char<1,53>>) -> !fir.ref<i8>
    %c111_i32 = arith.constant 111 : i32
    %188 = fir.call @_FortranAioBeginExternalListOutput(%c6_i32, %187, %c111_i32) fastmath<contract> : (i32, !fir.ref<i8>, i32) -> !fir.ref<i8>
    %189 = fir.address_of(@_QQclX7065722D73746570206D733A) : !fir.ref<!fir.char<1,12>>
    %c12 = arith.constant 12 : index
    %190:2 = hlfir.declare %189 typeparams %c12 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QQclX7065722D73746570206D733A"} : (!fir.ref<!fir.char<1,12>>, index) -> (!fir.ref<!fir.char<1,12>>, !fir.ref<!fir.char<1,12>>)
    %191 = fir.convert %190#0 : (!fir.ref<!fir.char<1,12>>) -> !fir.ref<i8>
    %192 = fir.convert %c12 : (index) -> i64
    %193 = fir.call @_FortranAioOutputAscii(%188, %191, %192) fastmath<contract> : (!fir.ref<i8>, !fir.ref<i8>, i64) -> i1
    %194 = fir.load %8#0 : !fir.ref<i64>
    %195 = fir.load %6#0 : !fir.ref<i64>
    %196 = arith.subi %194, %195 : i64
    %197 = fir.convert %196 : (i64) -> f32
    %198 = fir.load %71#0 : !fir.ref<i64>
    %199 = fir.convert %198 : (i64) -> f32
    %200 = arith.divf %197, %199 fastmath<contract> : f32
    %cst_99 = arith.constant 1.000000e+03 : f32
    %201 = arith.mulf %200, %cst_99 fastmath<contract> : f32
    %cst_100 = arith.constant 1.000000e+01 : f32
    %202 = arith.divf %201, %cst_100 fastmath<contract> : f32
    %203 = fir.call @_FortranAioOutputReal32(%188, %202) fastmath<contract> : (!fir.ref<i8>, f32) -> i1
    %204 = fir.call @_FortranAioEndIoStatement(%188) fastmath<contract> : (!fir.ref<i8>) -> i32
    %c6_i32_101 = arith.constant 6 : i32
    %205 = fir.address_of(@_QQclX80a40c38ee47a5aede30bfbca1971818) : !fir.ref<!fir.char<1,53>>
    %206 = fir.convert %205 : (!fir.ref<!fir.char<1,53>>) -> !fir.ref<i8>
    %c112_i32 = arith.constant 112 : i32
    %207 = fir.call @_FortranAioBeginExternalListOutput(%c6_i32_101, %206, %c112_i32) fastmath<contract> : (i32, !fir.ref<i8>, i32) -> !fir.ref<i8>
    %208 = fir.address_of(@_QQclX636865636B73756D205478783A) : !fir.ref<!fir.char<1,13>>
    %c13 = arith.constant 13 : index
    %209:2 = hlfir.declare %208 typeparams %c13 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QQclX636865636B73756D205478783A"} : (!fir.ref<!fir.char<1,13>>, index) -> (!fir.ref<!fir.char<1,13>>, !fir.ref<!fir.char<1,13>>)
    %210 = fir.convert %209#0 : (!fir.ref<!fir.char<1,13>>) -> !fir.ref<i8>
    %211 = fir.convert %c13 : (index) -> i64
    %212 = fir.call @_FortranAioOutputAscii(%207, %210, %211) fastmath<contract> : (!fir.ref<i8>, !fir.ref<i8>, i64) -> i1
    %213 = hlfir.elemental %106 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
    ^bb0(%arg0: index, %arg1: index, %arg2: index):
      %307 = hlfir.designate %107#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf32>>, index, index, index) -> !fir.ref<f32>
      %308 = fir.load %307 : !fir.ref<f32>
      %309 = fir.convert %308 : (f32) -> f64
      hlfir.yield_element %309 : f64
    }
    %214 = hlfir.sum %213 {fastmath = #arith.fastmath<contract>} : (!hlfir.expr<68x78x15xf64>) -> f64
    %215 = fir.call @_FortranAioOutputReal64(%207, %214) fastmath<contract> : (!fir.ref<i8>, f64) -> i1
    hlfir.destroy %213 : !hlfir.expr<68x78x15xf64>
    %216 = fir.address_of(@_QQclX20205479793A) : !fir.ref<!fir.char<1,6>>
    %c6 = arith.constant 6 : index
    %217:2 = hlfir.declare %216 typeparams %c6 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QQclX20205479793A"} : (!fir.ref<!fir.char<1,6>>, index) -> (!fir.ref<!fir.char<1,6>>, !fir.ref<!fir.char<1,6>>)
    %218 = fir.convert %217#0 : (!fir.ref<!fir.char<1,6>>) -> !fir.ref<i8>
    %219 = fir.convert %c6 : (index) -> i64
    %220 = fir.call @_FortranAioOutputAscii(%207, %218, %219) fastmath<contract> : (!fir.ref<i8>, !fir.ref<i8>, i64) -> i1
    %221 = hlfir.elemental %115 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
    ^bb0(%arg0: index, %arg1: index, %arg2: index):
      %307 = hlfir.designate %116#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf32>>, index, index, index) -> !fir.ref<f32>
      %308 = fir.load %307 : !fir.ref<f32>
      %309 = fir.convert %308 : (f32) -> f64
      hlfir.yield_element %309 : f64
    }
    %222 = hlfir.sum %221 {fastmath = #arith.fastmath<contract>} : (!hlfir.expr<68x78x15xf64>) -> f64
    %223 = fir.call @_FortranAioOutputReal64(%207, %222) fastmath<contract> : (!fir.ref<i8>, f64) -> i1
    hlfir.destroy %221 : !hlfir.expr<68x78x15xf64>
    %224 = fir.address_of(@_QQclX20205478793A) : !fir.ref<!fir.char<1,6>>
    %c6_102 = arith.constant 6 : index
    %225:2 = hlfir.declare %224 typeparams %c6_102 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QQclX20205478793A"} : (!fir.ref<!fir.char<1,6>>, index) -> (!fir.ref<!fir.char<1,6>>, !fir.ref<!fir.char<1,6>>)
    %226 = fir.convert %225#0 : (!fir.ref<!fir.char<1,6>>) -> !fir.ref<i8>
    %227 = fir.convert %c6_102 : (index) -> i64
    %228 = fir.call @_FortranAioOutputAscii(%207, %226, %227) fastmath<contract> : (!fir.ref<i8>, !fir.ref<i8>, i64) -> i1
    %229 = hlfir.elemental %109 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
    ^bb0(%arg0: index, %arg1: index, %arg2: index):
      %307 = hlfir.designate %110#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf32>>, index, index, index) -> !fir.ref<f32>
      %308 = fir.load %307 : !fir.ref<f32>
      %309 = fir.convert %308 : (f32) -> f64
      hlfir.yield_element %309 : f64
    }
    %230 = hlfir.sum %229 {fastmath = #arith.fastmath<contract>} : (!hlfir.expr<68x78x15xf64>) -> f64
    %231 = fir.call @_FortranAioOutputReal64(%207, %230) fastmath<contract> : (!fir.ref<i8>, f64) -> i1
    hlfir.destroy %229 : !hlfir.expr<68x78x15xf64>
    %232 = fir.call @_FortranAioEndIoStatement(%207) fastmath<contract> : (!fir.ref<i8>) -> i32
    %233 = fir.address_of(@_QQclX80a40c38ee47a5aede30bfbca1971818) : !fir.ref<!fir.char<1,53>>
    %234 = fir.convert %233 : (!fir.ref<!fir.char<1,53>>) -> !fir.ref<i8>
    %c113_i32 = arith.constant 113 : i32
    %235 = fir.call @_FortranAioBeginOpenNewUnit(%234, %c113_i32) fastmath<contract> : (!fir.ref<i8>, i32) -> !fir.ref<i8>
    %236 = fir.address_of(@_QQclX7A625F6F75742E62696E) : !fir.ref<!fir.char<1,10>>
    %c10 = arith.constant 10 : index
    %237:2 = hlfir.declare %236 typeparams %c10 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QQclX7A625F6F75742E62696E"} : (!fir.ref<!fir.char<1,10>>, index) -> (!fir.ref<!fir.char<1,10>>, !fir.ref<!fir.char<1,10>>)
    %238 = fir.convert %237#0 : (!fir.ref<!fir.char<1,10>>) -> !fir.ref<i8>
    %239 = fir.convert %c10 : (index) -> i64
    %240 = fir.call @_FortranAioSetFile(%235, %238, %239) fastmath<contract> : (!fir.ref<i8>, !fir.ref<i8>, i64) -> i1
    %241 = fir.address_of(@_QQclX73747265616D) : !fir.ref<!fir.char<1,6>>
    %c6_103 = arith.constant 6 : index
    %242:2 = hlfir.declare %241 typeparams %c6_103 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QQclX73747265616D"} : (!fir.ref<!fir.char<1,6>>, index) -> (!fir.ref<!fir.char<1,6>>, !fir.ref<!fir.char<1,6>>)
    %243 = fir.convert %242#0 : (!fir.ref<!fir.char<1,6>>) -> !fir.ref<i8>
    %244 = fir.convert %c6_103 : (index) -> i64
    %245 = fir.call @_FortranAioSetAccess(%235, %243, %244) fastmath<contract> : (!fir.ref<i8>, !fir.ref<i8>, i64) -> i1
    %246 = fir.address_of(@_QQclX756E666F726D6174746564) : !fir.ref<!fir.char<1,11>>
    %c11 = arith.constant 11 : index
    %247:2 = hlfir.declare %246 typeparams %c11 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QQclX756E666F726D6174746564"} : (!fir.ref<!fir.char<1,11>>, index) -> (!fir.ref<!fir.char<1,11>>, !fir.ref<!fir.char<1,11>>)
    %248 = fir.convert %247#0 : (!fir.ref<!fir.char<1,11>>) -> !fir.ref<i8>
    %249 = fir.convert %c11 : (index) -> i64
    %250 = fir.call @_FortranAioSetForm(%235, %248, %249) fastmath<contract> : (!fir.ref<i8>, !fir.ref<i8>, i64) -> i1
    %251 = fir.address_of(@_QQclX7265706C616365) : !fir.ref<!fir.char<1,7>>
    %c7 = arith.constant 7 : index
    %252:2 = hlfir.declare %251 typeparams %c7 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QQclX7265706C616365"} : (!fir.ref<!fir.char<1,7>>, index) -> (!fir.ref<!fir.char<1,7>>, !fir.ref<!fir.char<1,7>>)
    %253 = fir.convert %252#0 : (!fir.ref<!fir.char<1,7>>) -> !fir.ref<i8>
    %254 = fir.convert %c7 : (index) -> i64
    %255 = fir.call @_FortranAioSetStatus(%235, %253, %254) fastmath<contract> : (!fir.ref<i8>, !fir.ref<i8>, i64) -> i1
    %c4_i32 = arith.constant 4 : i32
    %256 = fir.call @_FortranAioGetNewUnit(%235, %118#0, %c4_i32) fastmath<contract> : (!fir.ref<i8>, !fir.ref<i32>, i32) -> i1
    %257 = fir.call @_FortranAioEndIoStatement(%235) fastmath<contract> : (!fir.ref<i8>) -> i32
    %258 = fir.load %118#0 : !fir.ref<i32>
    %259 = fir.address_of(@_QQclX80a40c38ee47a5aede30bfbca1971818) : !fir.ref<!fir.char<1,53>>
    %260 = fir.convert %259 : (!fir.ref<!fir.char<1,53>>) -> !fir.ref<i8>
    %c114_i32 = arith.constant 114 : i32
    %261 = fir.call @_FortranAioBeginUnformattedOutput(%258, %260, %c114_i32) fastmath<contract> : (i32, !fir.ref<i8>, i32) -> !fir.ref<i8>
    %262 = hlfir.elemental %106 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
    ^bb0(%arg0: index, %arg1: index, %arg2: index):
      %307 = hlfir.designate %107#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf32>>, index, index, index) -> !fir.ref<f32>
      %308 = fir.load %307 : !fir.ref<f32>
      %309 = fir.convert %308 : (f32) -> f64
      hlfir.yield_element %309 : f64
    }
    %263:3 = hlfir.associate %262(%106) {adapt.valuebyref} : (!hlfir.expr<68x78x15xf64>, !fir.shape<3>) -> (!fir.ref<!fir.array<68x78x15xf64>>, !fir.ref<!fir.array<68x78x15xf64>>, i1)
    %264 = fir.shape %c68_23, %c78_24, %c15_25 : (index, index, index) -> !fir.shape<3>
    %265 = fir.embox %263#0(%264) : (!fir.ref<!fir.array<68x78x15xf64>>, !fir.shape<3>) -> !fir.box<!fir.array<68x78x15xf64>>
    %266 = fir.convert %265 : (!fir.box<!fir.array<68x78x15xf64>>) -> !fir.box<none>
    %267 = fir.call @_FortranAioOutputDescriptor(%261, %266) fastmath<contract> : (!fir.ref<i8>, !fir.box<none>) -> i1
    hlfir.end_associate %263#1, %263#2 : !fir.ref<!fir.array<68x78x15xf64>>, i1
    hlfir.destroy %262 : !hlfir.expr<68x78x15xf64>
    %268 = fir.call @_FortranAioEndIoStatement(%261) fastmath<contract> : (!fir.ref<i8>) -> i32
    %269 = fir.load %118#0 : !fir.ref<i32>
    %270 = fir.address_of(@_QQclX80a40c38ee47a5aede30bfbca1971818) : !fir.ref<!fir.char<1,53>>
    %271 = fir.convert %270 : (!fir.ref<!fir.char<1,53>>) -> !fir.ref<i8>
    %c114_i32_104 = arith.constant 114 : i32
    %272 = fir.call @_FortranAioBeginUnformattedOutput(%269, %271, %c114_i32_104) fastmath<contract> : (i32, !fir.ref<i8>, i32) -> !fir.ref<i8>
    %273 = hlfir.elemental %115 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
    ^bb0(%arg0: index, %arg1: index, %arg2: index):
      %307 = hlfir.designate %116#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf32>>, index, index, index) -> !fir.ref<f32>
      %308 = fir.load %307 : !fir.ref<f32>
      %309 = fir.convert %308 : (f32) -> f64
      hlfir.yield_element %309 : f64
    }
    %274:3 = hlfir.associate %273(%115) {adapt.valuebyref} : (!hlfir.expr<68x78x15xf64>, !fir.shape<3>) -> (!fir.ref<!fir.array<68x78x15xf64>>, !fir.ref<!fir.array<68x78x15xf64>>, i1)
    %275 = fir.shape %c68_31, %c78_32, %c15_33 : (index, index, index) -> !fir.shape<3>
    %276 = fir.embox %274#0(%275) : (!fir.ref<!fir.array<68x78x15xf64>>, !fir.shape<3>) -> !fir.box<!fir.array<68x78x15xf64>>
    %277 = fir.convert %276 : (!fir.box<!fir.array<68x78x15xf64>>) -> !fir.box<none>
    %278 = fir.call @_FortranAioOutputDescriptor(%272, %277) fastmath<contract> : (!fir.ref<i8>, !fir.box<none>) -> i1
    hlfir.end_associate %274#1, %274#2 : !fir.ref<!fir.array<68x78x15xf64>>, i1
    hlfir.destroy %273 : !hlfir.expr<68x78x15xf64>
    %279 = fir.call @_FortranAioEndIoStatement(%272) fastmath<contract> : (!fir.ref<i8>) -> i32
    %280 = fir.load %118#0 : !fir.ref<i32>
    %281 = fir.address_of(@_QQclX80a40c38ee47a5aede30bfbca1971818) : !fir.ref<!fir.char<1,53>>
    %282 = fir.convert %281 : (!fir.ref<!fir.char<1,53>>) -> !fir.ref<i8>
    %c114_i32_105 = arith.constant 114 : i32
    %283 = fir.call @_FortranAioBeginUnformattedOutput(%280, %282, %c114_i32_105) fastmath<contract> : (i32, !fir.ref<i8>, i32) -> !fir.ref<i8>
    %284 = hlfir.elemental %109 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
    ^bb0(%arg0: index, %arg1: index, %arg2: index):
      %307 = hlfir.designate %110#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf32>>, index, index, index) -> !fir.ref<f32>
      %308 = fir.load %307 : !fir.ref<f32>
      %309 = fir.convert %308 : (f32) -> f64
      hlfir.yield_element %309 : f64
    }
    %285:3 = hlfir.associate %284(%109) {adapt.valuebyref} : (!hlfir.expr<68x78x15xf64>, !fir.shape<3>) -> (!fir.ref<!fir.array<68x78x15xf64>>, !fir.ref<!fir.array<68x78x15xf64>>, i1)
    %286 = fir.shape %c68_26, %c78_27, %c15_28 : (index, index, index) -> !fir.shape<3>
    %287 = fir.embox %285#0(%286) : (!fir.ref<!fir.array<68x78x15xf64>>, !fir.shape<3>) -> !fir.box<!fir.array<68x78x15xf64>>
    %288 = fir.convert %287 : (!fir.box<!fir.array<68x78x15xf64>>) -> !fir.box<none>
    %289 = fir.call @_FortranAioOutputDescriptor(%283, %288) fastmath<contract> : (!fir.ref<i8>, !fir.box<none>) -> i1
    hlfir.end_associate %285#1, %285#2 : !fir.ref<!fir.array<68x78x15xf64>>, i1
    hlfir.destroy %284 : !hlfir.expr<68x78x15xf64>
    %290 = fir.call @_FortranAioEndIoStatement(%283) fastmath<contract> : (!fir.ref<i8>) -> i32
    %291 = fir.load %118#0 : !fir.ref<i32>
    %292 = fir.address_of(@_QQclX80a40c38ee47a5aede30bfbca1971818) : !fir.ref<!fir.char<1,53>>
    %293 = fir.convert %292 : (!fir.ref<!fir.char<1,53>>) -> !fir.ref<i8>
    %c114_i32_106 = arith.constant 114 : i32
    %294 = fir.call @_FortranAioBeginClose(%291, %293, %c114_i32_106) fastmath<contract> : (i32, !fir.ref<i8>, i32) -> !fir.ref<i8>
    %295 = fir.call @_FortranAioEndIoStatement(%294) fastmath<contract> : (!fir.ref<i8>) -> i32
    %296 = fir.address_of(@_QQclX80a40c38ee47a5aede30bfbca1971818) : !fir.ref<!fir.char<1,53>>
    %297 = fir.convert %296 : (!fir.ref<!fir.char<1,53>>) -> !fir.ref<i8>
    %c115_i32 = arith.constant 115 : i32
    %298 = fir.call @_FortranAioBeginOpenNewUnit(%297, %c115_i32) fastmath<contract> : (!fir.ref<i8>, i32) -> !fir.ref<i8>
    %true = arith.constant true
    %false = arith.constant false
    %false_107 = arith.constant false
    %false_108 = arith.constant false
    %false_109 = arith.constant false
    fir.call @_FortranAioEnableHandlers(%298, %true, %false, %false_107, %false_108, %false_109) fastmath<contract> : (!fir.ref<i8>, i1, i1, i1, i1, i1) -> ()
    %299 = fir.address_of(@_QQclX7A625F7265662E62696E) : !fir.ref<!fir.char<1,10>>
    %c10_110 = arith.constant 10 : index
    %300:2 = hlfir.declare %299 typeparams %c10_110 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QQclX7A625F7265662E62696E"} : (!fir.ref<!fir.char<1,10>>, index) -> (!fir.ref<!fir.char<1,10>>, !fir.ref<!fir.char<1,10>>)
    %301 = fir.convert %300#0 : (!fir.ref<!fir.char<1,10>>) -> !fir.ref<i8>
    %302 = fir.convert %c10_110 : (index) -> i64
    %303 = fir.call @_FortranAioSetFile(%298, %301, %302) fastmath<contract> : (!fir.ref<i8>, !fir.ref<i8>, i64) -> i1
    fir.if %303 {
      %307 = fir.address_of(@_QQclX73747265616D) : !fir.ref<!fir.char<1,6>>
      %c6_112 = arith.constant 6 : index
      %308:2 = hlfir.declare %307 typeparams %c6_112 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QQclX73747265616D"} : (!fir.ref<!fir.char<1,6>>, index) -> (!fir.ref<!fir.char<1,6>>, !fir.ref<!fir.char<1,6>>)
      %309 = fir.convert %308#0 : (!fir.ref<!fir.char<1,6>>) -> !fir.ref<i8>
      %310 = fir.convert %c6_112 : (index) -> i64
      %311 = fir.call @_FortranAioSetAccess(%298, %309, %310) fastmath<contract> : (!fir.ref<i8>, !fir.ref<i8>, i64) -> i1
      fir.if %311 {
        %312 = fir.address_of(@_QQclX756E666F726D6174746564) : !fir.ref<!fir.char<1,11>>
        %c11_113 = arith.constant 11 : index
        %313:2 = hlfir.declare %312 typeparams %c11_113 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QQclX756E666F726D6174746564"} : (!fir.ref<!fir.char<1,11>>, index) -> (!fir.ref<!fir.char<1,11>>, !fir.ref<!fir.char<1,11>>)
        %314 = fir.convert %313#0 : (!fir.ref<!fir.char<1,11>>) -> !fir.ref<i8>
        %315 = fir.convert %c11_113 : (index) -> i64
        %316 = fir.call @_FortranAioSetForm(%298, %314, %315) fastmath<contract> : (!fir.ref<i8>, !fir.ref<i8>, i64) -> i1
        fir.if %316 {
          %317 = fir.address_of(@_QQclX6F6C64) : !fir.ref<!fir.char<1,3>>
          %c3_114 = arith.constant 3 : index
          %318:2 = hlfir.declare %317 typeparams %c3_114 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QQclX6F6C64"} : (!fir.ref<!fir.char<1,3>>, index) -> (!fir.ref<!fir.char<1,3>>, !fir.ref<!fir.char<1,3>>)
          %319 = fir.convert %318#0 : (!fir.ref<!fir.char<1,3>>) -> !fir.ref<i8>
          %320 = fir.convert %c3_114 : (index) -> i64
          %321 = fir.call @_FortranAioSetStatus(%298, %319, %320) fastmath<contract> : (!fir.ref<i8>, !fir.ref<i8>, i64) -> i1
          fir.if %321 {
            %c4_i32_115 = arith.constant 4 : i32
            %322 = fir.call @_FortranAioGetNewUnit(%298, %118#0, %c4_i32_115) fastmath<contract> : (!fir.ref<i8>, !fir.ref<i32>, i32) -> i1
          }
        }
      }
    }
    %304 = fir.call @_FortranAioEndIoStatement(%298) fastmath<contract> : (!fir.ref<i8>) -> i32
    fir.store %304 to %29#0 : !fir.ref<i32>
    %305 = fir.load %29#0 : !fir.ref<i32>
    %c0_i32_111 = arith.constant 0 : i32
    %306 = arith.cmpi eq, %305, %c0_i32_111 : i32
    fir.if %306 {
      %cst_112 = arith.constant 0.000000e+00 : f64
      hlfir.assign %cst_112 to %12#0 : f64, !fir.ref<f64>
      %307 = fir.load %118#0 : !fir.ref<i32>
      %308 = fir.address_of(@_QQclX80a40c38ee47a5aede30bfbca1971818) : !fir.ref<!fir.char<1,53>>
      %309 = fir.convert %308 : (!fir.ref<!fir.char<1,53>>) -> !fir.ref<i8>
      %c118_i32 = arith.constant 118 : i32
      %310 = fir.call @_FortranAioBeginUnformattedInput(%307, %309, %c118_i32) fastmath<contract> : (i32, !fir.ref<i8>, i32) -> !fir.ref<i8>
      %311 = fir.shape %c68_9, %c78_10, %c15_11 : (index, index, index) -> !fir.shape<3>
      %312 = fir.embox %74#0(%311) : (!fir.ref<!fir.array<68x78x15xf64>>, !fir.shape<3>) -> !fir.box<!fir.array<68x78x15xf64>>
      %313 = fir.convert %312 : (!fir.box<!fir.array<68x78x15xf64>>) -> !fir.box<none>
      %314 = fir.call @_FortranAioInputDescriptor(%310, %313) fastmath<contract> : (!fir.ref<i8>, !fir.box<none>) -> i1
      %315 = fir.call @_FortranAioEndIoStatement(%310) fastmath<contract> : (!fir.ref<i8>) -> i32
      %316 = hlfir.elemental %106 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
      ^bb0(%arg0: index, %arg1: index, %arg2: index):
        %383 = hlfir.designate %107#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf32>>, index, index, index) -> !fir.ref<f32>
        %384 = fir.load %383 : !fir.ref<f32>
        %385 = fir.convert %384 : (f32) -> f64
        hlfir.yield_element %385 : f64
      }
      %317 = hlfir.elemental %106 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
      ^bb0(%arg0: index, %arg1: index, %arg2: index):
        %383 = hlfir.apply %316, %arg0, %arg1, %arg2 : (!hlfir.expr<68x78x15xf64>, index, index, index) -> f64
        %384 = hlfir.designate %74#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf64>>, index, index, index) -> !fir.ref<f64>
        %385 = fir.load %384 : !fir.ref<f64>
        %386 = arith.subf %383, %385 fastmath<contract> : f64
        hlfir.yield_element %386 : f64
      }
      %318 = hlfir.elemental %106 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
      ^bb0(%arg0: index, %arg1: index, %arg2: index):
        %383 = hlfir.apply %317, %arg0, %arg1, %arg2 : (!hlfir.expr<68x78x15xf64>, index, index, index) -> f64
        %384 = math.absf %383 fastmath<contract> : f64
        hlfir.yield_element %384 : f64
      }
      %319 = hlfir.maxval %318 {fastmath = #arith.fastmath<contract>} : (!hlfir.expr<68x78x15xf64>) -> f64
      %320 = hlfir.elemental %73 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
      ^bb0(%arg0: index, %arg1: index, %arg2: index):
        %383 = hlfir.designate %74#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf64>>, index, index, index) -> !fir.ref<f64>
        %384 = fir.load %383 : !fir.ref<f64>
        %385 = math.absf %384 fastmath<contract> : f64
        hlfir.yield_element %385 : f64
      }
      %321 = hlfir.maxval %320 {fastmath = #arith.fastmath<contract>} : (!hlfir.expr<68x78x15xf64>) -> f64
      %322 = arith.divf %319, %321 fastmath<contract> : f64
      hlfir.assign %322 to %10#0 : f64, !fir.ref<f64>
      hlfir.destroy %320 : !hlfir.expr<68x78x15xf64>
      hlfir.destroy %318 : !hlfir.expr<68x78x15xf64>
      hlfir.destroy %317 : !hlfir.expr<68x78x15xf64>
      hlfir.destroy %316 : !hlfir.expr<68x78x15xf64>
      %323 = fir.load %12#0 : !fir.ref<f64>
      %324 = fir.load %10#0 : !fir.ref<f64>
      %325 = arith.cmpf ogt, %323, %324 fastmath<contract> : f64
      %326 = arith.select %325, %323, %324 : f64
      hlfir.assign %326 to %12#0 : f64, !fir.ref<f64>
      %327 = fir.load %118#0 : !fir.ref<i32>
      %328 = fir.address_of(@_QQclX80a40c38ee47a5aede30bfbca1971818) : !fir.ref<!fir.char<1,53>>
      %329 = fir.convert %328 : (!fir.ref<!fir.char<1,53>>) -> !fir.ref<i8>
      %c119_i32 = arith.constant 119 : i32
      %330 = fir.call @_FortranAioBeginUnformattedInput(%327, %329, %c119_i32) fastmath<contract> : (i32, !fir.ref<i8>, i32) -> !fir.ref<i8>
      %331 = fir.shape %c68_9, %c78_10, %c15_11 : (index, index, index) -> !fir.shape<3>
      %332 = fir.embox %74#0(%331) : (!fir.ref<!fir.array<68x78x15xf64>>, !fir.shape<3>) -> !fir.box<!fir.array<68x78x15xf64>>
      %333 = fir.convert %332 : (!fir.box<!fir.array<68x78x15xf64>>) -> !fir.box<none>
      %334 = fir.call @_FortranAioInputDescriptor(%330, %333) fastmath<contract> : (!fir.ref<i8>, !fir.box<none>) -> i1
      %335 = fir.call @_FortranAioEndIoStatement(%330) fastmath<contract> : (!fir.ref<i8>) -> i32
      %336 = hlfir.elemental %115 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
      ^bb0(%arg0: index, %arg1: index, %arg2: index):
        %383 = hlfir.designate %116#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf32>>, index, index, index) -> !fir.ref<f32>
        %384 = fir.load %383 : !fir.ref<f32>
        %385 = fir.convert %384 : (f32) -> f64
        hlfir.yield_element %385 : f64
      }
      %337 = hlfir.elemental %115 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
      ^bb0(%arg0: index, %arg1: index, %arg2: index):
        %383 = hlfir.apply %336, %arg0, %arg1, %arg2 : (!hlfir.expr<68x78x15xf64>, index, index, index) -> f64
        %384 = hlfir.designate %74#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf64>>, index, index, index) -> !fir.ref<f64>
        %385 = fir.load %384 : !fir.ref<f64>
        %386 = arith.subf %383, %385 fastmath<contract> : f64
        hlfir.yield_element %386 : f64
      }
      %338 = hlfir.elemental %115 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
      ^bb0(%arg0: index, %arg1: index, %arg2: index):
        %383 = hlfir.apply %337, %arg0, %arg1, %arg2 : (!hlfir.expr<68x78x15xf64>, index, index, index) -> f64
        %384 = math.absf %383 fastmath<contract> : f64
        hlfir.yield_element %384 : f64
      }
      %339 = hlfir.maxval %338 {fastmath = #arith.fastmath<contract>} : (!hlfir.expr<68x78x15xf64>) -> f64
      %340 = hlfir.elemental %73 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
      ^bb0(%arg0: index, %arg1: index, %arg2: index):
        %383 = hlfir.designate %74#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf64>>, index, index, index) -> !fir.ref<f64>
        %384 = fir.load %383 : !fir.ref<f64>
        %385 = math.absf %384 fastmath<contract> : f64
        hlfir.yield_element %385 : f64
      }
      %341 = hlfir.maxval %340 {fastmath = #arith.fastmath<contract>} : (!hlfir.expr<68x78x15xf64>) -> f64
      %342 = arith.divf %339, %341 fastmath<contract> : f64
      hlfir.assign %342 to %10#0 : f64, !fir.ref<f64>
      hlfir.destroy %340 : !hlfir.expr<68x78x15xf64>
      hlfir.destroy %338 : !hlfir.expr<68x78x15xf64>
      hlfir.destroy %337 : !hlfir.expr<68x78x15xf64>
      hlfir.destroy %336 : !hlfir.expr<68x78x15xf64>
      %343 = fir.load %12#0 : !fir.ref<f64>
      %344 = fir.load %10#0 : !fir.ref<f64>
      %345 = arith.cmpf ogt, %343, %344 fastmath<contract> : f64
      %346 = arith.select %345, %343, %344 : f64
      hlfir.assign %346 to %12#0 : f64, !fir.ref<f64>
      %347 = fir.load %118#0 : !fir.ref<i32>
      %348 = fir.address_of(@_QQclX80a40c38ee47a5aede30bfbca1971818) : !fir.ref<!fir.char<1,53>>
      %349 = fir.convert %348 : (!fir.ref<!fir.char<1,53>>) -> !fir.ref<i8>
      %c120_i32 = arith.constant 120 : i32
      %350 = fir.call @_FortranAioBeginUnformattedInput(%347, %349, %c120_i32) fastmath<contract> : (i32, !fir.ref<i8>, i32) -> !fir.ref<i8>
      %351 = fir.shape %c68_9, %c78_10, %c15_11 : (index, index, index) -> !fir.shape<3>
      %352 = fir.embox %74#0(%351) : (!fir.ref<!fir.array<68x78x15xf64>>, !fir.shape<3>) -> !fir.box<!fir.array<68x78x15xf64>>
      %353 = fir.convert %352 : (!fir.box<!fir.array<68x78x15xf64>>) -> !fir.box<none>
      %354 = fir.call @_FortranAioInputDescriptor(%350, %353) fastmath<contract> : (!fir.ref<i8>, !fir.box<none>) -> i1
      %355 = fir.call @_FortranAioEndIoStatement(%350) fastmath<contract> : (!fir.ref<i8>) -> i32
      %356 = hlfir.elemental %109 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
      ^bb0(%arg0: index, %arg1: index, %arg2: index):
        %383 = hlfir.designate %110#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf32>>, index, index, index) -> !fir.ref<f32>
        %384 = fir.load %383 : !fir.ref<f32>
        %385 = fir.convert %384 : (f32) -> f64
        hlfir.yield_element %385 : f64
      }
      %357 = hlfir.elemental %109 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
      ^bb0(%arg0: index, %arg1: index, %arg2: index):
        %383 = hlfir.apply %356, %arg0, %arg1, %arg2 : (!hlfir.expr<68x78x15xf64>, index, index, index) -> f64
        %384 = hlfir.designate %74#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf64>>, index, index, index) -> !fir.ref<f64>
        %385 = fir.load %384 : !fir.ref<f64>
        %386 = arith.subf %383, %385 fastmath<contract> : f64
        hlfir.yield_element %386 : f64
      }
      %358 = hlfir.elemental %109 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
      ^bb0(%arg0: index, %arg1: index, %arg2: index):
        %383 = hlfir.apply %357, %arg0, %arg1, %arg2 : (!hlfir.expr<68x78x15xf64>, index, index, index) -> f64
        %384 = math.absf %383 fastmath<contract> : f64
        hlfir.yield_element %384 : f64
      }
      %359 = hlfir.maxval %358 {fastmath = #arith.fastmath<contract>} : (!hlfir.expr<68x78x15xf64>) -> f64
      %360 = hlfir.elemental %73 unordered : (!fir.shape<3>) -> !hlfir.expr<68x78x15xf64> {
      ^bb0(%arg0: index, %arg1: index, %arg2: index):
        %383 = hlfir.designate %74#0 (%arg0, %arg1, %arg2)  : (!fir.ref<!fir.array<68x78x15xf64>>, index, index, index) -> !fir.ref<f64>
        %384 = fir.load %383 : !fir.ref<f64>
        %385 = math.absf %384 fastmath<contract> : f64
        hlfir.yield_element %385 : f64
      }
      %361 = hlfir.maxval %360 {fastmath = #arith.fastmath<contract>} : (!hlfir.expr<68x78x15xf64>) -> f64
      %362 = arith.divf %359, %361 fastmath<contract> : f64
      hlfir.assign %362 to %10#0 : f64, !fir.ref<f64>
      hlfir.destroy %360 : !hlfir.expr<68x78x15xf64>
      hlfir.destroy %358 : !hlfir.expr<68x78x15xf64>
      hlfir.destroy %357 : !hlfir.expr<68x78x15xf64>
      hlfir.destroy %356 : !hlfir.expr<68x78x15xf64>
      %363 = fir.load %12#0 : !fir.ref<f64>
      %364 = fir.load %10#0 : !fir.ref<f64>
      %365 = arith.cmpf ogt, %363, %364 fastmath<contract> : f64
      %366 = arith.select %365, %363, %364 : f64
      hlfir.assign %366 to %12#0 : f64, !fir.ref<f64>
      %367 = fir.load %118#0 : !fir.ref<i32>
      %368 = fir.address_of(@_QQclX80a40c38ee47a5aede30bfbca1971818) : !fir.ref<!fir.char<1,53>>
      %369 = fir.convert %368 : (!fir.ref<!fir.char<1,53>>) -> !fir.ref<i8>
      %c121_i32 = arith.constant 121 : i32
      %370 = fir.call @_FortranAioBeginClose(%367, %369, %c121_i32) fastmath<contract> : (i32, !fir.ref<i8>, i32) -> !fir.ref<i8>
      %371 = fir.call @_FortranAioEndIoStatement(%370) fastmath<contract> : (!fir.ref<i8>) -> i32
      %c6_i32_113 = arith.constant 6 : i32
      %372 = fir.address_of(@_QQclX80a40c38ee47a5aede30bfbca1971818) : !fir.ref<!fir.char<1,53>>
      %373 = fir.convert %372 : (!fir.ref<!fir.char<1,53>>) -> !fir.ref<i8>
      %c122_i32 = arith.constant 122 : i32
      %374 = fir.call @_FortranAioBeginExternalListOutput(%c6_i32_113, %373, %c122_i32) fastmath<contract> : (i32, !fir.ref<i8>, i32) -> !fir.ref<i8>
      %375 = fir.address_of(@_QQclX6D61782072656C206572722076732066703634207265666572656E63653A) : !fir.ref<!fir.char<1,30>>
      %c30 = arith.constant 30 : index
      %376:2 = hlfir.declare %375 typeparams %c30 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QQclX6D61782072656C206572722076732066703634207265666572656E63653A"} : (!fir.ref<!fir.char<1,30>>, index) -> (!fir.ref<!fir.char<1,30>>, !fir.ref<!fir.char<1,30>>)
      %377 = fir.convert %376#0 : (!fir.ref<!fir.char<1,30>>) -> !fir.ref<i8>
      %378 = fir.convert %c30 : (index) -> i64
      %379 = fir.call @_FortranAioOutputAscii(%374, %377, %378) fastmath<contract> : (!fir.ref<i8>, !fir.ref<i8>, i64) -> i1
      %380 = fir.load %12#0 : !fir.ref<f64>
      %381 = fir.call @_FortranAioOutputReal64(%374, %380) fastmath<contract> : (!fir.ref<i8>, f64) -> i1
      %382 = fir.call @_FortranAioEndIoStatement(%374) fastmath<contract> : (!fir.ref<i8>) -> i32
    }
    return
  }
  func.func private @_QFPmake_field(%arg0: !fir.ref<!fir.array<68x78x15xf64>> {fir.bindc_name = "f"}, %arg1: !fir.ref<f64> {fir.bindc_name = "a", fir.read_only}, %arg2: !fir.ref<f64> {fir.bindc_name = "b", fir.read_only}, %arg3: !fir.ref<f64> {fir.bindc_name = "c", fir.read_only}, %arg4: !fir.ref<tuple<!fir.ref<i64>>> {fir.host_assoc}) attributes {fir.host_symbol = @_QQmain, llvm.linkage = #llvm.linkage<internal>} {
    %0 = fir.dummy_scope : !fir.dscope
    %1 = fir.address_of(@_QFECnz) : !fir.ref<i32>
    %2:2 = hlfir.declare %1 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECnz"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %3 = fir.address_of(@_QFECszi) : !fir.ref<i32>
    %4:2 = hlfir.declare %3 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECszi"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %5 = fir.address_of(@_QFECszj) : !fir.ref<i32>
    %6:2 = hlfir.declare %5 {fortran_attrs = #fir.var_attrs<parameter>, uniq_name = "_QFECszj"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %c0_i32 = arith.constant 0 : i32
    %7 = fir.coordinate_of %arg4, %c0_i32 : (!fir.ref<tuple<!fir.ref<i64>>>, i32) -> !fir.llvm_ptr<!fir.ref<i64>>
    %8 = fir.load %7 : !fir.llvm_ptr<!fir.ref<i64>>
    %9:2 = hlfir.declare %8 {fortran_attrs = #fir.var_attrs<host_assoc>, uniq_name = "_QFEseed"} : (!fir.ref<i64>) -> (!fir.ref<i64>, !fir.ref<i64>)
    %10:2 = hlfir.declare %arg1 dummy_scope %0 arg 2 {fortran_attrs = #fir.var_attrs<intent_in>, uniq_name = "_QFFmake_fieldEa"} : (!fir.ref<f64>, !fir.dscope) -> (!fir.ref<f64>, !fir.ref<f64>)
    %11:2 = hlfir.declare %arg2 dummy_scope %0 arg 3 {fortran_attrs = #fir.var_attrs<intent_in>, uniq_name = "_QFFmake_fieldEb"} : (!fir.ref<f64>, !fir.dscope) -> (!fir.ref<f64>, !fir.ref<f64>)
    %12:2 = hlfir.declare %arg3 dummy_scope %0 arg 4 {fortran_attrs = #fir.var_attrs<intent_in>, uniq_name = "_QFFmake_fieldEc"} : (!fir.ref<f64>, !fir.dscope) -> (!fir.ref<f64>, !fir.ref<f64>)
    %c68 = arith.constant 68 : index
    %c78 = arith.constant 78 : index
    %c15 = arith.constant 15 : index
    %13 = fir.shape %c68, %c78, %c15 : (index, index, index) -> !fir.shape<3>
    %14:2 = hlfir.declare %arg0(%13) dummy_scope %0 arg 1 {fortran_attrs = #fir.var_attrs<intent_out>, uniq_name = "_QFFmake_fieldEf"} : (!fir.ref<!fir.array<68x78x15xf64>>, !fir.shape<3>, !fir.dscope) -> (!fir.ref<!fir.array<68x78x15xf64>>, !fir.ref<!fir.array<68x78x15xf64>>)
    %15 = fir.alloca i32 {bindc_name = "i", uniq_name = "_QFFmake_fieldEi"}
    %16:2 = hlfir.declare %15 {uniq_name = "_QFFmake_fieldEi"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %17 = fir.alloca i32 {bindc_name = "j", uniq_name = "_QFFmake_fieldEj"}
    %18:2 = hlfir.declare %17 {uniq_name = "_QFFmake_fieldEj"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %19 = fir.alloca i32 {bindc_name = "k", uniq_name = "_QFFmake_fieldEk"}
    %20:2 = hlfir.declare %19 {uniq_name = "_QFFmake_fieldEk"} : (!fir.ref<i32>) -> (!fir.ref<i32>, !fir.ref<i32>)
    %21 = fir.alloca f64 {bindc_name = "r", uniq_name = "_QFFmake_fieldEr"}
    %22:2 = hlfir.declare %21 {uniq_name = "_QFFmake_fieldEr"} : (!fir.ref<f64>) -> (!fir.ref<f64>, !fir.ref<f64>)
    %c1_i32 = arith.constant 1 : i32
    %c15_i32 = arith.constant 15 : i32
    %c1_i32_0 = arith.constant 1 : i32
    fir.do_loop %arg5 = %c1_i32 to %c15_i32 step %c1_i32_0 : i32 {
      fir.store %arg5 to %20#0 : !fir.ref<i32>
      %c1_i32_1 = arith.constant 1 : i32
      %c78_i32 = arith.constant 78 : i32
      %c1_i32_2 = arith.constant 1 : i32
      fir.do_loop %arg6 = %c1_i32_1 to %c78_i32 step %c1_i32_2 : i32 {
        fir.store %arg6 to %18#0 : !fir.ref<i32>
        %c1_i32_4 = arith.constant 1 : i32
        %c68_i32 = arith.constant 68 : i32
        %c1_i32_5 = arith.constant 1 : i32
        fir.do_loop %arg7 = %c1_i32_4 to %c68_i32 step %c1_i32_5 : i32 {
          fir.store %arg7 to %16#0 : !fir.ref<i32>
          %c1103515245_i64 = arith.constant 1103515245 : i64
          %56 = fir.load %9#0 : !fir.ref<i64>
          %57 = arith.muli %c1103515245_i64, %56 : i64
          %c12345_i64 = arith.constant 12345 : i64
          %58 = arith.addi %57, %c12345_i64 : i64
          %c2147483648_i64 = arith.constant 2147483648 : i64
          %59 = arith.remsi %58, %c2147483648_i64 : i64
          hlfir.assign %59 to %9#0 : i64, !fir.ref<i64>
          %60 = fir.load %9#0 : !fir.ref<i64>
          %61 = fir.convert %60 : (i64) -> f64
          %cst = arith.constant 0x41E0000000000000 : f64
          %62 = arith.divf %61, %cst fastmath<contract> : f64
          %cst_7 = arith.constant 5.000000e-01 : f64
          %63 = arith.subf %62, %cst_7 fastmath<contract> : f64
          hlfir.assign %63 to %22#0 : f64, !fir.ref<f64>
          %cst_8 = arith.constant 1.000000e-05 : f64
          %cst_9 = arith.constant 6.000000e-01 : f64
          %64 = fir.load %10#0 : !fir.ref<f64>
          %65 = fir.load %16#0 : !fir.ref<i32>
          %66 = fir.convert %65 : (i32) -> f64
          %67 = arith.mulf %64, %66 fastmath<contract> : f64
          %68 = fir.load %11#0 : !fir.ref<f64>
          %69 = fir.load %18#0 : !fir.ref<i32>
          %70 = fir.convert %69 : (i32) -> f64
          %71 = arith.mulf %68, %70 fastmath<contract> : f64
          %72 = arith.addf %67, %71 fastmath<contract> : f64
          %73 = fir.load %12#0 : !fir.ref<f64>
          %74 = fir.load %20#0 : !fir.ref<i32>
          %75 = fir.convert %74 : (i32) -> f64
          %76 = arith.mulf %73, %75 fastmath<contract> : f64
          %77 = arith.addf %72, %76 fastmath<contract> : f64
          %78 = math.sin %77 fastmath<contract> : f64
          %79 = arith.mulf %cst_9, %78 fastmath<contract> : f64
          %80 = fir.load %11#0 : !fir.ref<f64>
          %81 = fir.load %16#0 : !fir.ref<i32>
          %82 = fir.convert %81 : (i32) -> f64
          %83 = arith.mulf %80, %82 fastmath<contract> : f64
          %84 = fir.load %10#0 : !fir.ref<f64>
          %85 = fir.load %18#0 : !fir.ref<i32>
          %86 = fir.convert %85 : (i32) -> f64
          %87 = arith.mulf %84, %86 fastmath<contract> : f64
          %88 = arith.subf %83, %87 fastmath<contract> : f64
          %89 = math.cos %88 fastmath<contract> : f64
          %90 = arith.mulf %79, %89 fastmath<contract> : f64
          %cst_10 = arith.constant 4.000000e-01 : f64
          %91 = fir.load %22#0 : !fir.ref<f64>
          %92 = arith.mulf %cst_10, %91 fastmath<contract> : f64
          %93 = arith.addf %90, %92 fastmath<contract> : f64
          %94 = hlfir.no_reassoc %93 : f64
          %95 = arith.mulf %cst_8, %94 fastmath<contract> : f64
          %96 = fir.load %16#0 : !fir.ref<i32>
          %97 = fir.convert %96 : (i32) -> i64
          %98 = fir.load %18#0 : !fir.ref<i32>
          %99 = fir.convert %98 : (i32) -> i64
          %100 = fir.load %20#0 : !fir.ref<i32>
          %101 = fir.convert %100 : (i32) -> i64
          %102 = hlfir.designate %14#0 (%97, %99, %101)  : (!fir.ref<!fir.array<68x78x15xf64>>, i64, i64, i64) -> !fir.ref<f64>
          hlfir.assign %95 to %102 : f64, !fir.ref<f64>
        }
        %45 = fir.convert %c1_i32_4 : (i32) -> index
        %46 = fir.convert %c68_i32 : (i32) -> index
        %47 = fir.convert %c1_i32_5 : (i32) -> index
        %c0_6 = arith.constant 0 : index
        %48 = arith.subi %46, %45 : index
        %49 = arith.addi %48, %47 : index
        %50 = arith.divsi %49, %47 : index
        %51 = arith.cmpi slt, %50, %c0_6 : index
        %52 = arith.select %51, %c0_6, %50 : index
        %53 = arith.muli %52, %47 : index
        %54 = arith.addi %45, %53 : index
        %55 = fir.convert %54 : (index) -> i32
        fir.store %55 to %16#0 : !fir.ref<i32>
      }
      %34 = fir.convert %c1_i32_1 : (i32) -> index
      %35 = fir.convert %c78_i32 : (i32) -> index
      %36 = fir.convert %c1_i32_2 : (i32) -> index
      %c0_3 = arith.constant 0 : index
      %37 = arith.subi %35, %34 : index
      %38 = arith.addi %37, %36 : index
      %39 = arith.divsi %38, %36 : index
      %40 = arith.cmpi slt, %39, %c0_3 : index
      %41 = arith.select %40, %c0_3, %39 : index
      %42 = arith.muli %41, %36 : index
      %43 = arith.addi %34, %42 : index
      %44 = fir.convert %43 : (index) -> i32
      fir.store %44 to %18#0 : !fir.ref<i32>
    }
    %23 = fir.convert %c1_i32 : (i32) -> index
    %24 = fir.convert %c15_i32 : (i32) -> index
    %25 = fir.convert %c1_i32_0 : (i32) -> index
    %c0 = arith.constant 0 : index
    %26 = arith.subi %24, %23 : index
    %27 = arith.addi %26, %25 : index
    %28 = arith.divsi %27, %25 : index
    %29 = arith.cmpi slt, %28, %c0 : index
    %30 = arith.select %29, %c0, %28 : index
    %31 = arith.muli %30, %25 : index
    %32 = arith.addi %23, %31 : index
    %33 = fir.convert %32 : (index) -> i32
    fir.store %33 to %20#0 : !fir.ref<i32>
    return
  }
  fir.global internal @_QFECamplitude constant : f32 {
    %cst = arith.constant 1.000000e+00 : f32
    fir.has_value %cst : f32
  }
  fir.global internal @_QFECareat constant : f32 {
    %cst = arith.constant 6.250000e+08 : f32
    fir.has_value %cst : f32
  }
  fir.global internal @_QFEfld {alignment = 64 : i64} : !fir.array<68x78x15xf64> {
    %0 = fir.zero_bits !fir.array<68x78x15xf64>
    fir.has_value %0 : !fir.array<68x78x15xf64>
  }
  fir.global internal @_QFEChalo constant : i32 {
    %c4_i32 = arith.constant 4 : i32
    fir.has_value %c4_i32 : i32
  }
  fir.global internal @_QFECie constant : i32 {
    %c64_i32 = arith.constant 64 : i32
    fir.has_value %c64_i32 : i32
  }
  fir.global internal @_QFECieq constant : i32 {
    %c64_i32 = arith.constant 64 : i32
    fir.has_value %c64_i32 : i32
  }
  fir.global internal @_QFECis constant : i32 {
    %c5_i32 = arith.constant 5 : i32
    fir.has_value %c5_i32 : i32
  }
  fir.global internal @_QFECisq constant : i32 {
    %c4_i32 = arith.constant 4 : i32
    fir.has_value %c4_i32 : i32
  }
  fir.global internal @_QFECje constant : i32 {
    %c74_i32 = arith.constant 74 : i32
    fir.has_value %c74_i32 : i32
  }
  fir.global internal @_QFECjeq constant : i32 {
    %c74_i32 = arith.constant 74 : i32
    fir.has_value %c74_i32 : i32
  }
  fir.global internal @_QFECjs constant : i32 {
    %c5_i32 = arith.constant 5 : i32
    fir.has_value %c5_i32 : i32
  }
  fir.global internal @_QFECjsq constant : i32 {
    %c4_i32 = arith.constant 4 : i32
    fir.has_value %c4_i32 : i32
  }
  fir.global internal @_QFEkappa_h {alignment = 64 : i64} : !fir.array<68x78xf32> {
    %0 = fir.zero_bits !fir.array<68x78xf32>
    fir.has_value %0 : !fir.array<68x78xf32>
  }
  fir.global internal @_QFEmask2dbu {alignment = 64 : i64} : !fir.array<68x78xf32> {
    %0 = fir.zero_bits !fir.array<68x78xf32>
    fir.has_value %0 : !fir.array<68x78xf32>
  }
  fir.global internal @_QFEmask2dt {alignment = 64 : i64} : !fir.array<68x78xf32> {
    %0 = fir.zero_bits !fir.array<68x78xf32>
    fir.has_value %0 : !fir.array<68x78xf32>
  }
  fir.global internal @_QFECnih constant : i32 {
    %c60_i32 = arith.constant 60 : i32
    fir.has_value %c60_i32 : i32
  }
  fir.global internal @_QFECnjh constant : i32 {
    %c70_i32 = arith.constant 70 : i32
    fir.has_value %c70_i32 : i32
  }
  fir.global internal @_QFEnorm_h {alignment = 64 : i64} : !fir.array<68x78x15xf32> {
    %0 = fir.zero_bits !fir.array<68x78x15xf32>
    fir.has_value %0 : !fir.array<68x78x15xf32>
  }
  fir.global internal @_QFECnsteps constant : i32 {
    %c11_i32 = arith.constant 11 : i32
    fir.has_value %c11_i32 : i32
  }
  fir.global internal @_QFECnz constant : i32 {
    %c15_i32 = arith.constant 15 : i32
    fir.has_value %c15_i32 : i32
  }
  fir.global internal @_QFECoffset constant : i32 {
    %c1_i32 = arith.constant 1 : i32
    fir.has_value %c1_i32 : i32
  }
  fir.global internal @_QFEref {alignment = 64 : i64} : !fir.array<68x78x15xf64> {
    %0 = fir.zero_bits !fir.array<68x78x15xf64>
    fir.has_value %0 : !fir.array<68x78x15xf64>
  }
  fir.global internal @_QFECrk constant : i32 {
    %c4_i32 = arith.constant 4 : i32
    fir.has_value %c4_i32 : i32
  }
  fir.global internal @_QFEsh_xx {alignment = 64 : i64} : !fir.array<68x78x15xf32> {
    %0 = fir.zero_bits !fir.array<68x78x15xf32>
    fir.has_value %0 : !fir.array<68x78x15xf32>
  }
  fir.global internal @_QFEsh_xy {alignment = 64 : i64} : !fir.array<68x78x15xf32> {
    %0 = fir.zero_bits !fir.array<68x78x15xf32>
    fir.has_value %0 : !fir.array<68x78x15xf32>
  }
  fir.global internal @_QFEsh_xy_h {alignment = 64 : i64} : !fir.array<68x78x15xf32> {
    %0 = fir.zero_bits !fir.array<68x78x15xf32>
    fir.has_value %0 : !fir.array<68x78x15xf32>
  }
  fir.global internal @_QFEsqr_h {alignment = 64 : i64} : !fir.array<68x78xf32> {
    %0 = fir.zero_bits !fir.array<68x78xf32>
    fir.has_value %0 : !fir.array<68x78xf32>
  }
  fir.global internal @_QFECstencil_points constant : i32 {
    %c9_i32 = arith.constant 9 : i32
    fir.has_value %c9_i32 : i32
  }
  fir.global internal @_QFECstencil_size constant : i32 {
    %c3_i32 = arith.constant 3 : i32
    fir.has_value %c3_i32 : i32
  }
  fir.global internal @_QFECsubroundoff_shear constant : f32 {
    %cst = arith.constant 1.000000e-30 : f32
    fir.has_value %cst : f32
  }
  fir.global internal @_QFECszi constant : i32 {
    %c68_i32 = arith.constant 68 : i32
    fir.has_value %c68_i32 : i32
  }
  fir.global internal @_QFECszj constant : i32 {
    %c78_i32 = arith.constant 78 : i32
    fir.has_value %c78_i32 : i32
  }
  fir.global internal @_QFEtxx {alignment = 64 : i64} : !fir.array<68x78x15xf32> {
    %0 = fir.zero_bits !fir.array<68x78x15xf32>
    fir.has_value %0 : !fir.array<68x78x15xf32>
  }
  fir.global internal @_QFEtxy {alignment = 64 : i64} : !fir.array<68x78x15xf32> {
    %0 = fir.zero_bits !fir.array<68x78x15xf32>
    fir.has_value %0 : !fir.array<68x78x15xf32>
  }
  fir.global internal @_QFEtxy_h {alignment = 64 : i64} : !fir.array<68x78xf32> {
    %0 = fir.zero_bits !fir.array<68x78xf32>
    fir.has_value %0 : !fir.array<68x78xf32>
  }
  fir.global internal @_QFEtyy {alignment = 64 : i64} : !fir.array<68x78x15xf32> {
    %0 = fir.zero_bits !fir.array<68x78x15xf32>
    fir.has_value %0 : !fir.array<68x78x15xf32>
  }
  fir.global internal @_QFEvort_xy {alignment = 64 : i64} : !fir.array<68x78x15xf32> {
    %0 = fir.zero_bits !fir.array<68x78x15xf32>
    fir.has_value %0 : !fir.array<68x78x15xf32>
  }
  fir.global internal @_QFEvort_xy_h {alignment = 64 : i64} : !fir.array<68x78x15xf32> {
    %0 = fir.zero_bits !fir.array<68x78x15xf32>
    fir.has_value %0 : !fir.array<68x78x15xf32>
  }
  fir.global internal @_QFEx {alignment = 64 : i64} : !fir.array<27xf32> {
    %0 = fir.zero_bits !fir.array<27xf32>
    fir.has_value %0 : !fir.array<27xf32>
  }
  func.func private @_FortranASystemClockCount(i32) -> i64 attributes {fir.runtime}
  func.func private @_FortranASystemClockCountRate(i32) -> i64 attributes {fir.runtime}
  fir.global internal @_QQro.1xi4.0(dense<9> : tensor<1xi32>) {alignment = 64 : i64} constant : !fir.array<1xi32>
  func.func private @mlp_forward(!fir.ref<!fir.array<?xf32>>, !fir.ref<!fir.array<?xf32>>) attributes {fir.bindc_name = "mlp_forward", fir.proc_attrs = #fir.proc_attrs<bind_c>}
  func.func private @_FortranAioBeginExternalListOutput(i32, !fir.ref<i8>, i32) -> !fir.ref<i8> attributes {fir.io, fir.runtime}
  fir.global linkonce @_QQclX80a40c38ee47a5aede30bfbca1971818 constant : !fir.char<1,53> {
    %0 = fir.string_lit "/scratch/taghipouranvari.s/FTORCH/zb_run/zb_host.f90\00"(53) : !fir.char<1,53>
    fir.has_value %0 : !fir.char<1,53>
  }
  func.func private @_FortranAioOutputAscii(!fir.ref<i8>, !fir.ref<i8>, i64) -> i1 attributes {fir.io, fir.runtime}
  fir.global linkonce @_QQclX7065722D73746570206D733A constant : !fir.char<1,12> {
    %0 = fir.string_lit "per-step ms:"(12) : !fir.char<1,12>
    fir.has_value %0 : !fir.char<1,12>
  }
  func.func private @_FortranAioOutputReal32(!fir.ref<i8>, f32) -> i1 attributes {fir.io, fir.runtime}
  func.func private @_FortranAioEndIoStatement(!fir.ref<i8>) -> i32 attributes {fir.io, fir.runtime}
  fir.global linkonce @_QQclX636865636B73756D205478783A constant : !fir.char<1,13> {
    %0 = fir.string_lit "checksum Txx:"(13) : !fir.char<1,13>
    fir.has_value %0 : !fir.char<1,13>
  }
  func.func private @_FortranAioOutputReal64(!fir.ref<i8>, f64) -> i1 attributes {fir.io, fir.runtime}
  fir.global linkonce @_QQclX20205479793A constant : !fir.char<1,6> {
    %0 = fir.string_lit "  Tyy:"(6) : !fir.char<1,6>
    fir.has_value %0 : !fir.char<1,6>
  }
  fir.global linkonce @_QQclX20205478793A constant : !fir.char<1,6> {
    %0 = fir.string_lit "  Txy:"(6) : !fir.char<1,6>
    fir.has_value %0 : !fir.char<1,6>
  }
  func.func private @_FortranAioBeginOpenNewUnit(!fir.ref<i8>, i32) -> !fir.ref<i8> attributes {fir.io, fir.runtime}
  func.func private @_FortranAioSetFile(!fir.ref<i8>, !fir.ref<i8>, i64) -> i1 attributes {fir.io, fir.runtime}
  fir.global linkonce @_QQclX7A625F6F75742E62696E constant : !fir.char<1,10> {
    %0 = fir.string_lit "zb_out.bin"(10) : !fir.char<1,10>
    fir.has_value %0 : !fir.char<1,10>
  }
  func.func private @_FortranAioSetAccess(!fir.ref<i8>, !fir.ref<i8>, i64) -> i1 attributes {fir.io, fir.runtime}
  fir.global linkonce @_QQclX73747265616D constant : !fir.char<1,6> {
    %0 = fir.string_lit "stream"(6) : !fir.char<1,6>
    fir.has_value %0 : !fir.char<1,6>
  }
  func.func private @_FortranAioSetForm(!fir.ref<i8>, !fir.ref<i8>, i64) -> i1 attributes {fir.io, fir.runtime}
  fir.global linkonce @_QQclX756E666F726D6174746564 constant : !fir.char<1,11> {
    %0 = fir.string_lit "unformatted"(11) : !fir.char<1,11>
    fir.has_value %0 : !fir.char<1,11>
  }
  func.func private @_FortranAioSetStatus(!fir.ref<i8>, !fir.ref<i8>, i64) -> i1 attributes {fir.io, fir.runtime}
  fir.global linkonce @_QQclX7265706C616365 constant : !fir.char<1,7> {
    %0 = fir.string_lit "replace"(7) : !fir.char<1,7>
    fir.has_value %0 : !fir.char<1,7>
  }
  func.func private @_FortranAioGetNewUnit(!fir.ref<i8>, !fir.ref<i32>, i32) -> i1 attributes {fir.io, fir.runtime}
  func.func private @_FortranAioBeginUnformattedOutput(i32, !fir.ref<i8>, i32) -> !fir.ref<i8> attributes {fir.io, fir.runtime}
  func.func private @_FortranAioOutputDescriptor(!fir.ref<i8>, !fir.box<none>) -> i1 attributes {fir.io, fir.runtime}
  func.func private @_FortranAioBeginClose(i32, !fir.ref<i8>, i32) -> !fir.ref<i8> attributes {fir.io, fir.runtime}
  func.func private @_FortranAioEnableHandlers(!fir.ref<i8>, i1, i1, i1, i1, i1) attributes {fir.io, fir.runtime}
  fir.global linkonce @_QQclX7A625F7265662E62696E constant : !fir.char<1,10> {
    %0 = fir.string_lit "zb_ref.bin"(10) : !fir.char<1,10>
    fir.has_value %0 : !fir.char<1,10>
  }
  fir.global linkonce @_QQclX6F6C64 constant : !fir.char<1,3> {
    %0 = fir.string_lit "old"(3) : !fir.char<1,3>
    fir.has_value %0 : !fir.char<1,3>
  }
  func.func private @_FortranAioBeginUnformattedInput(i32, !fir.ref<i8>, i32) -> !fir.ref<i8> attributes {fir.io, fir.runtime}
  func.func private @_FortranAioInputDescriptor(!fir.ref<i8>, !fir.box<none>) -> i1 attributes {fir.io, fir.runtime}
  fir.global linkonce @_QQclX6D61782072656C206572722076732066703634207265666572656E63653A constant : !fir.char<1,30> {
    %0 = fir.string_lit "max rel err vs fp64 reference:"(30) : !fir.char<1,30>
    fir.has_value %0 : !fir.char<1,30>
  }
  func.func private @_FortranAProgramStart(i32, !llvm.ptr, !llvm.ptr, !llvm.ptr)
  func.func private @_FortranAProgramEndStatement()
  func.func private @fortis_pack(!fir.ref<!fir.array<27xf32>>, i32) attributes {fir.bindc_name = "fortis_pack", fir.proc_attrs = #fir.proc_attrs<bind_c>}
  func.func private @fortis_unpack(!fir.ref<!fir.array<3xf32>>, i32) attributes {fir.bindc_name = "fortis_unpack", fir.proc_attrs = #fir.proc_attrs<bind_c>}
  func.func private @fortis_begin(i32) attributes {fir.bindc_name = "fortis_begin", fir.proc_attrs = #fir.proc_attrs<bind_c>}
  func.func private @mlp_forward_batched() attributes {fir.bindc_name = "mlp_forward_batched", fir.proc_attrs = #fir.proc_attrs<bind_c>}
  func.func private @fortis_gather(!fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78x15xf32>>) attributes {fir.bindc_name = "fortis_gather", fir.proc_attrs = #fir.proc_attrs<bind_c>}
  func.func private @fortis_scatter(i32, !fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78xf32>>, !fir.ref<!fir.array<68x78xf32>>, !fir.ref<!fir.array<68x78x15xf32>>, !fir.ref<!fir.array<68x78x15xf32>>) attributes {fir.bindc_name = "fortis_scatter", fir.proc_attrs = #fir.proc_attrs<bind_c>}
  func.func @main(%arg0: i32, %arg1: !llvm.ptr, %arg2: !llvm.ptr) -> i32 {
    %0 = fir.zero_bits !fir.ref<tuple<i32, !fir.ref<!fir.array<0xtuple<!fir.ref<i8>, !fir.ref<i8>>>>>>
    fir.call @_FortranAProgramStart(%arg0, %arg1, %arg2, %0) fastmath<contract> : (i32, !llvm.ptr, !llvm.ptr, !fir.ref<tuple<i32, !fir.ref<!fir.array<0xtuple<!fir.ref<i8>, !fir.ref<i8>>>>>>) -> ()
    fir.call @_QQmain() fastmath<contract> : () -> ()
    %c0_i32 = arith.constant 0 : i32
    fir.call @_FortranAProgramEndStatement() fastmath<contract> : () -> ()
    return %c0_i32 : i32
  }
}

