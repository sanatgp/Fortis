import sys, torch
sys.argv = [sys.argv[0]]
exec(open("export_zb.py").read().split("if (len(sys.argv)")[0])   # defines m
for B in (1, 2, 4736):
    torch.onnx.export(m, torch.zeros(B, 27), f"zb_b{B}.onnx", input_names=["x"], output_names=["y"], opset_version=17, dynamo=False)
    print("exported zb_b%d.onnx" % B)
