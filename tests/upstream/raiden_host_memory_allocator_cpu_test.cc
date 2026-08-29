// Copyright 2026 CaPU contributors.
// SPDX-License-Identifier: Apache-2.0

// CPU adapter for the shared-memory recovery contract in the pinned
// google/tpu-raiden host_memory_allocator_test.cc. The upstream test binary
// also links a TPU-client-only test and aborts during PJRT plugin registration
// when TPU_LIBRARY_PATH is absent. This adapter executes the same cold/warm
// boot and schema-mismatch assertions against the unmodified upstream
// SharedMemoryHostMemoryAllocator production implementation without linking
// that TPU-only dependency.

#include "tpu_raiden/core/host_memory_allocator.h"

#include <sys/mman.h>
#include <unistd.h>

#include <cstdint>
#include <cstring>
#include <string>

#include "absl/strings/str_format.h"
#include "xla/tsl/platform/statusor.h"
#include "xla/tsl/platform/test.h"

namespace tpu_raiden {
namespace {

TEST(RaidenHostMemoryAllocatorCpuAdapterTest, SharedMemoryColdAndWarmBoot) {
  std::string shm_key =
      "/capu_raiden_cpu_adapter_" + std::to_string(getpid());

  SharedMemoryHeader schema1 = {};
  schema1.magic = 0x52414944454E;
  schema1.version = 1;
  absl::SNPrintF(schema1.model_uid, sizeof(schema1.model_uid),
                 "test_model_v1");
  schema1.num_blocks = 128;
  schema1.block_size = 4096;
  schema1.num_heads = 32;
  schema1.head_dim = 128;
  schema1.itemsize = 2;

  {
    shm_unlink(shm_key.c_str());

    TF_ASSERT_OK_AND_ASSIGN(
        auto allocator1,
        SharedMemoryHostMemoryAllocator::Create(nullptr, shm_key, schema1));
    TF_ASSERT_OK_AND_ASSIGN(HostBufferAllocation alloc1,
                            allocator1->Allocate(1024));
    ASSERT_NE(alloc1.ptr, nullptr);
    ASSERT_EQ(alloc1.size, 1024);

    std::memset(alloc1.ptr, 0x55, 1024);

    SharedMemoryHeader* header1 = reinterpret_cast<SharedMemoryHeader*>(
        static_cast<uint8_t*>(alloc1.ptr) - sizeof(SharedMemoryHeader));
    EXPECT_EQ(header1->reference_count, 1);
    EXPECT_EQ(header1->version, 1);
    EXPECT_STREQ(header1->model_uid, "test_model_v1");

    {
      TF_ASSERT_OK_AND_ASSIGN(
          auto allocator2,
          SharedMemoryHostMemoryAllocator::Create(nullptr, shm_key, schema1));
      TF_ASSERT_OK_AND_ASSIGN(HostBufferAllocation alloc2,
                              allocator2->Allocate(1024));
      ASSERT_NE(alloc2.ptr, nullptr);
      ASSERT_EQ(alloc2.size, 1024);

      for (size_t i = 0; i < 1024; ++i) {
        ASSERT_EQ(alloc2.ptr[i], 0x55);
      }

      SharedMemoryHeader* header2 = reinterpret_cast<SharedMemoryHeader*>(
          static_cast<uint8_t*>(alloc2.ptr) - sizeof(SharedMemoryHeader));
      EXPECT_EQ(header2->reference_count, 2);
    }

    EXPECT_EQ(header1->reference_count, 1);

    {
      SharedMemoryHeader schema2 = schema1;
      schema2.version = 2;
      absl::SNPrintF(schema2.model_uid, sizeof(schema2.model_uid),
                     "test_model_v2");

      TF_ASSERT_OK_AND_ASSIGN(
          auto allocator3,
          SharedMemoryHostMemoryAllocator::Create(nullptr, shm_key, schema2));
      TF_ASSERT_OK_AND_ASSIGN(HostBufferAllocation alloc3,
                              allocator3->Allocate(1024));
      ASSERT_NE(alloc3.ptr, nullptr);

      SharedMemoryHeader* header3 = reinterpret_cast<SharedMemoryHeader*>(
          static_cast<uint8_t*>(alloc3.ptr) - sizeof(SharedMemoryHeader));
      EXPECT_EQ(header3->reference_count, 1);
      EXPECT_EQ(header3->version, 2);
      EXPECT_STREQ(header3->model_uid, "test_model_v2");

      for (size_t i = 0; i < 1024; ++i) {
        ASSERT_EQ(alloc3.ptr[i], 0);
      }
    }
  }

  shm_unlink(shm_key.c_str());
}

}  // namespace
}  // namespace tpu_raiden
