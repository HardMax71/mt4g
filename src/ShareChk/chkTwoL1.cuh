
#ifndef CUDATEST_TWOL1
#define CUDATEST_TWOL1

# include <cstdio>
# include <cstdint>

# include "cuda.h"


__global__ void chkTwoL1(unsigned int N, unsigned int* array1, unsigned int* array2, unsigned int *duration1, unsigned int * duration2, unsigned int *index1, unsigned int *index2,
                         bool* isDisturbed) {
    *isDisturbed = false;

    unsigned int start_time, end_time;
    unsigned int j = 0;
    __shared__ long long s_tvalue1[LESS_SIZE];
    __shared__ unsigned int s_index1[LESS_SIZE];
    __shared__ long long s_tvalue2[LESS_SIZE];
    __shared__ unsigned int s_index2[LESS_SIZE];

    __syncthreads();

    if (threadIdx.x == 0) {
        for (int k = 0; k < LESS_SIZE; k++) {
            s_index1[k] = 0;
            s_tvalue1[k] = 0;
        }
    }

    __syncthreads();

    if (threadIdx.x == 1){
        for (int k = 0; k < LESS_SIZE; k++) {
            s_index2[k] = 0;
            s_tvalue2[k] = 0;
        }
    }

    unsigned int* ptr;
    __syncthreads();

    if (threadIdx.x == 0) {
        for (int k = 0; k < N; k++) {
            ptr = array1 + j;
            asm volatile("ld.global.ca.u32 %0, [%1];" : "=r"(j) : "l"(ptr) : "memory");
        }
    }

    __syncthreads();

    if (threadIdx.x == 1){
        for (int k = 0; k < N; k++) {
            ptr = array2 + j;
            asm volatile("ld.global.ca.u32 %0, [%1];" : "=r"(j) : "l"(ptr) : "memory");
        }
    }

    __syncthreads();

    if (threadIdx.x == 0) {
        //second round
        for (int k = 0; k < LESS_SIZE; k++) {
            ptr = array1 + j;
            start_time = clock();
            asm volatile("ld.global.ca.u32 %0, [%1];" : "=r"(j) : "l"(ptr) : "memory");
            s_index1[k] = j;
            end_time = clock();
            s_tvalue1[k] = (end_time - start_time);
        }
    }

    __syncthreads();

    if (threadIdx.x == 1){
        for (int k = 0; k < LESS_SIZE; k++) {
            ptr = array2 + j;
            start_time = clock();
            asm volatile("ld.global.ca.u32 %0, [%1];" : "=r"(j) : "l"(ptr) : "memory");
            s_index2[k] = j;
            end_time = clock();
            s_tvalue2[k] = (end_time - start_time);
        }
    }

    __syncthreads();

    if (threadIdx.x == 0) {
        for (int k = 0; k < LESS_SIZE; k++) {
            index1[k] = s_index1[k];
            duration1[k] = s_tvalue1[k];
            if (duration1[k] > 3000) {
                *isDisturbed = true;
            }
        }
    }

    __syncthreads();

    if (threadIdx.x == 1) {
        for (int k = 0; k < LESS_SIZE; k++) {
            index2[k] = s_index2[k];
            duration2[k] = s_tvalue2[k];
            if (duration2[k] > 3000) {
                *isDisturbed = true;
            }
        }
    }
}

