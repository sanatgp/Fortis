import sys, torch
sys.argv = [sys.argv[0]]
exec(open("export_sam.py").read().split("if len(sys.argv)")[0])
for B in (1, 3240):
    torch.onnx.export(m, torch.zeros(B, 61), f"sam_b{B}.onnx", input_names=["x"], output_names=["y"], opset_version=17, dynamo=False)
    print("wrote sam_b%d.onnx" % B)
