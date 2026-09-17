#include <cstdlib>
// FORTIS fusion pass v3: N-dim warp mapping, standalone parallel groups, init producers,
// subview-aware addressing, batch-aware GEMM lowering, WAR renaming.
#include "mlir/Dialect/Affine/IR/AffineOps.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/GPU/IR/GPUDialect.h"
#include "mlir/Dialect/Linalg/IR/Linalg.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/IRMapping.h"
#include "mlir/IR/SymbolTable.h"
#include "mlir/InitAllDialects.h"
#include "mlir/Pass/Pass.h"
#include "llvm/ADT/MapVector.h"
#include "mlir/Tools/mlir-opt/MlirOptMain.h"

using namespace mlir;

namespace {

struct Group {
  linalg::LinalgOp red;            // reduction op, or null for a standalone group
  Operation *single = nullptr;     // standalone parallel op or copy
  SmallVector<Operation*> epi;     // epilogue ops of a reduction group
  bool closed = false;
};

struct FortisFusePass
    : public PassWrapper<FortisFusePass, OperationPass<ModuleOp>> {
  static constexpr int64_t kConvLibMinMACs = int64_t(1) << 24;   // conv MACs above which cuDNN is used
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(FortisFusePass)

  DenseMap<Value, Value> rename;        // WAR renaming
  DenseMap<Operation*, Operation*> initProducer;   // reduction -> absorbed producer of its init (chain follows copies)
  DenseMap<Operation*, Operation*> chainNext;      // absorbed copy -> producer of its source
  IRMapping map;                        // host value -> kernel value (per kernel)
  gpu::GPUFuncOp curFunc;               // kernel being built
  SmallVector<Value> curOperands;       // host values passed to it, in argument order
  std::optional<Location> kloc;
  // Lazily turn a host value into a kernel argument.
  Value karg(Value host) {
    if (Value m = map.lookupOrNull(host)) return m;
    BlockArgument a = curFunc.getBody().front().addArgument(host.getType(), *kloc);
    map.map(host, a);
    curOperands.push_back(host);
    return a;
  }
  DenseMap<Value, Value> svMemo;        // host subview -> in-kernel subview (per kernel)

  void getDependentDialects(DialectRegistry &registry) const override {
    registry.insert<gpu::GPUDialect, scf::SCFDialect, arith::ArithDialect,
                    memref::MemRefDialect, affine::AffineDialect, func::FuncDialect>();
  }
  StringRef getArgument() const final { return "fortis-fuse"; }
  StringRef getDescription() const final { return "Fuse a linalg op chain into GPU kernels"; }

  Value phys(Value v) { Value r = rename.lookup(v); return r ? r : v; }
  static Value viewSource(Value v) {
    if (auto o = v.getDefiningOp<memref::SubViewOp>()) return o.getSource();
    if (auto o = v.getDefiningOp<memref::ExpandShapeOp>()) return o.getSrc();
    if (auto o = v.getDefiningOp<memref::CollapseShapeOp>()) return o.getSrc();
    if (auto o = v.getDefiningOp<memref::CastOp>()) return o.getSource();
    return Value();
  }
  static Value baseOf(Value v) {
    while (Value s = viewSource(v)) v = s;
    return v;
  }
  struct ConvInfo { bool ok = false; unsigned R = 0, nD = 0, fD = 0, cD = 0; SmallVector<unsigned> spD, kD; SmallVector<int64_t> stride; };
  static bool dimOf(AffineExpr e, unsigned &d) { if (auto de = dyn_cast<AffineDimExpr>(e)) { d = de.getPosition(); return true; } return false; }
  static bool parseTerm(AffineExpr e, unsigned &d, int64_t &coef) {
    coef = 1; if (dimOf(e, d)) return true;
    auto m = dyn_cast<AffineBinaryOpExpr>(e); if (!m || m.getKind() != AffineExprKind::Mul) return false;
    auto cst = dyn_cast<AffineConstantExpr>(m.getRHS()); if (!cst || !dimOf(m.getLHS(), d)) return false;
    coef = cst.getValue(); return true;
  }
  static ConvInfo matchConv(linalg::LinalgOp red) {
    ConvInfo ci; auto maps = red.getIndexingMapsArray(); if (maps.size() != 3) return ci;
    auto iters = red.getIteratorTypesArray();
    auto isPar = [&](unsigned d) { return iters[d] == utils::IteratorType::parallel; };
    AffineMap mi = maps[0], mw = maps[1], mo = maps[2];
    if (mo.getNumResults() < 4 || mo.getNumResults() > 5) return ci;
    unsigned R = mo.getNumResults() - 2;
    if (mi.getNumResults() != R + 2 || mw.getNumResults() != R + 2) return ci;
    unsigned n, f, wf, wc, in_n, in_c;
    if (!dimOf(mo.getResult(0), n) || !dimOf(mo.getResult(1), f)) return ci;
    if (!dimOf(mw.getResult(0), wf) || !dimOf(mw.getResult(1), wc) || wf != f) return ci;
    if (!dimOf(mi.getResult(0), in_n) || !dimOf(mi.getResult(1), in_c) || in_n != n || in_c != wc) return ci;
    if (!isPar(n) || !isPar(f) || isPar(wc)) return ci;
    for (unsigned i = 0; i < R; i++) {
      unsigned sp, k; if (!dimOf(mo.getResult(2 + i), sp) || !dimOf(mw.getResult(2 + i), k)) return ci;
      if (!isPar(sp) || isPar(k)) return ci;
      auto bin = dyn_cast<AffineBinaryOpExpr>(mi.getResult(2 + i)); if (!bin || bin.getKind() != AffineExprKind::Add) return ci;
      unsigned a, b; int64_t ca, cb;
      if (!parseTerm(bin.getLHS(), a, ca) || !parseTerm(bin.getRHS(), b, cb)) return ci;
      int64_t s;
      if (a == sp && b == k && cb == 1) s = ca; else if (a == k && b == sp && ca == 1) s = cb; else return ci;
      ci.spD.push_back(sp); ci.kD.push_back(k); ci.stride.push_back(s);
    }
    ci.ok = true; ci.R = R; ci.nD = n; ci.fD = f; ci.cD = wc; return ci;
  }
  static bool isReduction(linalg::LinalgOp l) {
    for (auto it : l.getIteratorTypesArray())
      if (it == utils::IteratorType::reduction) return true;
    return false;
  }
  static Value writtenBuffer(Operation *op) {
    if (auto cp = dyn_cast<memref::CopyOp>(op)) return cp.getTarget();
    return cast<linalg::LinalgOp>(op).getDpsInits()[0];
  }
  static bool readsBuffer(Operation *op, Value buf) {
    if (auto cp = dyn_cast<memref::CopyOp>(op)) return baseOf(cp.getSource()) == baseOf(buf);
    for (Value v : cast<linalg::LinalgOp>(op).getDpsInputs())
      if (isa<MemRefType>(v.getType()) && baseOf(v) == baseOf(buf)) return true;
    return false;
  }

  // Host memref value -> usable inside the current kernel (subviews re-materialized).
  Value kmem(OpBuilder &b, Location loc, Value v) {
    v = phys(v);
    if (Value s = viewSource(v)) {
      if (Value m = svMemo.lookup(v)) return m;
      IRMapping local;
      local.map(s, kmem(b, loc, s));
      Value r = b.clone(*v.getDefiningOp(), local)->getResult(0);
      svMemo[v] = r;
      return r;
    }
    return karg(v);
  }

  SmallVector<Value> mapIndices(OpBuilder &b, Location loc, linalg::LinalgOp l, unsigned oi, ArrayRef<Value> idx) {
    AffineMap am = l.getIndexingMapsArray()[oi];
    SmallVector<Value> out;
    for (AffineExpr e : am.getResults())
      out.push_back(b.create<affine::AffineApplyOp>(loc, AffineMap::get(l.getNumLoops(), 0, e), idx));
    return out;
  }

  Value loadOperand(OpBuilder &b, Location loc, linalg::LinalgOp l, unsigned oi, ArrayRef<Value> idx) {
    Value operand = l->getOperand(oi);
    if (!isa<MemRefType>(operand.getType())) {
      if (auto cst = operand.getDefiningOp<arith::ConstantOp>()) return b.clone(*cst)->getResult(0);
      return karg(operand);
    }
    if (auto gg = operand.getDefiningOp<memref::GetGlobalOp>()) {
      auto glob = SymbolTable::lookupNearestSymbolFrom<memref::GlobalOp>(gg, gg.getNameAttr());
      auto init = glob ? dyn_cast_or_null<DenseElementsAttr>(glob.getInitialValueAttr()) : DenseElementsAttr();
      if (init && init.isSplat())
        return b.create<arith::ConstantOp>(loc, cast<TypedAttr>(init.getSplatValue<Attribute>()));
      l->emitError("fortis-fuse: non-splat memref.global operand unsupported");
      return Value();
    }
    return b.create<memref::LoadOp>(loc, kmem(b, loc, operand), mapIndices(b, loc, l, oi, idx));
  }

  // Clone the payload with block args bound to argVals and linalg.index bound to idx.
  Value clonePayload(OpBuilder &b, linalg::LinalgOp l, ArrayRef<Value> argVals, ArrayRef<Value> idx) {
    Block &payload = l->getRegion(0).front();
    IRMapping pm;
    for (unsigned i = 0; i < std::min<unsigned>(argVals.size(), payload.getNumArguments()); i++)
      pm.map(payload.getArgument(i), argVals[i]);
    for (Operation &op : payload.without_terminator()) {
      if (auto ix = dyn_cast<linalg::IndexOp>(op)) { pm.map(ix.getResult(), idx[ix.getDim()]); continue; }
      for (Value opd : op.getOperands()) {
        if (pm.contains(opd) || opd.getParentRegion() == &l->getRegion(0)) continue;
        if (isa<MemRefType>(opd.getType())) { pm.map(opd, kmem(b, l->getLoc(), opd)); continue; }
        if (Operation *def = opd.getDefiningOp())
          if (def->hasTrait<OpTrait::ConstantLike>()) pm.map(opd, b.clone(*def)->getResult(0));
      }
      b.clone(op, pm);
    }
    auto yield = cast<linalg::YieldOp>(payload.getTerminator());
    Value y = yield.getOperand(0);
    if (!pm.contains(y) && y.getParentRegion() != &l->getRegion(0))
      if (Operation *def = y.getDefiningOp())
        if (def->hasTrait<OpTrait::ConstantLike>()) return b.clone(*def)->getResult(0);
    return pm.lookupOrDefault(y);
  }

  // Value of `buf` at parallel indices pidx as computed by its absorbed producer chain.
  Value evalInit(OpBuilder &b, Location loc, Value buf, Operation *p, ArrayRef<Value> pidx, Type elemTy) {
    if (!p) return b.create<memref::LoadOp>(loc, kmem(b, loc, buf), pidx);
    if (auto cp = dyn_cast<memref::CopyOp>(p)) return evalInit(b, loc, cp.getSource(), chainNext.lookup(p), pidx, elemTy);
    linalg::LinalgOp l = cast<linalg::LinalgOp>(p);
    unsigned numIns = l.getNumDpsInputs();
    SmallVector<Value> args;
    for (unsigned oi = 0; oi < l->getNumOperands(); oi++) {
      if (oi < numIns) args.push_back(loadOperand(b, loc, l, oi, pidx));
      else args.push_back(b.create<arith::ConstantOp>(loc, b.getZeroAttr(elemTy)));
    }
    return clonePayload(b, l, args, pidx);
  }

  void delinearize(OpBuilder &b, Location loc, Value lin, ArrayRef<unsigned> dims,
                   ArrayRef<int64_t> sizes, SmallVectorImpl<Value> &idx) {
    Value rem = lin;
    for (int i = dims.size() - 1; i >= 0; i--) {
      unsigned d = dims[i];
      Value sz = b.create<arith::ConstantIndexOp>(loc, sizes[d]);
      idx[d] = b.create<arith::RemUIOp>(loc, rem, sz);
      rem = b.create<arith::DivUIOp>(loc, rem, sz);
    }
  }

  void runOnOperation() override {
    ModuleOp module = getOperation();
    MLIRContext *ctx = module.getContext();
    rename.clear(); initProducer.clear(); chainNext.clear();

    func::FuncOp host;
    module.walk([&](func::FuncOp f) {
      bool has = false; f.walk([&](linalg::LinalgOp) { has = true; });
      if (has && !host) host = f;
    });
    if (!host) return;
    Location loc = host.getLoc();

    // Arguments are persistent (weights) or the host's input: an op that writes into one must
    // instead write into a private copy, and all later uses see that copy.
    {
      SmallVector<Operation*> ops;
      for (Operation &op : host.getBody().front())
        if (isa<linalg::LinalgOp>(op) || isa<memref::CopyOp>(op)) ops.push_back(&op);
      for (Operation *op : ops) {
        Value w = baseOf(writtenBuffer(op));
        auto arg = dyn_cast<BlockArgument>(w);
        if (!arg || arg.getOwner()->getParentOp() != host.getOperation()) continue;
        OpBuilder ab(host.getBody().front().getTerminator()); ab.setInsertionPointToStart(&host.getBody().front());
        Value fresh = ab.create<memref::AllocOp>(loc, cast<MemRefType>(arg.getType()));
        OpBuilder cb(op);
        auto cp = cb.create<memref::CopyOp>(loc, arg, fresh);
        arg.replaceUsesWithIf(fresh, [&](OpOperand &u) { return u.getOwner() != cp.getOperation(); });
      }
    }

    // Out-param conversion: a returned alloc becomes an appended out argument (+ a copy to absorb).
    if (host.getNumResults() == 1) {
      Operation *term = host.getBody().front().getTerminator();
      Value rv = term->getOperand(0);
      if (isa<MemRefType>(rv.getType())) {   // returned alloc, view, or argument: append an out-param and copy into it
        unsigned n = host.getNumArguments();
        host.insertArgument(n, rv.getType(), DictionaryAttr::get(ctx), loc);
        Value outArg = host.getArgument(n);
        term->setOperand(0, outArg);
        OpBuilder cb(term);
        cb.create<memref::CopyOp>(loc, rv, outArg);
      }
    }

    SmallVector<Operation*> seq;
    for (Operation &op : host.getBody().front())
      if (isa<linalg::LinalgOp>(op) || isa<memref::CopyOp>(op)) seq.push_back(&op);

    SetVector<Value> allocs;
    for (Operation *op : seq)
      for (Value v : op->getOperands())
        if (auto al = baseOf(v).getDefiningOp<memref::AllocOp>()) allocs.insert(al.getResult());

    // Pass A: absorb init producers (last writer of a reduction's init buffer with no reader in between,
    // following copy chains).
    DenseSet<Operation*> absorbed;
    for (unsigned i = 0; i < seq.size(); i++) {
      auto r = dyn_cast<linalg::LinalgOp>(seq[i]);
      if (!r || !isReduction(r)) continue;
      Value buf = r.getDpsInits()[0];
      int limit = i;
      Operation *prev = nullptr;
      while (true) {
        int w = -1;
        for (int j = limit - 1; j >= 0; j--) if (writtenBuffer(seq[j]) == buf) { w = j; break; }
        static const bool dbg = getenv("FORTIS_DEBUG") != nullptr;
        if (dbg) llvm::errs() << "PassA red@" << i << " buf " << buf << " writer@" << w << "\n";
        if (w < 0) break;
        // A non-absorbed reader would need the buffer materialized. The init buffer itself is written by
        // the reduction, so only readers before it matter; a chain source buffer is never written at all,
        // so no non-absorbed reader may exist anywhere after its producer.
        // A pure fill (constant input) can be evaluated in-kernel by any consumer: reductions that read the
        // buffer as their init, and copies absorbed into a chain, do not need it materialized.
        auto isFill = [&](Operation *o) {
          auto lo = dyn_cast<linalg::LinalgOp>(o);
          return lo && lo.getNumDpsInputs() == 1 && lo->getOperand(0).getDefiningOp<arith::ConstantOp>();
        };
        auto readsAsInit = [&](Operation *o) {
          auto lo = dyn_cast<linalg::LinalgOp>(o);
          return lo && isReduction(lo) && lo.getDpsInits()[0] == buf;
        };
        bool readBetween = false;
        int end = prev ? (int)seq.size() : limit;
        for (int j = w + 1; j < end; j++) {
          if (j != (int)i && !absorbed.count(seq[j]) && readsBuffer(seq[j], buf) &&
              !(isFill(seq[w]) && (readsAsInit(seq[j]) || isa<memref::CopyOp>(seq[j])))) readBetween = true;
          if (j != (int)i && writtenBuffer(seq[j]) == buf) break;   // later writer supersedes the producer
        }
        if (dbg) llvm::errs() << "  readBetween=" << readBetween << " writerIsRed=" << (isa<linalg::LinalgOp>(seq[w]) && isReduction(cast<linalg::LinalgOp>(seq[w]))) << "\n";
        if (readBetween || isa<linalg::LinalgOp>(seq[w]) && isReduction(cast<linalg::LinalgOp>(seq[w]))) break;
        absorbed.insert(seq[w]);
        if (prev) chainNext[prev] = seq[w]; else initProducer[seq[i]] = seq[w];
        prev = seq[w];
        auto cp = dyn_cast<memref::CopyOp>(seq[w]);
        if (!cp) break;
        buf = cp.getSource(); limit = w;
      }
    }

    // Pass A2: a large conv whose input is a materialized zero pad (fill + copy into a centered
    // subview, no other readers) takes the unpadded source and the pad amounts instead; the two
    // pad kernels disappear.
    struct PadInfo { Value src; SmallVector<int64_t> pad; };
    DenseMap<Operation*, PadInfo> padOf;
    for (int i = 0; i < (int)seq.size(); i++) {
      auto r = dyn_cast<linalg::LinalgOp>(seq[i]);
      if (!r || !isReduction(r) || absorbed.count(seq[i])) continue;
      ConvInfo ci = matchConv(r); if (!ci.ok) continue;
      SmallVector<int64_t> rs = r.getStaticLoopRanges();
      int64_t macs = 1; for (int64_t s : rs) macs *= s;
      if (macs < kConvLibMinMACs) continue;
      if (getenv("FORTIS_NO_PADFOLD")) continue;
      Value X = r.getDpsInputs()[0];
      if (!X.getDefiningOp<memref::AllocOp>()) continue;
      Operation *fill = nullptr, *copy = nullptr; bool clean = true;
      for (int j = 0; j < i && clean; j++) {
        Operation *o = seq[j]; if (absorbed.count(o)) continue;
        bool touches = false;
        for (Value v : o->getOperands()) if (baseOf(v) == X) touches = true;
        for (Region &rg : o->getRegions()) rg.walk([&](Operation *in) { for (Value v : in->getOperands()) if (isa<MemRefType>(v.getType()) && baseOf(v) == X) touches = true; });
        if (!touches) continue;
        if (auto lo = dyn_cast<linalg::LinalgOp>(o)) {
          bool zeroFill = lo.getNumDpsInputs() == 1 && lo->getOperand(lo->getNumOperands() - 1) == X && !fill;
          if (zeroFill) if (auto cst = lo->getOperand(0).getDefiningOp<arith::ConstantOp>()) zeroFill = cast<FloatAttr>(cst.getValue()).getValue().isZero(); else zeroFill = false;
          if (zeroFill) fill = o; else clean = false;
        } else if (auto cp = dyn_cast<memref::CopyOp>(o)) {
          auto sv = cp.getTarget().getDefiningOp<memref::SubViewOp>();
          if (sv && sv.getSource() == X && !copy && baseOf(cp.getSource()) != X) copy = o; else clean = false;
        } else clean = false;
      }
      for (int j = i + 1; j < (int)seq.size() && clean; j++)
        for (Value v : seq[j]->getOperands()) if (baseOf(v) == X) clean = false;
      if (!clean || !fill || !copy) continue;
      auto sv = cast<memref::CopyOp>(copy).getTarget().getDefiningOp<memref::SubViewOp>();
      auto offs = sv.getStaticOffsets(); auto szs = sv.getStaticSizes(); auto strs = sv.getStaticStrides();
      auto xshape = cast<MemRefType>(X.getType()).getShape();
      bool sym = true; SmallVector<int64_t> pad;
      for (unsigned d = 0; d < xshape.size(); d++) {
        if (strs[d] != 1) sym = false;
        if (d < 2) { if (offs[d] != 0 || szs[d] != xshape[d]) sym = false; }
        else { if (xshape[d] != szs[d] + 2 * offs[d]) sym = false; pad.push_back(offs[d]); }
      }
      if (!sym) continue;
      if (baseOf(cast<memref::CopyOp>(copy).getSource()) == baseOf(r.getDpsInits()[0])) continue;   // in-place conv: library needs distinct x, y
      padOf[seq[i]] = PadInfo{cast<memref::CopyOp>(copy).getSource(), pad};
      absorbed.insert(fill); absorbed.insert(copy);
    }

    // Pass B: build groups.
    SmallVector<Group> groups;
    DenseSet<Value> chainWritten, chainReadNonId;
    for (Operation *op : seq) {
      if (absorbed.count(op)) continue;
      auto l = dyn_cast<linalg::LinalgOp>(op);
      if (l && isReduction(l)) { Group g; g.red = l; groups.push_back(g); continue; }
      bool attach = false;
      if (!groups.empty() && groups.back().red && !groups.back().closed) {
        Group &g = groups.back();
        SmallVector<int64_t> rs = g.red.getStaticLoopRanges();
        auto it = g.red.getIteratorTypesArray();
        SmallVector<int64_t> par; for (unsigned d = 0; d < rs.size(); d++) if (it[d] == utils::IteratorType::parallel) par.push_back(rs[d]);
        if (l) attach = (l.getStaticLoopRanges() == par);
        else { auto cp = cast<memref::CopyOp>(op); auto mt = cast<MemRefType>(cp.getSource().getType()); attach = (SmallVector<int64_t>(mt.getShape()) == par); }
      }
      // Elementwise chain: same loop space as the open standalone group, reads of chain-written
      // buffers element-aligned (forwarded in registers), no clobbering of gathered reads.
      auto isView = [&](Value v) { return viewSource(v) != Value(); };
      auto recordChain = [&](Operation *o) {
        if (auto lo = dyn_cast<linalg::LinalgOp>(o)) {
          auto maps = lo.getIndexingMapsArray();
          for (unsigned oi = 0; oi < lo->getNumOperands(); oi++) {
            Value b = baseOf(lo->getOperand(oi));
            if (!maps[oi].isIdentity() || isView(lo->getOperand(oi))) chainReadNonId.insert(b);
          }
          for (Region &r : lo->getRegions()) r.walk([&](Operation *inner) { for (Value v : inner->getOperands()) if (isa<MemRefType>(v.getType())) chainReadNonId.insert(baseOf(v)); });
          chainWritten.insert(baseOf(lo->getOperand(lo->getNumOperands() - 1)));
        } else { auto cp = cast<memref::CopyOp>(o); chainWritten.insert(baseOf(cp.getTarget())); }
      };
      auto chainable = [&](Operation *o) {   // can this op start or extend a chain?
        if (auto lo = dyn_cast<linalg::LinalgOp>(o)) return !isReduction(lo) && lo.getIndexingMapsArray().back().isIdentity() && !isView(lo->getOperand(lo->getNumOperands() - 1));
        auto cp = cast<memref::CopyOp>(o); return !isView(cp.getSource()) && !isView(cp.getTarget());
      };
      static const bool noChain = getenv("FORTIS_NO_CHAIN") != nullptr;
      if (!noChain && !attach && !groups.empty() && !groups.back().red && !groups.back().closed && chainable(op)) {
        Group &g = groups.back();
        SmallVector<int64_t> par;
        if (auto ls = dyn_cast<linalg::LinalgOp>(g.single)) par = ls.getStaticLoopRanges();
        else par = SmallVector<int64_t>(cast<MemRefType>(cast<memref::CopyOp>(g.single).getSource().getType()).getShape());
        bool ok;
        if (l) ok = (l.getStaticLoopRanges() == par);
        else ok = (SmallVector<int64_t>(cast<MemRefType>(cast<memref::CopyOp>(op).getSource().getType()).getShape()) == par);
        if (ok && l) {
          auto maps = l.getIndexingMapsArray();
          for (unsigned oi = 0; oi < l->getNumOperands() && ok; oi++)
            if (chainWritten.count(baseOf(l->getOperand(oi))) && (!maps[oi].isIdentity() || isView(l->getOperand(oi)))) ok = false;
          for (Region &r : l->getRegions()) r.walk([&](Operation *inner) { for (Value v : inner->getOperands()) if (isa<MemRefType>(v.getType()) && chainWritten.count(baseOf(v))) ok = false; });
        }
        if (ok && chainReadNonId.count(baseOf(writtenBuffer(op)))) ok = false;
        attach = ok;
        if (attach) recordChain(op);
      }
      if (attach) { groups.back().epi.push_back(op); continue; }
      if (!groups.empty()) groups.back().closed = true;
      Group g; g.single = op; groups.push_back(g);
      chainWritten.clear(); chainReadNonId.clear();
      if (chainable(op)) recordChain(op); else groups.back().closed = true;
    }

    module->setAttr(gpu::GPUDialect::getContainerModuleAttrName(), UnitAttr::get(ctx));
    OpBuilder mb(ctx);
    mb.setInsertionPointToStart(module.getBody());
    auto gpuMod = mb.create<gpu::GPUModuleOp>(loc, "fortis");

    OpBuilder hb(ctx);
    hb.setInsertionPointToStart(&host.getBody().front());

    // WAR hazard pre-pass on reduction groups.
    struct RenameEv { unsigned epiIdx; Value init; Value fresh; };
    SmallVector<SmallVector<RenameEv>> events(groups.size());
    {
      DenseMap<Value, Value> rn;
      for (unsigned gi = 0; gi < groups.size(); gi++) {
        Group &g = groups[gi]; if (!g.red) continue;
        SmallVector<Value> redIns;
        for (Value v : g.red.getDpsInputs()) { Value r = rn.lookup(v); redIns.push_back(baseOf(r ? r : v)); }
        for (unsigned ei = 0; ei < g.epi.size(); ei++) {
          Value init = writtenBuffer(g.epi[ei]);
          Value cur = rn.lookup(init); if (!cur) cur = init;
          if (llvm::is_contained(redIns, baseOf(cur)) && !init.getDefiningOp<memref::SubViewOp>()) {
            Value fresh = hb.create<memref::AllocOp>(loc, cast<MemRefType>(init.getType()));
            rn[init] = fresh; allocs.insert(fresh);
            events[gi].push_back({ei, init, fresh});
          }
        }
      }
    }

    SmallVector<Value> kernelOperands(host.getArguments().begin(), host.getArguments().end());
    for (Value a : allocs) kernelOperands.push_back(a);
    SmallVector<Type> argTypes;
    for (Value v : kernelOperands) argTypes.push_back(v.getType());

    func::FuncOp gemmFn;
    {
      OpBuilder db(ctx); db.setInsertionPointToStart(module.getBody());
      auto dyn = MemRefType::get({ShapedType::kDynamic, ShapedType::kDynamic}, db.getF32Type());
      auto ft = db.getFunctionType({dyn, dyn, dyn, db.getIndexType(), db.getIndexType(), db.getIndexType()}, {});
      gemmFn = db.create<func::FuncOp>(loc, "fortis_gemm", ft);
      gemmFn.setPrivate();
    }
    func::FuncOp conv2dFn, conv3dFn, conv3dFftFn;
    {
      OpBuilder db(ctx); db.setInsertionPointToStart(module.getBody());
      auto dyn4 = MemRefType::get({ShapedType::kDynamic, ShapedType::kDynamic, ShapedType::kDynamic, ShapedType::kDynamic}, db.getF32Type());
      auto dyn5 = MemRefType::get({ShapedType::kDynamic, ShapedType::kDynamic, ShapedType::kDynamic, ShapedType::kDynamic, ShapedType::kDynamic}, db.getF32Type());
      SmallVector<Type> t2{dyn4, dyn4, dyn4}; for (int i = 0; i < 13; i++) t2.push_back(db.getIndexType());
      SmallVector<Type> t3{dyn5, dyn5, dyn5}; for (int i = 0; i < 18; i++) t3.push_back(db.getIndexType());
      conv2dFn = db.create<func::FuncOp>(loc, "fortis_conv2d", db.getFunctionType(t2, {})); conv2dFn.setPrivate();
      conv3dFn = db.create<func::FuncOp>(loc, "fortis_conv3d", db.getFunctionType(t3, {})); conv3dFn.setPrivate();
      conv3dFftFn = db.create<func::FuncOp>(loc, "fortis_conv3d_fft", db.getFunctionType(t3, {})); conv3dFftFn.setPrivate();
    }
    const int64_t kGemmBatchThreshold = 32;
    Value h1, h256;
    {
      OpBuilder tb(ctx); tb.setInsertionPointToStart(&host.getBody().front());
      h1 = tb.create<arith::ConstantIndexOp>(loc, 1);
      h256 = tb.create<arith::ConstantIndexOp>(loc, 256);
    }

    auto newKernel = [&](StringRef name) {
      OpBuilder gb(ctx);
      gb.setInsertionPointToEnd(gpuMod.getBody());
      auto kfunc = gb.create<gpu::GPUFuncOp>(loc, name, gb.getFunctionType({}, {}), TypeRange{}, TypeRange{});
      kfunc->setAttr(gpu::GPUDialect::getKernelFuncAttrName(), gb.getUnitAttr());
      map = IRMapping(); svMemo.clear(); curOperands.clear(); curFunc = kfunc; kloc = loc;
      return kfunc;
    };
    auto launch = [&](gpu::GPUFuncOp k, int64_t nBlocks) {
      SmallVector<Type> tys; for (Value v : curOperands) tys.push_back(v.getType());
      k.setFunctionTypeAttr(TypeAttr::get(FunctionType::get(ctx, tys, {})));
      Value nb = hb.create<arith::ConstantIndexOp>(loc, nBlocks);
      hb.create<gpu::LaunchFuncOp>(loc, k, gpu::KernelDim3{nb, h1, h1}, gpu::KernelDim3{h256, h1, h1}, Value(), ValueRange(curOperands));
    };

    // Last use of each temporary, by group index, so it can be released right after that launch.
    DenseMap<Value, int> lastUse;
    auto noteUses = [&](Operation *op, int gi) {
      auto note = [&](Value v) { if (auto al = baseOf(v).getDefiningOp<memref::AllocOp>()) lastUse[al.getResult()] = std::max(lastUse.lookup(al.getResult()), gi); };
      for (Value v : op->getOperands()) note(v);
      op->walk([&](Operation *inner) { for (Value v : inner->getOperands()) if (isa<MemRefType>(v.getType())) note(v); });
    };
    for (unsigned gi = 0; gi < groups.size(); gi++) {
      Group &g = groups[gi];
      if (g.single) { noteUses(g.single, gi); for (Operation *e : g.epi) noteUses(e, gi); }
      else {
        noteUses(g.red.getOperation(), gi);
        for (Operation *e : g.epi) noteUses(e, gi);
        for (Operation *p = initProducer.lookup(g.red.getOperation()); p; p = chainNext.lookup(p)) noteUses(p, gi);
        if (auto pi = padOf.find(g.red.getOperation()); pi != padOf.end()) if (auto al = baseOf(pi->second.src).getDefiningOp<memref::AllocOp>()) lastUse[al.getResult()] = std::max(lastUse.lookup(al.getResult()), (int)gi);
        for (auto &ev : events[gi]) lastUse[ev.fresh] = std::max({lastUse.lookup(ev.fresh), (int)gi, lastUse.lookup(baseOf(ev.init))});
      }
    }
    static const bool noRelease = getenv("FORTIS_NO_RELEASE") != nullptr;
    auto releaseAfter = [&](int gi) {
      if (noRelease) return;
      for (Value a : allocs) if (lastUse.lookup(a) == gi) hb.create<memref::DeallocOp>(loc, a);
    };

    for (unsigned gi = 0; gi < groups.size(); gi++) {
      Group &g = groups[gi];
      {
        Operation *last = g.epi.empty() ? (g.single ? g.single : g.red.getOperation()) : g.epi.back();
        hb.setInsertionPointAfter(last);
      }

      // ---------------- standalone parallel group ----------------
      if (!g.red) {
        auto kfunc = newKernel("fortis_k" + std::to_string(gi));
        OpBuilder b(ctx);
        b.setInsertionPointToStart(&kfunc.getBody().front());
        Value bid = b.create<gpu::BlockIdOp>(loc, gpu::Dimension::x);
        Value tid = b.create<gpu::ThreadIdOp>(loc, gpu::Dimension::x);
        Value c256 = b.create<arith::ConstantIndexOp>(loc, 256);
        Value gid = b.create<arith::AddIOp>(loc, b.create<arith::MulIOp>(loc, bid, c256), tid);
        SmallVector<int64_t> sizes;
        if (auto l = dyn_cast<linalg::LinalgOp>(g.single)) sizes = l.getStaticLoopRanges();
        else sizes = SmallVector<int64_t>(cast<MemRefType>(cast<memref::CopyOp>(g.single).getSource().getType()).getShape());
        int64_t total = 1; for (int64_t s : sizes) total *= s;
        SmallVector<unsigned> dims; for (unsigned d = 0; d < sizes.size(); d++) dims.push_back(d);
        Value cond = b.create<arith::CmpIOp>(loc, arith::CmpIPredicate::slt, gid, b.create<arith::ConstantIndexOp>(loc, total));
        auto ifOp = b.create<scf::IfOp>(loc, cond, false);
        b.setInsertionPointToStart(&ifOp.getThenRegion().front());
        SmallVector<Value> idx(sizes.size());
        delinearize(b, loc, gid, dims, sizes, idx);
        DenseMap<Value, Value> reg;   // buffer -> this element's value, for element-aligned forwarding
        SmallVector<Operation*> chain{g.single}; chain.append(g.epi.begin(), g.epi.end());
        for (Operation *co : chain) {
          if (auto cp = dyn_cast<memref::CopyOp>(co)) {
            Value v = reg.lookup(baseOf(cp.getSource()));
            if (!v) v = b.create<memref::LoadOp>(loc, kmem(b, loc, cp.getSource()), idx);
            b.create<memref::StoreOp>(loc, v, kmem(b, loc, cp.getTarget()), idx);
            reg[baseOf(cp.getTarget())] = v;
          } else {
            linalg::LinalgOp l = cast<linalg::LinalgOp>(co);
            auto maps = l.getIndexingMapsArray();
            SmallVector<Value> args;
            for (unsigned oi = 0; oi < l->getNumOperands(); oi++) {
              Value v = maps[oi].isIdentity() ? reg.lookup(baseOf(l->getOperand(oi))) : Value();
              if (!v) v = (oi < l.getNumDpsInputs()) ? loadOperand(b, loc, l, oi, idx)
                                                     : b.create<memref::LoadOp>(loc, kmem(b, loc, l->getOperand(oi)), mapIndices(b, loc, l, oi, idx));
              args.push_back(v);
            }
            Value y = clonePayload(b, l, args, idx);
            unsigned outOi = l->getNumOperands() - 1;
            b.create<memref::StoreOp>(loc, y, kmem(b, loc, l->getOperand(outOi)), mapIndices(b, loc, l, outOi, idx));
            reg[baseOf(l->getOperand(outOi))] = y;
          }
        }
        b.setInsertionPointAfter(ifOp);
        b.create<gpu::ReturnOp>(loc);
        launch(kfunc, (total + 255) / 256);
        releaseAfter(gi);
        continue;
      }

      // ---------------- reduction group ----------------
      linalg::LinalgOp red = g.red;
      SmallVector<int64_t> sizes = red.getStaticLoopRanges();
      auto iters = red.getIteratorTypesArray();
      unsigned nLoops = sizes.size();
      SmallVector<unsigned> parDims, redDims; int64_t parProd = 1, redProd = 1;
      for (unsigned i = 0; i < nLoops; i++) {
        if (iters[i] == utils::IteratorType::parallel) { parDims.push_back(i); parProd *= sizes[i]; }
        else { redDims.push_back(i); redProd *= sizes[i]; }
      }
      Type elemTy = cast<MemRefType>(red.getDpsInits()[0].getType()).getElementType();

      // Batch-aware lowering: (batch, out, k) matmul with large batch -> cuBLAS.
      int batchD = -1, outD = -1; bool useGemm = false;
      if (nLoops == 3 && parDims.size() == 2 && red.getNumDpsInputs() == 2) {
        auto maps = red.getIndexingMapsArray();
        for (unsigned d : parDims) {
          bool in0 = maps[0].isFunctionOfDim(d), in1 = maps[1].isFunctionOfDim(d);
          if (in0 && !in1) batchD = d;
          if (in1 && !in0) outD = d;
        }
        if (batchD >= 0 && outD >= 0) {
          unsigned rd = redDims[0];
          auto dd = [&](int d) { return getAffineDimExpr(d, ctx); };
          bool shapeOk = maps[0] == AffineMap::get(3, 0, {dd(batchD), dd(rd)}, ctx) &&
                         maps[1] == AffineMap::get(3, 0, {dd(outD), dd(rd)}, ctx) &&
                         maps[2] == AffineMap::get(3, 0, {dd(batchD), dd(outD)}, ctx);
          useGemm = shapeOk && sizes[batchD] >= kGemmBatchThreshold;
          // GEMM path only when the init is a plain zero fill chain (beta = 0).
          if (useGemm) {
            Operation *p = initProducer.lookup(red.getOperation());
            while (p && isa<memref::CopyOp>(p)) p = chainNext.lookup(p);
            bool zeroFill = false;
            if (auto lp = dyn_cast_or_null<linalg::LinalgOp>(p))
              if (lp.getNumDpsInputs() == 1 && !isa<MemRefType>(lp.getDpsInputs()[0].getType()))
                if (auto c = lp.getDpsInputs()[0].getDefiningOp<arith::ConstantOp>())
                  if (auto f = dyn_cast<FloatAttr>(c.getValue())) zeroFill = f.getValue().isZero();
            useGemm = zeroFill;
          }
        }
      }
      if (useGemm) {
        auto dyn = MemRefType::get({ShapedType::kDynamic, ShapedType::kDynamic}, hb.getF32Type());
        Value A = hb.create<memref::CastOp>(loc, dyn, phys(red.getDpsInputs()[0]));
        Value Wv = hb.create<memref::CastOp>(loc, dyn, phys(red.getDpsInputs()[1]));
        Value C = hb.create<memref::CastOp>(loc, dyn, phys(red.getDpsInits()[0]));
        hb.create<func::CallOp>(loc, gemmFn, ValueRange{A, Wv, C,
            hb.create<arith::ConstantIndexOp>(loc, sizes[batchD]), hb.create<arith::ConstantIndexOp>(loc, sizes[outD]),
            hb.create<arith::ConstantIndexOp>(loc, sizes[redDims[0]])});
      }

      // Large convolutions -> cuDNN forward with a fixed algorithm; init and epilogue stay fused.
      bool useConv = false;
      if (!useGemm) {
        ConvInfo ci = matchConv(red);
        if (ci.ok && parProd * redProd >= kConvLibMinMACs) {
          useConv = true;
          Value xin = red.getDpsInputs()[0];
          SmallVector<int64_t> pads(ci.R, 0);
          if (auto pi = padOf.find(red.getOperation()); pi != padOf.end()) { xin = pi->second.src; pads = pi->second.pad; }
          auto inTy = cast<MemRefType>(xin.getType());
          bool is3 = (ci.R == 3);
          auto dynTy = MemRefType::get(SmallVector<int64_t>(ci.R + 2, ShapedType::kDynamic), hb.getF32Type());
          Value X = hb.create<memref::CastOp>(loc, dynTy, phys(xin));
          Value Wv = hb.create<memref::CastOp>(loc, dynTy, phys(red.getDpsInputs()[1]));
          Value Y = hb.create<memref::CastOp>(loc, dynTy, phys(red.getDpsInits()[0]));
          auto ci64 = [&](int64_t v) { return hb.create<arith::ConstantIndexOp>(loc, v); };
          SmallVector<Value> args{X, Wv, Y, ci64(sizes[ci.nD]), ci64(sizes[ci.cD])};
          for (unsigned i = 0; i < ci.R; i++) args.push_back(ci64(inTy.getShape()[2 + i]));   // input spatial
          args.push_back(ci64(sizes[ci.fD]));
          for (unsigned i = 0; i < ci.R; i++) args.push_back(ci64(sizes[ci.kD[i]]));         // kernel
          for (unsigned i = 0; i < ci.R; i++) args.push_back(ci64(sizes[ci.spD[i]]));        // output spatial
          for (unsigned i = 0; i < ci.R; i++) args.push_back(ci64(ci.stride[i]));            // strides
          for (unsigned i = 0; i < ci.R; i++) args.push_back(ci64(pads[i]));                 // pads
          int64_t kvol = 1; for (unsigned i = 0; i < ci.R; i++) kvol *= sizes[ci.kD[i]];
          bool pads0 = llvm::all_of(pads, [](int64_t p) { return p == 0; });
          const int64_t kFftKernelMinVol = 125;   // 5x5x5 and larger: whole-volume FFT with precomputed weight spectra
          func::FuncOp callee = is3 ? ((kvol >= kFftKernelMinVol && pads0 && sizes[ci.nD] == 1) ? conv3dFftFn : conv3dFn) : conv2dFn;
          hb.create<func::CallOp>(loc, callee, args);
        }
      }
      bool useLib = useGemm || useConv;

      auto kfunc = newKernel("fortis_k" + std::to_string(gi));
      OpBuilder b(ctx);
      b.setInsertionPointToStart(&kfunc.getBody().front());
      Value bid = b.create<gpu::BlockIdOp>(loc, gpu::Dimension::x);
      Value tid = b.create<gpu::ThreadIdOp>(loc, gpu::Dimension::x);
      Value c0 = b.create<arith::ConstantIndexOp>(loc, 0);
      Value c32 = b.create<arith::ConstantIndexOp>(loc, 32);
      Value c256 = b.create<arith::ConstantIndexOp>(loc, 256);
      Value gid = b.create<arith::AddIOp>(loc, b.create<arith::MulIOp>(loc, bid, c256), tid);
      const int64_t kWarpReductionMin = 256;
      const int64_t kPerThreadMinOutputs = 8192;   // enough outputs to fill the GPU one per thread
      bool additive = true;   // warp path splits the reduction across lanes: needs an additive combine
      red->getRegion(0).walk([&](Operation *o) {
        if (isa<arith::MaximumFOp, arith::MinimumFOp, arith::MaxNumFOp, arith::MinNumFOp, arith::MulFOp>(o) &&
            o->getResult(0) == cast<linalg::YieldOp>(red->getRegion(0).front().getTerminator()).getOperand(0)) additive = false;
      });
      bool perThread = useLib || !additive || (redProd < kWarpReductionMin && parProd >= kPerThreadMinOutputs);
      Value w = perThread ? gid : b.create<arith::DivUIOp>(loc, gid, c32);
      Value lane = perThread ? c0 : b.create<arith::RemUIOp>(loc, gid, c32);
      Value cond = b.create<arith::CmpIOp>(loc, arith::CmpIPredicate::slt, w, b.create<arith::ConstantIndexOp>(loc, parProd));
      auto ifOp = b.create<scf::IfOp>(loc, cond, false);
      b.setInsertionPointToStart(&ifOp.getThenRegion().front());

      SmallVector<Value> idx(nLoops, c0);
      delinearize(b, loc, w, parDims, sizes, idx);
      SmallVector<Value> pidx; for (unsigned d : parDims) pidx.push_back(idx[d]);

      Value acc;
      unsigned outOi = red->getNumOperands() - 1;
      if (useLib) {
        acc = b.create<memref::LoadOp>(loc, kmem(b, loc, red.getDpsInits()[0]), mapIndices(b, loc, red, outOi, idx));
        if (useConv) {
          Value init = evalInit(b, loc, red.getDpsInits()[0], initProducer.lookup(red.getOperation()), mapIndices(b, loc, red, outOi, idx), elemTy);
          acc = b.create<arith::AddFOp>(loc, acc, init);
        }
      } else {
        Value init = evalInit(b, loc, red.getDpsInits()[0], initProducer.lookup(red.getOperation()), mapIndices(b, loc, red, outOi, idx), elemTy);
        Value ub = b.create<arith::ConstantIndexOp>(loc, redProd);
        Value zero = b.create<arith::ConstantOp>(loc, b.getZeroAttr(elemTy));
        Value step = perThread ? b.create<arith::ConstantIndexOp>(loc, 1) : c32;
        auto forOp = b.create<scf::ForOp>(loc, lane, ub, step, ValueRange{perThread ? init : zero});
        {
          OpBuilder::InsertionGuard gg(b);
          b.setInsertionPointToStart(forOp.getBody());
          SmallVector<Value> lidx(idx.begin(), idx.end());
          delinearize(b, loc, forOp.getInductionVar(), redDims, sizes, lidx);
          unsigned numIns = red.getNumDpsInputs();
          SmallVector<Value> args;
          for (unsigned oi = 0; oi < red->getNumOperands(); oi++)
            args.push_back(oi < numIns ? loadOperand(b, loc, red, oi, lidx) : forOp.getRegionIterArgs()[0]);
          Value y = clonePayload(b, red, args, lidx);
          b.create<scf::YieldOp>(loc, y);
        }
        acc = forOp.getResult(0);
        Value width = b.create<arith::ConstantOp>(loc, b.getI32IntegerAttr(32));
        for (int off = perThread ? 0 : 16; off > 0; off >>= 1) {
          Value o = b.create<arith::ConstantOp>(loc, b.getI32IntegerAttr(off));
          auto sh = b.create<gpu::ShuffleOp>(loc, acc, o, width, gpu::ShuffleMode::DOWN);
          acc = b.create<arith::AddFOp>(loc, acc, sh.getShuffleResult());
        }
        if (!perThread) acc = b.create<arith::AddFOp>(loc, acc, init);
      }

      Value isLane0 = b.create<arith::CmpIOp>(loc, arith::CmpIPredicate::eq, lane, c0);
      auto if0 = b.create<scf::IfOp>(loc, isLane0, false);
      b.setInsertionPointToStart(&if0.getThenRegion().front());
      llvm::MapVector<Value, Value> produced;
      llvm::MapVector<Value, Operation*> producer;
      produced[red.getDpsInits()[0]] = acc; producer[red.getDpsInits()[0]] = red.getOperation();
      for (unsigned ei = 0; ei < g.epi.size(); ei++) {
        Operation *op = g.epi[ei];
        auto applyEvents = [&]() { for (auto &ev : events[gi]) if (ev.epiIdx == ei) rename[ev.init] = ev.fresh; };
        if (auto cp = dyn_cast<memref::CopyOp>(op)) {
          Value srcv = cp.getSource(), v;
          auto it = produced.find(srcv);
          if (it != produced.end()) v = it->second;
          else v = b.create<memref::LoadOp>(loc, kmem(b, loc, srcv), pidx);
          applyEvents();
          produced[cp.getTarget()] = v; producer[cp.getTarget()] = op;
          continue;
        }
        linalg::LinalgOp e = cast<linalg::LinalgOp>(op);
        unsigned numIns = e.getNumDpsInputs();
        SmallVector<Value> args;
        for (unsigned oi = 0; oi < e->getNumOperands(); oi++) {
          Value opd = e->getOperand(oi);
          auto it = produced.find(opd);
          if (it != produced.end()) args.push_back(it->second);
          else if (oi < numIns) args.push_back(loadOperand(b, loc, e, oi, pidx));
          else args.push_back(b.create<arith::ConstantOp>(loc, b.getZeroAttr(elemTy)));
        }
        Value y = clonePayload(b, e, args, pidx);
        applyEvents();
        Value init = e.getDpsInits()[0];
        produced[init] = y; producer[init] = op;
      }
      for (auto &kv : produced) {
        Operation *p = producer[kv.first];
        SmallVector<Value> sidx;
        if (auto pl = dyn_cast<linalg::LinalgOp>(p)) sidx = mapIndices(b, loc, pl, pl->getNumOperands() - 1, (pl == red) ? ArrayRef<Value>(idx) : ArrayRef<Value>(pidx));
        else sidx.assign(pidx.begin(), pidx.end());
        b.create<memref::StoreOp>(loc, kv.second, kmem(b, loc, kv.first), sidx);
      }
      b.setInsertionPointAfter(ifOp);
      b.create<gpu::ReturnOp>(loc);
      launch(kfunc, perThread ? (parProd + 255) / 256 : (parProd * 32 + 255) / 256);
      releaseAfter(gi);
    }

    hb.setInsertionPoint(host.getBody().front().getTerminator());
    for (Operation *op : llvm::reverse(seq)) op->erase();
    for (Value a : allocs) if (noRelease || !lastUse.count(a)) { if (a.use_empty()) a.getDefiningOp()->erase(); else hb.create<memref::DeallocOp>(loc, a); }
  }
};

// Fold pure-permutation linalg.generic (transpose after generalization) into
// its consumers' indexing maps. Run after -linalg-generalize-named-ops.
struct FortisFoldTransposePass
    : public PassWrapper<FortisFoldTransposePass, OperationPass<func::FuncOp>> {
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(FortisFoldTransposePass)
  StringRef getArgument() const final { return "fortis-fold-transpose"; }
  StringRef getDescription() const final { return "Fold transposes into consumer indexing maps"; }

  static bool isPermCopy(linalg::GenericOp g, SmallVector<int64_t> &perm) {
    if (g.getNumDpsInputs() != 1 || g.getNumDpsInits() != 1) return false;
    for (auto it : g.getIteratorTypesArray())
      if (it != utils::IteratorType::parallel) return false;
    Block &body = g.getRegion().front();
    auto yield = cast<linalg::YieldOp>(body.getTerminator());
    if (yield.getNumOperands() != 1 || yield.getOperand(0) != body.getArgument(0)) return false;
    auto maps = g.getIndexingMapsArray();
    if (!maps[0].isPermutation() || !maps[1].isPermutation()) return false;
    // perm[k] = loop dim of OUT dim k;  inl[j] = loop dim of IN dim j
    perm.clear();
    for (AffineExpr e : maps[1].getResults())
      perm.push_back(cast<AffineDimExpr>(e).getPosition());
    for (AffineExpr e : maps[0].getResults())
      perm.push_back(cast<AffineDimExpr>(e).getPosition());
    return true;
  }

  void runOnOperation() override {
    func::FuncOp f = getOperation();
    SmallVector<linalg::GenericOp> cands;
    f.walk([&](linalg::GenericOp g) { cands.push_back(g); });
    for (linalg::GenericOp t : cands) {
      SmallVector<int64_t> perm;
      if (!isPermCopy(t, perm)) continue;
      Value res = t->getResult(0);
      Value in = t.getDpsInputs()[0];
      unsigned rank = perm.size() / 2;
      ArrayRef<int64_t> outl(perm.data(), rank), inl(perm.data() + rank, rank);
      for (OpOperand &use : llvm::make_early_inc_range(res.getUses())) {
        auto g = dyn_cast<linalg::GenericOp>(use.getOwner());
        if (!g || !g.isDpsInput(&use)) continue;
        unsigned idx = use.getOperandNumber();
        SmallVector<AffineMap> maps = g.getIndexingMapsArray();
        AffineMap m = maps[idx];
        // consumer index r_k addresses out dim k = loop outl[k];
        // in dim j = loop inl[j]  =>  newRes[j] = r_k where outl[k] == inl[j]
        SmallVector<AffineExpr> newRes(rank);
        for (unsigned j = 0; j < rank; j++)
          for (unsigned k = 0; k < rank; k++)
            if (outl[k] == inl[j]) newRes[j] = m.getResult(k);
        maps[idx] = AffineMap::get(m.getNumDims(), 0, newRes, g.getContext());
        OpBuilder b(g);
        g.setIndexingMapsAttr(b.getAffineMapArrayAttr(maps));
        use.set(in);
      }
      if (res.use_empty()) t->erase();
    }
  }
};

} // namespace

int main(int argc, char **argv) {
  DialectRegistry registry;
  registerAllDialects(registry);
  PassRegistration<FortisFusePass>();
  PassRegistration<FortisFoldTransposePass>();
  return asMainReturnCode(MlirOptMain(argc, argv, "fortis-opt", registry));
}
