#include <torch/script.h>
#include <torch/torch.h>
#include <memory>
#include <string>
#include <cstring>

extern "C" {

struct TorchModel {
    torch::jit::script::Module module;
    torch::Device device;
    int64_t input_size;
    int64_t output_size;
    bool initialized;
};

void* torch_load_model(const char* path) {
    try {
        auto* model = new TorchModel();
        model->device = torch::kCPU;
        model->module = torch::jit::load(path);
        model->module.to(model->device);
        model->module.eval();
        
        torch::NoGradGuard no_grad;
        auto test_input = torch::zeros({1, 128}, torch::kFloat32);
        auto output = model->module.forward({test_input}).toTensor();
        
        model->input_size = test_input.size(1);
        model->output_size = output.size(1);
        model->initialized = true;
        
        return model;
    } catch (const c10::Error& e) {
        return nullptr;
    }
}

int torch_forward_batch(void* model_ptr, 
                       const float* input, int input_size, int batch_size,
                       float* output, int output_size) {
    if (!model_ptr) return -1;
    
    TorchModel* model = static_cast<TorchModel*>(model_ptr);
    if (!model->initialized) return -2;
    
    try {
        torch::NoGradGuard no_grad;
        
        auto options = torch::TensorOptions()
            .dtype(torch::kFloat32)
            .device(model->device)
            .requires_grad(false);
        
        auto input_tensor = torch::from_blob(
            const_cast<float*>(input),
            {input_size, batch_size},
            {1, input_size},
            options
        ).transpose(0, 1).contiguous();
        
        std::vector<torch::jit::IValue> inputs{input_tensor};
        auto output_tensor = model->module.forward(inputs).toTensor();
        
        if (output_tensor.dim() != 2) return -3;
        if (output_tensor.size(0) != batch_size) return -4;
        if (output_tensor.size(1) != output_size) return -5;
        
        output_tensor = output_tensor.transpose(0, 1).contiguous();
        
        std::memcpy(output, output_tensor.data_ptr<float>(), 
                   sizeof(float) * output_size * batch_size);
        
        return 0;
    } catch (const c10::Error& e) {
        return -6;
    }
}

void torch_free_model(void* model_ptr) {
    if (model_ptr) {
        TorchModel* model = static_cast<TorchModel*>(model_ptr);
        delete model;
    }
}

int torch_get_input_size(void* model_ptr) {
    if (!model_ptr) return -1;
    TorchModel* model = static_cast<TorchModel*>(model_ptr);
    return model->input_size;
}

int torch_get_output_size(void* model_ptr) {
    if (!model_ptr) return -1;
    TorchModel* model = static_cast<TorchModel*>(model_ptr);
    return model->output_size;
}

}