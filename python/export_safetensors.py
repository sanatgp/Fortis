import json
import torch
import torch.nn as nn
import safetensors.torch as st
from pathlib import Path
import argparse
import numpy as np

class ChemistryMLP(nn.Module):
    def __init__(self, d_in, h1, h2, d_out):
        super().__init__()
        self.l0 = nn.Linear(d_in, h1)
        self.l1 = nn.Linear(h1, h2)
        self.out = nn.Linear(h2, d_out)
        
    def forward(self, x):
        x = torch.relu(self.l0(x))
        x = torch.relu(self.l1(x))
        return self.out(x)

def export_model(model_path, output_dir, trace_input=None):
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    checkpoint = torch.load(model_path, map_location='cpu')
    
    if 'model_config' in checkpoint:
        config = checkpoint['model_config']
    else:
        config = {
            'd_in': 128,
            'h1': 512,
            'h2': 512,
            'd_out': 128
        }
    
    model = ChemistryMLP(**config)
    
    if 'model_state_dict' in checkpoint:
        model.load_state_dict(checkpoint['model_state_dict'])
    else:
        model.load_state_dict(checkpoint)
    
    model.eval()
    
    tensors = {}
    for name, param in model.named_parameters():
        tensors[name] = param.contiguous().cpu()
    
    st.save_file(tensors, str(output_dir / 'model.safetensors'))
    
    meta = {
        'd_in': config['d_in'],
        'h1': config['h1'],
        'h2': config['h2'],
        'd_out': config['d_out'],
        'activation': 'relu',
        'layers': [
            {'name': 'l0', 'type': 'linear', 'shape': [config['h1'], config['d_in']]},
            {'name': 'l1', 'type': 'linear', 'shape': [config['h2'], config['h1']]},
            {'name': 'out', 'type': 'linear', 'shape': [config['d_out'], config['h2']]}
        ]
    }
    
    with open(output_dir / 'model.meta.json', 'w') as f:
        json.dump(meta, f, indent=2)
    
    if trace_input is None:
        trace_input = torch.randn(1, config['d_in'])
    
    traced = torch.jit.trace(model, trace_input)
    traced.save(str(output_dir / 'model.pt'))
    
    norm_stats = {}
    if 'normalization' in checkpoint:
        norm_stats = checkpoint['normalization']
    else:
        norm_stats = {
            'input_mean': np.zeros(config['d_in']).tolist(),
            'input_std': np.ones(config['d_in']).tolist(),
            'output_mean': np.zeros(config['d_out']).tolist(),
            'output_std': np.ones(config['d_out']).tolist()
        }
    
    with open(output_dir / 'norm_stats.json', 'w') as f:
        json.dump(norm_stats, f, indent=2)
    
    print(f"Exported model to {output_dir}")
    print(f"  model.safetensors: {sum(p.numel() * 4 for p in model.parameters()) / 1024:.1f} KB")
    print(f"  model.pt: TorchScript module")
    print(f"  model.meta.json: Model metadata")
    print(f"  norm_stats.json: Normalization parameters")

def validate_export(model_dir):
    model_dir = Path(model_dir)
    
    meta = json.load(open(model_dir / 'model.meta.json'))
    weights = st.load_file(str(model_dir / 'model.safetensors'))
    
    required_weights = ['l0.weight', 'l0.bias', 'l1.weight', 'l1.bias', 'out.weight', 'out.bias']
    for w in required_weights:
        assert w in weights, f"Missing weight: {w}"
    
    assert weights['l0.weight'].shape == (meta['h1'], meta['d_in'])
    assert weights['l1.weight'].shape == (meta['h2'], meta['h1'])
    assert weights['out.weight'].shape == (meta['d_out'], meta['h2'])
    
    print("Export validation passed")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('model', help='Path to PyTorch model checkpoint')
    parser.add_argument('--output', '-o', default='./fortis_model', help='Output directory')
    parser.add_argument('--validate', action='store_true', help='Validate export')
    args = parser.parse_args()
    
    export_model(args.model, args.output)
    
    if args.validate:
        validate_export(args.output)