#define _GNU_SOURCE
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdio.h>
#include <errno.h>

typedef struct {
    void* addr;
    size_t size;
    int fd;
} mmap_handle;

void* mmap_file(const char* filename, int* out_size) {
    int fd = open(filename, O_RDONLY);
    if (fd < 0) {
        return NULL;
    }
    
    struct stat st;
    if (fstat(fd, &st) < 0) {
        close(fd);
        return NULL;
    }
    
    void* addr = mmap(NULL, st.st_size, PROT_READ, MAP_SHARED, fd, 0);
    close(fd);
    
    if (addr == MAP_FAILED) {
        return NULL;
    }
    
    if (madvise(addr, st.st_size, MADV_SEQUENTIAL | MADV_WILLNEED) != 0) {
    }
    
    *out_size = st.st_size;
    return addr;
}

void munmap_file(void* addr, int size) {
    if (addr && size > 0) {
        munmap(addr, size);
    }
}

void* shm_create(const char* name, size_t size) {
    int fd = shm_open(name, O_CREAT | O_RDWR, 0666);
    if (fd < 0) {
        return NULL;
    }
    
    if (ftruncate(fd, size) < 0) {
        close(fd);
        shm_unlink(name);
        return NULL;
    }
    
    void* addr = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
    
    if (addr == MAP_FAILED) {
        shm_unlink(name);
        return NULL;
    }
    
    return addr;
}

void* shm_attach(const char* name, size_t size) {
    int fd = shm_open(name, O_RDONLY, 0666);
    if (fd < 0) {
        return NULL;
    }
    
    void* addr = mmap(NULL, size, PROT_READ, MAP_SHARED, fd, 0);
    close(fd);
    
    if (addr == MAP_FAILED) {
        return NULL;
    }
    
    return addr;
}

void shm_detach(void* addr, size_t size) {
    if (addr && size > 0) {
        munmap(addr, size);
    }
}

void shm_destroy(const char* name) {
    shm_unlink(name);
}

typedef struct {
    uint64_t header_size;
    char header_json[1];
} safetensors_file;

typedef struct {
    size_t offset;
    size_t length;
    int dtype;
    int ndim;
    int64_t shape[4];
} tensor_info;

void* parse_safetensors_header(void* file_addr, size_t file_size, tensor_info** out_tensors, int* out_count) {
    if (file_size < sizeof(uint64_t)) {
        return NULL;
    }
    
    safetensors_file* sf = (safetensors_file*)file_addr;
    uint64_t header_size = sf->header_size;
    
    if (header_size > file_size - sizeof(uint64_t)) {
        return NULL;
    }
    
    char* data_start = (char*)file_addr + sizeof(uint64_t) + header_size;
    
    *out_tensors = NULL;
    *out_count = 0;
    
    return data_start;
}

float* get_tensor_ptr(void* file_addr, const char* tensor_name, 
                     int* rows, int* cols) {
    safetensors_file* sf = (safetensors_file*)file_addr;
    uint64_t header_size = sf->header_size;
    
    char* header = sf->header_json;
    char* data_start = (char*)file_addr + sizeof(uint64_t) + header_size;
    
    char search_key[256];
    snprintf(search_key, sizeof(search_key), "\"%s\"", tensor_name);
    
    char* pos = strstr(header, search_key);
    if (!pos) return NULL;
    
    char* offset_str = strstr(pos, "\"data_offsets\":[");
    if (!offset_str) return NULL;
    offset_str += strlen("\"data_offsets\":[");
    
    size_t start_offset, end_offset;
    sscanf(offset_str, "%zu,%zu", &start_offset, &end_offset);
    
    char* shape_str = strstr(pos, "\"shape\":[");
    if (!shape_str) return NULL;
    shape_str += strlen("\"shape\":[");
    
    int shape_dims[4] = {1, 1, 1, 1};
    int dim_count = 0;
    char* shape_end = strchr(shape_str, ']');
    if (shape_end) {
        char shape_copy[256];
        size_t len = shape_end - shape_str;
        if (len < sizeof(shape_copy)) {
            strncpy(shape_copy, shape_str, len);
            shape_copy[len] = '\0';
            
            char* tok = strtok(shape_copy, ",");
            while (tok && dim_count < 4) {
                shape_dims[dim_count++] = atoi(tok);
                tok = strtok(NULL, ",");
            }
        }
    }
    
    if (dim_count == 2) {
        *rows = shape_dims[0];
        *cols = shape_dims[1];
    } else if (dim_count == 1) {
        *rows = shape_dims[0];
        *cols = 1;
    }
    
    return (float*)(data_start + start_offset);
}

typedef struct {
    float* l0_weight;
    float* l0_bias;
    float* l1_weight;
    float* l1_bias;
    float* out_weight;
    float* out_bias;
    int h1, h2, d_in, d_out;
} model_weights;

model_weights* load_safetensors_weights(const char* filename) {
    int file_size;
    void* file_addr = mmap_file(filename, &file_size);
    if (!file_addr) return NULL;
    
    model_weights* weights = (model_weights*)calloc(1, sizeof(model_weights));
    if (!weights) {
        munmap_file(file_addr, file_size);
        return NULL;
    }
    
    int rows, cols;
    
    weights->l0_weight = get_tensor_ptr(file_addr, "l0.weight", &rows, &cols);
    weights->h1 = rows;
    weights->d_in = cols;
    
    weights->l0_bias = get_tensor_ptr(file_addr, "l0.bias", &rows, &cols);
    
    weights->l1_weight = get_tensor_ptr(file_addr, "l1.weight", &rows, &cols);
    weights->h2 = rows;
    
    weights->l1_bias = get_tensor_ptr(file_addr, "l1.bias", &rows, &cols);
    
    weights->out_weight = get_tensor_ptr(file_addr, "out.weight", &rows, &cols);
    weights->d_out = rows;
    
    weights->out_bias = get_tensor_ptr(file_addr, "out.bias", &rows, &cols);
    
    return weights;
}

void free_safetensors_weights(model_weights* weights) {
    if (weights) {
        free(weights);
    }
}