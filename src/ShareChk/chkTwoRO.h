#include "hip/hip_runtime.h"

#ifndef CUDATEST_TWORO
#define CUDATEST_TWORO

# include <cstdio>
# include <cstdint>

# include "hip/hip_runtime.h"
#include "../general_functions.h"

__global__ void chkTwoRO(unsigned int N, const unsigned int* __restrict__ arrayRO1, const unsigned int* __restrict__ arrayRO2, unsigned int *durationRO1, unsigned int * durationRO2, unsigned int *indexRO1, unsigned int *indexRO2,
                         bool* isDisturbed) {
    *isDisturbed = false;

    unsigned int start_time, end_time;
    unsigned int j = 0;
    __shared__ ALIGN(16) long long s_tvalueRO1[lessSize];
    __shared__ ALIGN(16) unsigned int s_indexRO1[lessSize];
    __shared__ ALIGN(16) long long s_tvalueRO2[lessSize];
    __shared__ ALIGN(16) unsigned int s_indexRO2[lessSize];

    __syncthreads();

    if (threadIdx.x == 0) {
        for (int k = 0; k < lessSize; k++) {
            s_indexRO1[k] = 0;
            s_tvalueRO1[k] = 0;
        }
    }

    __syncthreads();

    if (threadIdx.x == 1){
        for (int k = 0; k < lessSize; k++) {
            s_indexRO2[k] = 0;
            s_tvalueRO2[k] = 0;
        }
    }

    __syncthreads();

    if (threadIdx.x == 0) {
        for (int k = 0; k < N; k++) {
            j = __ldg(&arrayRO1[j]);
        }
    }

    __syncthreads();

    if (threadIdx.x == 1){
        for (int k = 0; k < N; k++) {
            j = __ldg(&arrayRO2[j]);
        }
    }

    __syncthreads();

    if (threadIdx.x == 0) {
        //second round
        for (int k = 0; k < lessSize; k++) {
            start_time = clock();
            j = __ldg(&arrayRO1[j]);
            s_indexRO1[k] = j;
            end_time = clock();
            s_tvalueRO1[k] = (end_time - start_time);
        }
    }

    __syncthreads();

    if (threadIdx.x == 1){
        for (int k = 0; k < lessSize; k++) {
            start_time = clock();
            j = __ldg(&arrayRO2[j]);
            s_indexRO2[k] = j;
            end_time = clock();
            s_tvalueRO2[k] = (end_time - start_time);
        }
    }

    __syncthreads();

    if (threadIdx.x == 0) {
        for (int k = 0; k < lessSize; k++) {
            indexRO1[k] = s_indexRO1[k];
            durationRO1[k] = s_tvalueRO1[k];
            if (durationRO1[k] > 3000) {
                *isDisturbed = true;
            }
        }
    }

    __syncthreads();

    if (threadIdx.x == 1){
        for (int k = 0; k < lessSize; k++) {
            indexRO2[k] = s_indexRO2[k];
            durationRO2[k] = s_tvalueRO2[k];
            if (durationRO2[k] > 3000) {
                *isDisturbed = true;
            }
        }
    }
}