bool launchBenchmarkTwoL1(unsigned int N, double *avgOut1, double* avgOut2, unsigned int* potMissesOut1, unsigned int* potMissesOut2, unsigned int **time1, unsigned int **time2, int* error) {
    cudaDeviceReset();
    cudaError_t error_id;

    unsigned int *h_index1 = nullptr, *h_index2 = nullptr, *h_timeinfo1 = nullptr, *h_timeinfo2 = nullptr, *h_a = nullptr,
    *duration1 = nullptr, *duration2 = nullptr, *d_index1 = nullptr, *d_index2 = nullptr, *d_a1 = nullptr, *d_a2 = nullptr;
    bool *disturb = nullptr, *d_disturb = nullptr;

    do {
        // Allocate Memory on Host
        h_index1 = (unsigned int *) malloc(sizeof(unsigned int) * LESS_SIZE);
        if (h_index1 == nullptr) {
            printf("[CHKTWOL1.CUH]: malloc h_index1 Error\n");
            *error = 1;
            break;
        }

        h_index2 = (unsigned int *) malloc(sizeof(unsigned int) * LESS_SIZE);
        if (h_index2 == nullptr) {
            printf("[CHKTWOL1.CUH]: malloc h_index2 Error\n");
            *error = 1;
            break;
        }

        h_timeinfo1 = (unsigned int *) malloc(sizeof(unsigned int) * LESS_SIZE);
        if (h_timeinfo1 == nullptr) {
            printf("[CHKTWOL1.CUH]: malloc h_timeinfo1 Error\n");
            *error = 1;
            break;
        }

        h_timeinfo2 = (unsigned int *) malloc(sizeof(unsigned int) * LESS_SIZE);
        if (h_timeinfo2 == nullptr) {
            printf("[CHKTWOL1.CUH]: malloc h_timeinfo2 Error\n");
            *error = 1;
            break;
        }

        disturb = (bool *) malloc(sizeof(bool));
        if (disturb == nullptr) {
            printf("[CHKTWOL1.CUH]: malloc disturb Error\n");
            *error = 1;
            break;
        }

        h_a = (unsigned int *) malloc(sizeof(unsigned int) * (N));
        if (h_a == nullptr) {
            printf("[CHKTWOL1.CUH]: malloc h_a Error\n");
            *error = 1;
            break;
        }

        // Allocate Memory on GPU
        error_id = cudaMalloc((void **) &duration1, sizeof(unsigned int) * LESS_SIZE);
        if (error_id != cudaSuccess) {
            printf("[CHKTWOL1.CUH]: cudaMalloc duration1 Error: %s\n", cudaGetErrorString(error_id));
            *error = 2;
            break;
        }

        error_id = cudaMalloc((void **) &duration2, sizeof(unsigned int) * LESS_SIZE);
        if (error_id != cudaSuccess) {
            printf("[CHKTWOL1.CUH]: cudaMalloc duration2 Error: %s\n", cudaGetErrorString(error_id));
            *error = 2;
            break;
        }

        error_id = cudaMalloc((void **) &d_index1, sizeof(unsigned int) * LESS_SIZE);
        if (error_id != cudaSuccess) {
            printf("[CHKTWOL1.CUH]: cudaMalloc d_index1 Error: %s\n", cudaGetErrorString(error_id));
            *error = 2;
            break;
        }

        error_id = cudaMalloc((void **) &d_index2, sizeof(unsigned int) * LESS_SIZE);
        if (error_id != cudaSuccess) {
            printf("[CHKTWOL1.CUH]: cudaMalloc d_index2 Error: %s\n", cudaGetErrorString(error_id));
            *error = 2;
            break;
        }

        error_id = cudaMalloc((void **) &d_disturb, sizeof(bool));
        if (error_id != cudaSuccess) {
            printf("[CHKTWOL1.CUH]: cudaMalloc disturb Error: %s\n", cudaGetErrorString(error_id));
            *error = 2;
            break;
        }

        error_id = cudaMalloc((void **) &d_a1, sizeof(unsigned int) * (N));
        if (error_id != cudaSuccess) {
            printf("[CHKTWOL1.CUH]: cudaMalloc d_a1 Error: %s\n", cudaGetErrorString(error_id));
            *error = 2;
            break;
        }
        error_id = cudaMalloc((void **) &d_a2, sizeof(unsigned int) * (N));
        if (error_id != cudaSuccess) {
            printf("[CHKTWOL1.CUH]: cudaMalloc d_a2 Error: %s\n", cudaGetErrorString(error_id));
            *error = 2;
            break;
        }

        // Initialize p-chase array
        for (int i = 0; i < N; i++) {
            h_a[i] = (i + 1) % N;
        }

        // Copy array from Host to GPU
        error_id = cudaMemcpy(d_a1, h_a, sizeof(unsigned int) * N, cudaMemcpyHostToDevice);
        if (error_id != cudaSuccess) {
            printf("[CHKTWOL1.CUH]: cudaMemcpy d_a1 Error: %s\n", cudaGetErrorString(error_id));
            *error = 3;
            break;
        }

        error_id = cudaMemcpy(d_a2, h_a, sizeof(unsigned int) * N, cudaMemcpyHostToDevice);
        if (error_id != cudaSuccess) {
            printf("[CHKTWOL1.CUH]: cudaMemcpy d_a2 Error: %s\n", cudaGetErrorString(error_id));
            *error = 3;
            break;
        }

        cudaDeviceSynchronize();

        error_id = cudaGetLastError();
        if (error_id != cudaSuccess) {
            printf("[CHKTWOL1.CUH]: cudaDeviceSynchronize Error: %s\n", cudaGetErrorString(error_id));
            *error = 99;
            break;
        }
        cudaDeviceSynchronize();

        // Launch Kernel function
        dim3 Db = dim3(2);
        dim3 Dg = dim3(1, 1, 1);
        chkTwoL1<<<Dg, Db>>>(N, d_a1, d_a2, duration1, duration2, d_index1, d_index2, d_disturb);

        cudaDeviceSynchronize();
        error_id = cudaGetLastError();
        if (error_id != cudaSuccess) {
            printf("[CHKTWOL1.CUH]: Kernel launch/execution Error: %s\n", cudaGetErrorString(error_id));
            *error = 5;
            break;
        }

        // Copy results from GPU to Host
        error_id = cudaMemcpy((void *) h_timeinfo1, (void *) duration1, sizeof(unsigned int) * LESS_SIZE, cudaMemcpyDeviceToHost);
        if (error_id != cudaSuccess) {
            printf("[CHKTWOL1.CUH]: cudaMemcpy duration1 Error: %s\n", cudaGetErrorString(error_id));
            *error = 6;
            break;
        }

        error_id = cudaMemcpy((void *) h_timeinfo2, (void *) duration2, sizeof(unsigned int) * LESS_SIZE, cudaMemcpyDeviceToHost);
        if (error_id != cudaSuccess) {
            printf("[CHKTWOL1.CUH]: cudaMemcpy duration2 Error: %s\n", cudaGetErrorString(error_id));
            *error = 6;
            break;
        }

        error_id = cudaMemcpy((void *) h_index1, (void *) d_index1, sizeof(unsigned int) * LESS_SIZE, cudaMemcpyDeviceToHost);
        if (error_id != cudaSuccess) {
            printf("[CHKTWOL1.CUH]: cudaMemcpy d_index1 Error: %s\n", cudaGetErrorString(error_id));
            *error = 6;
            break;
        }

        error_id = cudaMemcpy((void *) h_index2, (void *) d_index2, sizeof(unsigned int) * LESS_SIZE, cudaMemcpyDeviceToHost);
        if (error_id != cudaSuccess) {
            printf("[CHKTWOL1.CUH]: cudaMemcpy d_index2 Error: %s\n", cudaGetErrorString(error_id));
            *error = 6;
            break;
        }

        error_id = cudaMemcpy((void *) disturb, (void *) d_disturb, sizeof(bool), cudaMemcpyDeviceToHost);
        if (error_id != cudaSuccess) {
            printf("[CHKTWOL1.CUH]: cudaMemcpy disturb Error: %s\n", cudaGetErrorString(error_id));
            *error = 6;
            break;
        }

        createOutputFile((int) N, LESS_SIZE, h_index1, h_timeinfo1, avgOut1, potMissesOut1, "TwoL1_1_");
        createOutputFile((int) N, LESS_SIZE, h_index2, h_timeinfo2, avgOut2, potMissesOut2, "TwoL1_2_");
    } while(false);

    bool ret = false;
    if (disturb != nullptr) {
        ret = *disturb;
        free(disturb);
    }

    // Free Memory on GPU
    if (d_index1 != nullptr) {
        cudaFree(d_index1);
    }

    if (d_index2 != nullptr) {
        cudaFree(d_index2);
    }

    if (duration1 != nullptr) {
        cudaFree(duration1);
    }

    if (duration2 != nullptr) {
        cudaFree(duration2);
    }

    if (d_a1 != nullptr) {
        cudaFree(d_a1);
    }

    if (d_a2 != nullptr) {
        cudaFree(d_a2);
    }

    if (d_disturb != nullptr) {
        cudaFree(d_disturb);
    }

    // Free Memory on Host
    if (h_index1 != nullptr) {
        free(h_index1);
    }

    if (h_index2 != nullptr) {
        free(h_index2);
    }

    if (h_a != nullptr) {
        free(h_a);
    }

    if (h_timeinfo1 != nullptr) {
        if (time1 != nullptr) {
            time1[0] = h_timeinfo1;
        } else {
            free(h_timeinfo1);
        }
    }

    if (h_timeinfo2 != nullptr) {
        if (time2 != nullptr) {
            time2[0] = h_timeinfo2;
        } else {
            free(h_timeinfo2);
        }
    }

    cudaDeviceReset();
    return ret;
}

