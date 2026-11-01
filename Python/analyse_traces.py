
import csv
import os
from collections import Counter

TRACE_DIR = "traces"

def load_trace(filename):
    addresses = []

    with open(filename, "r") as f:
        reader = csv.DictReader(f)

        for row in reader:
            addresses.append(int(row["address"], 16))

    return addresses

def analyse_line_utilization(addresses, line_sizes=(16, 32, 64)):

    print("\nCACHE-LINE UTILIZATION")

    for line_size in line_sizes:

        line_words = {}

        for addr in addresses:
            line_addr = addr // line_size

            if line_addr not in line_words:
                line_words[line_addr] = set()

            # Track distinct 32-bit words accessed in this line
            line_words[line_addr].add(addr)

        total_useful_bytes = sum(
            len(words) * 4
            for words in line_words.values()
        )

        total_fetched_bytes = len(line_words) * line_size

        utilization = (
            total_useful_bytes / total_fetched_bytes
        ) * 100

        print(
            f"Line size: {line_size:2d} B | "
            f"Lines: {len(line_words):3d} | "
            f"Utilization: {utilization:.2f}%"
        )


def analyse(addresses, line_sizes=(16, 32, 64)):

    total = len(addresses)
    strides = [
        addresses[i] - addresses[i-1]
        for i in range(1, total)
    ]

    stride_counts = Counter(strides)

    print("\nTotal accesses:", total)
    print("Unique word addresses:", len(set(addresses)))

    if strides:
        print("Most common strides:",
              stride_counts.most_common(5))

        sequential = sum(s == 4 for s in strides)
        print("Sequential access percentage:",
              round(100 * sequential / len(strides), 2), "%")

    for line_size in line_sizes:

        lines = set(addr // line_size for addr in addresses)

        print(f"\nCache line size: {line_size} bytes")
        print("Unique cache lines:", len(lines))
        print("Total bytes represented:",
              len(lines) * line_size)

    reuse_count = total - len(set(addresses))

    print("\nRepeated word accesses:", reuse_count)


for filename in sorted(os.listdir(TRACE_DIR)):

    if not filename.endswith(".csv"):
        continue

    print("\n" + "=" * 50)
    print("TRACE:", filename)
    print("=" * 50)

    addresses = load_trace(os.path.join(TRACE_DIR, filename))
    analyse(addresses)
    analyse_line_utilization(addresses)