bool launchBenchmarkTwoRO(unsigned int N, double *avgOut1, double* avgOut2, unsigned int* potMissesOut1, unsigned int* potMissesOut2, unsigned int **time1, unsigned int **time2, int* error) {
    hipError_t error_id;
    error_id = hipDeviceReset();

    unsigned int *h_indexReadOnly1 = nullptr, *h_indexReadOnly2 = nullptr, *h_timeinfoReadOnly1 = nullptr, *h_timeinfoReadOnly2 = nullptr, *h_aReadOnly = nullptr,
    *durationRO1 = nullptr, *durationRO2 = nullptr, *d_indexRO1 = nullptr, *d_indexRO2 = nullptr, *d_aReadOnly1 = nullptr, *d_aReadOnly2 = nullptr;
    bool *disturb = nullptr, *d_disturb = nullptr;

    do {
        // Allocate Memory on Host
        h_indexReadOnly1 = (unsigned int *) malloc(sizeof(unsigned int) * lessSize);
        if (h_indexReadOnly1 == nullptr) {
            printf("[CHKTWORO.CPP]: hipMalloc h_indexReadOnly1 Error\n");
            *error = 1;
            break;
        }

        h_indexReadOnly2 = (unsigned int *) malloc(sizeof(unsigned int) * lessSize);
        if (h_indexReadOnly2 == nullptr) {
            printf("[CHKTWORO.CPP]: hipMalloc h_indexReadOnly2 Error\n");
            *error = 1;
            break;
        }

        h_timeinfoReadOnly1 = (unsigned int *) malloc(sizeof(unsigned int) * lessSize);
        if (h_timeinfoReadOnly1 == nullptr) {
            printf("[CHKTWORO.CPP]: hipMalloc h_timeinfoReadOnly1 Error\n");
            *error = 1;
            break;
        }

        h_timeinfoReadOnly2 = (unsigned int *) malloc(sizeof(unsigned int) * lessSize);
        if (h_timeinfoReadOnly2 == nullptr) {
            printf("[CHKTWORO.CPP]: hipMalloc h_timeinfoReadOnly2 Error\n");
            *error = 1;
            break;
        }

        disturb = (bool *) malloc(sizeof(bool));
        if (disturb == nullptr) {
            printf("[CHKTWORO.CPP]: hipMalloc disturb Error\n");
            *error = 1;
            break;
        }

        h_aReadOnly = (unsigned int *) malloc(sizeof(unsigned int) * (N));
        if (h_aReadOnly == nullptr) {
            printf("[CHKTWORO.CPP]: hipMalloc h_aReadOnly Error\n");
            *error = 1;
            break;
        }

        // Allocate Memory on GPU
        error_id = hipMalloc((void **) &durationRO1, sizeof(unsigned int) * lessSize);
        if (error_id != hipSuccess) {
            printf("[CHKTWORO.CPP]: hipMalloc durationRO1 Error: %s\n", hipGetErrorString(error_id));
            *error = 2;
            break;
        }

        error_id = hipMalloc((void **) &durationRO2, sizeof(unsigned int) * lessSize);
        if (error_id != hipSuccess) {
            printf("[CHKTWORO.CPP]: hipMalloc durationRO2 Error: %s\n", hipGetErrorString(error_id));
            *error = 2;
            break;
        }

        error_id = hipMalloc((void **) &d_indexRO1, sizeof(unsigned int) * lessSize);
        if (error_id != hipSuccess) {
            printf("[CHKTWORO.CPP]: hipMalloc d_indexRO1 Error: %s\n", hipGetErrorString(error_id));
            *error = 2;
            break;
        }

        error_id = hipMalloc((void **) &d_indexRO2, sizeof(unsigned int) * lessSize);
        if (error_id != hipSuccess) {
            printf("[CHKTWORO.CPP]: hipMalloc d_indexRO2 Error: %s\n", hipGetErrorString(error_id));
            *error = 2;
            break;
        }

        error_id = hipMalloc((void **) &d_disturb, sizeof(bool));
        if (error_id != hipSuccess) {
            printf("[CHKTWORO.CPP]: hipMalloc disturb Error: %s\n", hipGetErrorString(error_id));
            *error = 2;
            break;
        }

        error_id = hipMalloc((void **) &d_aReadOnly1, sizeof(unsigned int) * (N));
        if (error_id != hipSuccess) {
            printf("[CHKTWORO.CPP]: hipMalloc d_aReadOnly1 Error: %s\n", hipGetErrorString(error_id));
            *error = 2;
            break;
        }
        error_id = hipMalloc((void **) &d_aReadOnly2, sizeof(unsigned int) * (N));
        if (error_id != hipSuccess) {
            printf("[CHKTWORO.CPP]: hipMalloc d_aReadOnly2 Error: %s\n", hipGetErrorString(error_id));
            *error = 2;
            break;
        }

        // Initialize p-chase array
        for (int i = 0; i < N; i++) {
            h_aReadOnly[i] = (i + 1) % N;
        }

        // Copy array from Host to GPU
        error_id = hipMemcpy(d_aReadOnly1, h_aReadOnly, sizeof(unsigned int) * N, hipMemcpyHostToDevice);
        if (error_id != hipSuccess) {
            printf("[CHKTWORO.CPP]: hipMemcpy d_aReadOnly1 Error: %s\n", hipGetErrorString(error_id));
            *error = 3;
            break;
        }

        error_id = hipMemcpy(d_aReadOnly2, h_aReadOnly, sizeof(unsigned int) * N, hipMemcpyHostToDevice);
        if (error_id != hipSuccess) {
            printf("[CHKTWORO.CPP]: hipMemcpy d_aReadOnly2 Error: %s\n", hipGetErrorString(error_id));
            *error = 3;
            break;
        }

        error_id = hipDeviceSynchronize();

        error_id = hipGetLastError();
        if (error_id != hipSuccess) {
            printf("[CHKTWORO.CPP]: hipDeviceSynchronize Error: %s\n", hipGetErrorString(error_id));
            *error = 99;
            break;
        }
        error_id = hipDeviceSynchronize();

        // Launch Kernel function
        dim3 Db = dim3(2);
        dim3 Dg = dim3(1, 1, 1);
        hipLaunchKernelGGL(chkTwoRO, Dg, Db, 0, 0, N, d_aReadOnly1, d_aReadOnly2, durationRO1, durationRO2, d_indexRO1, d_indexRO2, d_disturb);

        error_id = hipDeviceSynchronize();
        error_id = hipGetLastError();
        if (error_id != hipSuccess) {
            printf("[CHKTWORO.CPP]: Kernel launch/execution Error: %s\n", hipGetErrorString(error_id));
            *error = 5;
            break;
        }

        // Copy results from GPU to Host
        error_id = hipMemcpy((void *) h_timeinfoReadOnly1, (void *) durationRO1, sizeof(unsigned int) * lessSize,hipMemcpyDeviceToHost);
        if (error_id != hipSuccess) {
            printf("[CHKTWORO.CPP]: hipMemcpy durationRO1 Error: %s\n", hipGetErrorString(error_id));
            *error = 6;
            break;
        }

        error_id = hipMemcpy((void *) h_timeinfoReadOnly2, (void *) durationRO2, sizeof(unsigned int) * lessSize,hipMemcpyDeviceToHost);
        if (error_id != hipSuccess) {
            printf("[CHKTWORO.CPP]: hipMemcpy durationRO2 Error: %s\n", hipGetErrorString(error_id));
            *error = 6;
            break;
        }

        error_id = hipMemcpy((void *) h_indexReadOnly1, (void *) d_indexRO1, sizeof(unsigned int) * lessSize,hipMemcpyDeviceToHost);
        if (error_id != hipSuccess) {
            printf("[CHKTWORO.CPP]: hipMemcpy d_indexRO1 Error: %s\n", hipGetErrorString(error_id));
            *error = 6;
            break;
        }

        error_id = hipMemcpy((void *) h_indexReadOnly2, (void *) d_indexRO2, sizeof(unsigned int) * lessSize,hipMemcpyDeviceToHost);
        if (error_id != hipSuccess) {
            printf("[CHKTWORO.CPP]: hipMemcpy d_indexRO2 Error: %s\n", hipGetErrorString(error_id));
            *error = 6;
            break;
        }

        error_id = hipMemcpy((void *) disturb, (void *) d_disturb, sizeof(bool), hipMemcpyDeviceToHost);
        if (error_id != hipSuccess) {
            printf("[CHKTWORO.CPP]: hipMemcpy disturb Error: %s\n", hipGetErrorString(error_id));
            *error = 6;
            break;
        }

        createOutputFile((int) N, lessSize, h_indexReadOnly1, h_timeinfoReadOnly1, avgOut1, potMissesOut1, "TwoRO1_");
        createOutputFile((int) N, lessSize, h_indexReadOnly2, h_timeinfoReadOnly2, avgOut2, potMissesOut2, "TwoRO2_");
    } while(false);

    bool ret = false;
    if (disturb) {
        ret = *disturb;
        free(disturb);
    }

    // Free Memory on GPU
    FreeTestMemory({d_aReadOnly1, d_aReadOnly2, durationRO1, durationRO2, d_indexRO1, d_indexRO2, d_disturb}, true);

    // Free Memory on Host
    FreeTestMemory({h_indexReadOnly1, h_indexReadOnly2, h_aReadOnly}, false);

    SET_PART_OF_2D(time1, h_timeinfoReadOnly1);
    SET_PART_OF_2D(time2, h_timeinfoReadOnly2);

    error_id = hipDeviceReset();
    return ret;
}

