
#ifndef CUDATEST_L2_LINESIZEALT
#define CUDATEST_L2_LINESIZEALT

# include <cstdio>

# include "cuda.h"
# include "../eval.h"
# include "../GPU_resources.cuh"

__global__ void l2_lineSize (unsigned int N, unsigned int * my_array, unsigned int *missIndex);

unsigned int launchL2LineSizeAltKernelBenchmark(unsigned int N, int stride, int* error);

unsigned int measure_L2_LineSize_Alt(unsigned int l2SizeBytes) {
    unsigned int l2SizeInts = l2SizeBytes >> 2; // / 4;
    int error = 0;

    unsigned int lineSize = 0;
    // Doubling the size of N such that the whole array is not already cached in L2 after copy from Host to GPU
    lineSize = launchL2LineSizeAltKernelBenchmark(l2SizeInts * 2, 1, &error);
    if (error != 0) {
        printErrorCodeInformation(error);
        exit(error);
    }
    return lineSize;
}

unsigned int launchL2LineSizeAltKernelBenchmark(unsigned int N, int stride, int* error) {
    unsigned int lineSize = 0;
    cudaError_t error_id;
    unsigned int *h_a = nullptr, *h_missIndex = nullptr,
    *d_a = nullptr, *d_missIndex = nullptr;

    do {
        // Allocate Memory on Host Memory
        h_a = (unsigned int *) malloc(sizeof(unsigned int) * (N));
        if (h_a == nullptr) {
            printf("[L2_LINESIZE.CUH]: malloc h_a Error\n");
            *error = 1;
            break;
        }

        h_missIndex = (unsigned int*) calloc(LineMeasureSize, sizeof(unsigned int));
        if (h_missIndex == nullptr) {
            printf("[L2_LINESIZE.CUH]: malloc h_missIndex Error\n");
            *error = 1;
            break;
        }

        // Allocate Memory on GPU Memory
        error_id = cudaMalloc((void **) &d_a, sizeof(unsigned int) * (N));
        if (error_id != cudaSuccess) {
            printf("[L2_LINESIZE.CUH]: cudaMalloc d_a Error: %s\n", cudaGetErrorString(error_id));
            *error = 2;
            break;
        }

        error_id = cudaMalloc((void **) &d_missIndex, sizeof(int) * LineMeasureSize);
        if (error_id != cudaSuccess) {
            printf("[L2_LINESIZE.CUH]: cudaMalloc d_missIndex Error: %s\n", cudaGetErrorString(error_id));
            *error = 2;
            break;
        }

        // Initialize p-chase array
        for (int i = 0; i < N; i++) {
            //original:
            h_a[i] = (i + stride) % N;
        }

        // Copy elements from Host to GPU
        error_id = cudaMemcpy(d_a, h_a, sizeof(unsigned int) * N, cudaMemcpyHostToDevice);
        if (error_id != cudaSuccess) {
            printf("[L2_LINESIZE.CUH]: cudaMemcpy d_a Error: %s\n", cudaGetErrorString(error_id));
            *error = 3;
            break;
        }

        // Copy zeroes to GPU array
        error_id = cudaMemcpy(d_missIndex, h_missIndex, sizeof(unsigned int) * LineMeasureSize, cudaMemcpyHostToDevice);
        if (error_id != cudaSuccess) {
            printf("[L2_LINESIZE.CUH]: cudaMemcpy d_missIndex Error: %s\n", cudaGetErrorString(error_id));
            *error = 3;
            break;
        }

        cudaDeviceSynchronize();

        // Launch Kernel function
        dim3 Db = dim3(1);
        dim3 Dg = dim3(1, 1, 1);
        l2_lineSize <<<Dg, Db>>>(N, d_a, d_missIndex);
        cudaDeviceSynchronize();

        error_id = cudaGetLastError();
        if (error_id != cudaSuccess) {
            printf("[L2_LINESIZE.CUH]: Kernel launch/execution with clock Error: %s\n", cudaGetErrorString(error_id));
            *error = 5;
            break;
        }
        cudaDeviceSynchronize();

        // Copy results from GPU to Host
        error_id = cudaMemcpy((void *) h_missIndex, (void *) d_missIndex, sizeof(unsigned int) * LineMeasureSize, cudaMemcpyDeviceToHost);
        if (error_id != cudaSuccess) {
            printf("[L2_LINESIZE.CUH]: cudaMemcpy d_missIndex Error: %s\n", cudaGetErrorString(error_id));
            *error = 6;
            break;
        }
        cudaDeviceSynchronize();

        lineSize = getMostValueInArray(h_missIndex, LineMeasureSize) * 4;
        cudaDeviceSynchronize();
    } while(false);

    // Free Memory on GPU
    if (d_a != nullptr) {
        cudaFree(d_a);
    }

    if (d_missIndex != nullptr) {
        cudaFree(d_missIndex);
    }

    // Free Memory on Host
    if (h_a != nullptr) {
        free(h_a);
    }

    if (h_missIndex != nullptr) {
        free(h_missIndex);
    }

    cudaDeviceReset();

    return lineSize;
}

__global__ void l2_lineSize (unsigned int N, unsigned int* my_array, unsigned int *missIndex) {
    unsigned int start_time, end_time;
    unsigned int j = 0;
    int tol = 50;

    // Using cold cache misses for this cache
    for (int k = 0; k < LineMeasureSize; k++) {
        unsigned int* ptr = my_array + j;
        start_time = clock();
        asm volatile("ld.global.cg.u32 %0, [%1];\n\t" : "=r"(j) : "l"(ptr) : "memory");
        s_index[k] = j;
        end_time = clock();
        s_tvalue[k] = end_time - start_time;
    }

    unsigned long long ref = 0;
    for (int i = 0; i < LineMeasureSize; ++i) {
        ref = ref + s_tvalue[i];
    }
    ref = ref / LineMeasureSize;

    int lastMissIndex = 0;
    int missPtr = 0;

    for (int i = 1; i < LineMeasureSize; ++i) {
        if (s_tvalue[i] > ref + tol) {
            missIndex[missPtr] = i - lastMissIndex;
            lastMissIndex = i;
            ++missPtr;
        }
    }
}

#endif //CUDATEST_L2_LINESIZEALT

