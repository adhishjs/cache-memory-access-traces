
import csv
import os
import random
from collections import Counter

TRACE_DIR = "traces"
os.makedirs(TRACE_DIR, exist_ok=True)

random.seed(42)

def save_trace(name, addresses):
    filename = os.path.join(TRACE_DIR, name + ".csv")

    with open(filename, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["sequence", "operation", "address", "size"])

        for i, addr in enumerate(addresses):
            writer.writerow([i, "R", hex(addr), 4])

    print(f"Generated {filename}")


# 1. Sequential workload
sequential = [0x1000 + i * 4 for i in range(256)]

# 2. Fixed stride: 16 bytes
stride = [0x2000 + i * 16 for i in range(256)]

# 3. Repeated access
repeated = []
for i in range(64):
    repeated.extend([0x3000, 0x3004, 0x3000, 0x3004])

# 4. Random access
random_access = [
    0x4000 + random.randrange(256) * 4
    for _ in range(256)
]

# 5. Matrix row-wise traversal (16 x 16, 32-bit elements)
matrix_row = [
    0x5000 + (i * 16 + j) * 4
    for i in range(16)
    for j in range(16)
]

# 6. Matrix column-wise traversal
matrix_column = [
    0x5000 + (i * 16 + j) * 4
    for j in range(16)
    for i in range(16)
]

# 7. Mixed workload
mixed = (
    sequential[:64]
    + stride[:64]
    + random_access[:64]
    + repeated[:64]
)

save_trace("sequential", sequential)
save_trace("stride16", stride)
save_trace("repeated", repeated)
save_trace("random", random_access)
save_trace("matrix_row", matrix_row)
save_trace("matrix_column", matrix_column)
save_trace("mixed", mixed)

print("\nAll traces generated.")