#define FreeMeasureTwoROResOnlyPtr()        \
free(time);                                 \
free(timeRef);                              \
free(avgFlow);                              \
free(potMissesFlow);                        \
free(avgFlowRef);                           \
free(potMissesFlowRef);                     \

#define FreeMeasureTwoROResources()         \
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

double measure_TwoRO(unsigned int measuredSizeCache, unsigned int sub) {
    unsigned int CacheSizeInInt = (measuredSizeCache - sub) / 4;

    double* avgFlowRef = (double*) malloc(sizeof(double));
    unsigned int *potMissesFlowRef = (unsigned int*) malloc(sizeof(unsigned int));
    unsigned int** timeRef = (unsigned int**) malloc(sizeof(unsigned int*));

    double* avgFlow = (double*) malloc(sizeof(double)  * 2);
    unsigned int *potMissesFlow = (unsigned int*) malloc(sizeof(unsigned int) * 2);
    unsigned int** time = (unsigned int**) malloc(sizeof(unsigned int*) * 2);
    if (avgFlowRef == nullptr || potMissesFlowRef == nullptr || timeRef == nullptr ||
        avgFlow == nullptr || potMissesFlow == nullptr || time == nullptr) {
        FreeMeasureTwoROResOnlyPtr()
        printErrorCodeInformation(1);
        exit(1);
    }
    timeRef[0] = time[0] = time[1] = nullptr;

    bool dist = true; int n = 5;
    while(dist && n > 0) {
        int error = 0;
        dist = launchROBenchmarkReferenceValue((int) CacheSizeInInt, 1, avgFlowRef, potMissesFlowRef, timeRef, &error);
        if (error != 0) {
            FreeMeasureTwoROResources()
            printErrorCodeInformation(error);
            exit(error);
        }
        --n;
    }

    dist = true;
    n = 5;
    while(dist && n > 0) {
        int error = 0;
        dist = launchBenchmarkTwoRO(CacheSizeInInt, &avgFlow[0], &avgFlow[1], &potMissesFlow[0], &potMissesFlow[1], &time[0],
                                    &time[1], &error);
        if (error != 0) {
            FreeMeasureTwoROResources()
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
    fprintf(out, "Measured RO Avg in clean execution: %f\n", avgFlowRef[0]);

    fprintf(out, "Measured RO1 Avg While Shared With RO2:  %f\n", avgFlow[0]);
    fprintf(out, "Measured RO1 Pot Misses While Shared With RO2:  %u\n", potMissesFlow[0]);

    fprintf(out, "Measured RO2 Avg While Shared With RO1:  %f\n", avgFlow[1]);
    fprintf(out, "Measured RO2 Pot Misses While Shared With RO1:  %u\n", potMissesFlow[1]);
#endif //IsDebug

    FreeMeasureTwoROResources()

    return std::max(std::abs(result.second - result.first), std::abs(result.third - result.first));
}


#endif //CUDATEST_TWORO