#define FreeMeasureTwoL1ResOnlyPtr()        \
free(time);                                 \
free(timeRef);                              \
free(avgFlow);                              \
free(potMissesFlow);                        \
free(avgFlowRef);                           \
free(potMissesFlowRef);                     \

#define FreeMeasureTwoL1Resources()         \
if (time[0] != nullptr) {                   \
    free(time[0]);                          \
}                                           \
if (time[1] != nullptr) {                   \
    free(time[1]);                          \
}                                           \
if (timeRef[0] != nullptr) {                \
    free(timeRef[0]);                       \
}                                           \
free(time);                                 \
free(timeRef);                              \
free(avgFlow);                              \
free(potMissesFlow);                        \
free(avgFlowRef);                           \
free(potMissesFlowRef);                     \

double measure_TwoL1(unsigned int measuredSizeCache, unsigned int sub) {
    unsigned int CacheSizeInInt = (measuredSizeCache - sub) / 4;

    double* avgFlowRef = (double*) malloc(sizeof(double));
    unsigned int *potMissesFlowRef = (unsigned int*) malloc(sizeof(unsigned int));
    unsigned int** timeRef = (unsigned int**) malloc(sizeof(unsigned int*));

    double* avgFlow = (double*) malloc(sizeof(double)  * 2);
    unsigned int *potMissesFlow = (unsigned int*) malloc(sizeof(unsigned int) * 2);
    unsigned int** time = (unsigned int**) malloc(sizeof(unsigned int*) * 2);
    if (avgFlowRef == nullptr || potMissesFlowRef == nullptr || timeRef == nullptr ||
        avgFlow == nullptr || potMissesFlow == nullptr || time == nullptr) {
        FreeMeasureTwoL1ResOnlyPtr()
        printErrorCodeInformation(1);
        exit(1);
    }
    timeRef[0] = time[0] = time[1] = nullptr;

    bool dist = true;
    int n = 5;
    while(dist && n > 0) {
        int error = 0;
        dist = launchL1DataBenchmarkReferenceValue((int) CacheSizeInInt, 1, avgFlowRef, potMissesFlowRef, timeRef, &error);
        if (error != 0) {
            FreeMeasureTwoL1Resources()
            printErrorCodeInformation(error);
            exit(error);
        }
        --n;
    }

    dist = true;
    n = 5;
    while(dist && n > 0) {
        int error = 0;
        dist = launchBenchmarkTwoL1(CacheSizeInInt, &avgFlow[0], &avgFlow[1], &potMissesFlow[0], &potMissesFlow[1], &time[0],
                                    &time[1], &error);
        if (error != 0) {
            FreeMeasureTwoL1Resources()
            printErrorCodeInformation(error);
            exit(error);
        }
        --n;
    }

    dTriple result;
    result.first = avgFlowRef[0];
    result.second = avgFlow[0];
    result.third = avgFlow[1];
#ifdef IsDebug
    fprintf(out, "Measured L1 Avg in clean execution: %f\n", avgFlowRef[0]);

    fprintf(out, "Measured L1_1 Avg While Shared With L1_2:  %f\n", avgFlow[0]);
    fprintf(out, "Measured L1_1 Pot Misses While Shared With L1_2:  %u\n", potMissesFlow[0]);

    fprintf(out, "Measured L1_2 Avg While Shared With L1_1:  %f\n", avgFlow[1]);
    fprintf(out, "Measured L1_2 Pot Misses While Shared With L1_1:  %u\n", potMissesFlow[1]);
#endif //IsDebug

    FreeMeasureTwoL1Resources()

    return std::max(std::abs(result.second - result.first), std::abs(result.third - result.first));
}


#endif //CUDATEST_TWOL1